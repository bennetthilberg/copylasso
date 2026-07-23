#!/bin/bash

set -euo pipefail
umask 077

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
# shellcheck source=scripts/lib/release-metadata.sh
source "$repository_root/scripts/lib/release-metadata.sh"

fail() {
    echo "$1" >&2
    exit 1
}

usage() {
    echo "Usage: generate-draft-appcast.sh --application <app> --dmg <dmg> --release-notes <text> --output <appcast> --sparkle-tools-dir <dir>" >&2
    exit 64
}

application=""
dmg=""
release_notes=""
output=""
tools_directory=""
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --application)
            [[ "$#" -ge 2 ]] || usage
            application="$2"
            shift 2
            ;;
        --dmg)
            [[ "$#" -ge 2 ]] || usage
            dmg="$2"
            shift 2
            ;;
        --release-notes)
            [[ "$#" -ge 2 ]] || usage
            release_notes="$2"
            shift 2
            ;;
        --output)
            [[ "$#" -ge 2 ]] || usage
            output="$2"
            shift 2
            ;;
        --sparkle-tools-dir)
            [[ "$#" -ge 2 ]] || usage
            tools_directory="$2"
            shift 2
            ;;
        *) usage ;;
    esac
done
[[ -n "$application" && -n "$dmg" && -n "$release_notes" && -n "$output" && \
    -n "$tools_directory" ]] || usage

readonly private_key="${COPYLASSO_SPARKLE_PRIVATE_KEY:-}"
unset COPYLASSO_SPARKLE_PRIVATE_KEY
[[ -n "$private_key" ]] || fail "The protected Sparkle signing secret is unavailable."
private_key_bytes="$(printf '%s' "$private_key" | /usr/bin/base64 -D 2>/dev/null | /usr/bin/wc -c | /usr/bin/tr -d ' ')"
[[ "$private_key_bytes" == "32" ]] || fail "The protected Sparkle signing secret is invalid."

readonly temporary_directory="$(/usr/bin/mktemp -d "${TMPDIR:-/private/tmp}/copylasso-g36-appcast.XXXXXX")"
cleanup() {
    /bin/rm -rf "$temporary_directory"
}
trap cleanup EXIT
readonly public_key_deriver="$temporary_directory/derive-sparkle-public-key"
if ! /usr/bin/xcrun swiftc \
    "$repository_root/scripts/lib/derive-sparkle-public-key.swift" \
    -o "$public_key_deriver" \
    >"$temporary_directory/public-key-deriver-build.log" 2>&1; then
    fail "The reviewed Sparkle public-key verifier could not be prepared."
fi

[[ -d "$application" && ! -L "$application" ]] || \
    fail "The qualified CopyLasso application is unavailable."
readonly application_info="$application/Contents/Info.plist"
[[ -f "$application_info" && ! -L "$application_info" ]] || \
    fail "The qualified CopyLasso application has no readable metadata."
readonly shipped_public_key="$(
    /usr/bin/plutil -extract SUPublicEDKey raw -o - "$application_info" 2>/dev/null || true
)"
shipped_public_key_bytes="$(
    printf '%s' "$shipped_public_key" | /usr/bin/base64 -D 2>/dev/null | \
        /usr/bin/wc -c | /usr/bin/tr -d ' '
)"
[[ "$shipped_public_key_bytes" == "32" ]] || \
    fail "The qualified CopyLasso application has an invalid Sparkle public key."
readonly derived_public_key="$(
    printf '%s' "$private_key" | /usr/bin/base64 -D 2>/dev/null | \
        "$public_key_deriver" 2>/dev/null
)" || fail "The protected Sparkle signing secret is invalid."
[[ "$derived_public_key" == "$shipped_public_key" ]] || \
    fail "The protected Sparkle signing secret does not match the public key shipped in CopyLasso."

[[ -f "$dmg" && ! -L "$dmg" ]] || fail "The qualified release DMG is unavailable."
[[ "$(/usr/bin/basename "$dmg")" == "$COPYLASSO_RELEASE_DMG" ]] || \
    fail "The qualified release DMG has the wrong name."
[[ -f "$release_notes" && ! -L "$release_notes" && -s "$release_notes" ]] || \
    fail "The reviewed inline release notes are unavailable."
[[ "$(/usr/bin/basename "$output")" == "$COPYLASSO_RELEASE_APPCAST" ]] || \
    fail "The authenticated draft appcast has the wrong name."
[[ ! -e "$output" && ! -L "$output" ]] || \
    fail "The authenticated draft appcast output already exists."
[[ -d "$(/usr/bin/dirname "$output")" ]] || \
    fail "The authenticated draft appcast output directory is unavailable."

readonly generate_appcast="$tools_directory/generate_appcast"
readonly sign_update="$tools_directory/sign_update"
[[ -x "$generate_appcast" && -x "$sign_update" ]] || \
    fail "The reviewed Sparkle signing tools are unavailable."

readonly archives="$temporary_directory/archives"
readonly generated_appcast="$temporary_directory/$COPYLASSO_RELEASE_APPCAST"
/bin/mkdir -p "$archives"
/bin/cp "$dmg" "$archives/$COPYLASSO_RELEASE_DMG"
/bin/cp "$release_notes" "$archives/CopyLasso-$COPYLASSO_RELEASE_VERSION.txt"

if ! printf '%s' "$private_key" | \
    /usr/bin/env -u COPYLASSO_SPARKLE_PRIVATE_KEY \
    "$generate_appcast" \
        --ed-key-file - \
        --embed-release-notes \
        --disable-signing-warning \
        --download-url-prefix \
        "https://github.com/bennetthilberg/copylasso/releases/download/$COPYLASSO_RELEASE_TAG/" \
        --versions "$COPYLASSO_RELEASE_BUILD" \
        --maximum-deltas 0 \
        --maximum-versions 1 \
        -o "$generated_appcast" \
        "$archives" \
        >"$temporary_directory/generate.log" 2>&1; then
    fail "Sparkle could not generate authenticated draft update metadata."
fi

/usr/bin/xmllint --nonet --noout "$generated_appcast" 2>/dev/null || \
    fail "The authenticated draft appcast is not well-formed XML."
xpath_string() {
    /usr/bin/xmllint --nonet --xpath "string($1)" "$generated_appcast" 2>/dev/null
}
readonly enclosure_xpath='//*[local-name()="enclosure"]'
readonly expected_url="https://github.com/bennetthilberg/copylasso/releases/download/$COPYLASSO_RELEASE_TAG/$COPYLASSO_RELEASE_DMG"
readonly expected_size="$(/usr/bin/stat -f '%z' "$dmg")"
readonly enclosure_signature="$(xpath_string "$enclosure_xpath/@*[local-name()=\"edSignature\"]")"
[[ "$(xpath_string 'count(//*[local-name()="item"])')" == "1" ]] || \
    fail "The authenticated draft appcast must contain exactly one update."
[[ "$(xpath_string '//*[local-name()="version"]')" == "$COPYLASSO_RELEASE_BUILD" ]] || \
    fail "The authenticated draft appcast has the wrong build."
[[ "$(xpath_string '//*[local-name()="shortVersionString"]')" == "$COPYLASSO_RELEASE_VERSION" ]] || \
    fail "The authenticated draft appcast has the wrong display version."
[[ "$(xpath_string "$enclosure_xpath/@url")" == "$expected_url" ]] || \
    fail "The authenticated draft appcast has the wrong enclosure URL."
[[ "$(xpath_string "$enclosure_xpath/@length")" == "$expected_size" ]] || \
    fail "The authenticated draft appcast has the wrong signed length."
[[ -n "$enclosure_signature" ]] || \
    fail "The authenticated draft appcast is missing its enclosure signature."
[[ "$(xpath_string '//*[local-name()="description"]/@*[local-name()="format"]')" == "plain-text" ]] || \
    fail "The authenticated draft appcast must embed plain-text release notes."
[[ -n "$(xpath_string 'normalize-space(//*[local-name()="description"])')" ]] || \
    fail "The authenticated draft appcast has empty release notes."
[[ "$(xpath_string 'count(//*[local-name()="releaseNotesLink" or local-name()="fullReleaseNotesLink"])')" == "0" ]] || \
    fail "The authenticated draft appcast must not reference external release notes."

if ! printf '%s' "$private_key" | \
    /usr/bin/env -u COPYLASSO_SPARKLE_PRIVATE_KEY \
    "$sign_update" --verify --ed-key-file - "$generated_appcast" \
    >"$temporary_directory/feed-verification.log" 2>&1; then
    fail "Sparkle rejected the authenticated draft appcast signature."
fi
if ! printf '%s' "$private_key" | \
    /usr/bin/env -u COPYLASSO_SPARKLE_PRIVATE_KEY \
    "$sign_update" --verify --ed-key-file - "$dmg" "$enclosure_signature" \
    >"$temporary_directory/archive-verification.log" 2>&1; then
    fail "Sparkle rejected the authenticated draft enclosure signature."
fi

if printf '%s\n' "$private_key" | \
    /usr/bin/grep -Fq -f /dev/stdin "$generated_appcast"; then
    fail "The authenticated draft appcast contains private signing material."
fi
/bin/cp "$generated_appcast" "$output"
/bin/chmod 644 "$output"

echo "Authenticated draft update metadata created and verified."
