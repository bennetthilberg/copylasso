#!/bin/bash

set -euo pipefail
umask 077

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
# shellcheck source=scripts/lib/v02-publication-verification.sh
source "$repository_root/scripts/lib/v02-publication-verification.sh"

usage() {
    cat >&2 <<'TEXT'
Usage: generate-release-appcast.sh \
  --application /path/to/CopyLasso.app \
  --candidate-dir /path/to/downloaded/G42/assets \
  --release-notes /path/to/0.2.0.md \
  --output /path/to/appcast.xml \
  --sparkle-tools-dir /path/to/Sparkle/bin
TEXT
    exit 64
}

application=""
candidate_directory=""
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
        --candidate-dir)
            [[ "$#" -ge 2 ]] || usage
            candidate_directory="$2"
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
[[ -n "$application" && -n "$candidate_directory" && -n "$release_notes" && \
    -n "$output" && -n "$tools_directory" ]] || usage

readonly private_key="${COPYLASSO_SPARKLE_PRIVATE_KEY:-}"
unset COPYLASSO_SPARKLE_PRIVATE_KEY
[[ -n "$private_key" ]] || \
    v02_publication_fail "The protected Sparkle signing secret is unavailable."
private_key_bytes="$(
    /usr/bin/printf '%s' "$private_key" |
        /usr/bin/base64 -D 2>/dev/null |
        /usr/bin/wc -c |
        /usr/bin/tr -d ' '
)"
[[ "$private_key_bytes" == "32" ]] || \
    v02_publication_fail "The protected Sparkle signing secret is invalid."

assert_v02_candidate_files "$candidate_directory"
assert_v02_release_notes "$release_notes"
[[ -d "$application" && ! -L "$application" ]] || \
    v02_publication_fail "The qualified CopyLasso application is unavailable."
readonly application_info="$application/Contents/Info.plist"
[[ -f "$application_info" && ! -L "$application_info" ]] || \
    v02_publication_fail "The qualified CopyLasso application has no readable metadata."
[[ "$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$application_info" 2>/dev/null || true)" == \
    "io.github.bennetthilberg.copylasso" ]] || \
    v02_publication_fail "The qualified CopyLasso application has the wrong bundle identifier."
[[ "$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$application_info" 2>/dev/null || true)" == \
    "$COPYLASSO_RELEASE_VERSION" ]] || \
    v02_publication_fail "The qualified CopyLasso application has the wrong version."
[[ "$(/usr/bin/plutil -extract CFBundleVersion raw -o - "$application_info" 2>/dev/null || true)" == \
    "$COPYLASSO_RELEASE_BUILD" ]] || \
    v02_publication_fail "The qualified CopyLasso application has the wrong build."
[[ "$(/usr/bin/plutil -extract SUFeedURL raw -o - "$application_info" 2>/dev/null || true)" == \
    "$COPYLASSO_V02_FEED_URL" ]] || \
    v02_publication_fail "The qualified CopyLasso application has the wrong update-feed URL."

readonly shipped_public_key="$(
    /usr/bin/plutil -extract SUPublicEDKey raw -o - "$application_info" 2>/dev/null || true
)"
shipped_public_key_bytes="$(
    /usr/bin/printf '%s' "$shipped_public_key" |
        /usr/bin/base64 -D 2>/dev/null |
        /usr/bin/wc -c |
        /usr/bin/tr -d ' '
)"
[[ "$shipped_public_key_bytes" == "32" ]] || \
    v02_publication_fail "The qualified CopyLasso application has an invalid Sparkle public key."

[[ "$(/usr/bin/basename "$output")" == "$COPYLASSO_V02_PUBLIC_APPCAST_NAME" ]] || \
    v02_publication_fail "The public update metadata must be named appcast.xml."
[[ ! -e "$output" && ! -L "$output" ]] || \
    v02_publication_fail "The public appcast output already exists."
readonly output_parent="$(/usr/bin/dirname "$output")"
[[ -d "$output_parent" && ! -L "$output_parent" ]] || \
    v02_publication_fail "The public appcast output directory is unavailable."
readonly generate_appcast="$tools_directory/generate_appcast"
readonly sign_update="$tools_directory/sign_update"
[[ -x "$generate_appcast" && -x "$sign_update" ]] || \
    v02_publication_fail "The reviewed Sparkle signing tools are unavailable."

readonly temporary_directory="$(/usr/bin/mktemp -d \
    "${TMPDIR:-/private/tmp}/copylasso-g43-appcast.XXXXXX")"
cleanup() {
    /bin/rm -rf "$temporary_directory"
}
trap cleanup EXIT
readonly public_key_deriver="$temporary_directory/derive-sparkle-public-key"
if ! /usr/bin/xcrun swiftc \
    "$repository_root/scripts/lib/derive-sparkle-public-key.swift" \
    -o "$public_key_deriver" \
    > "$temporary_directory/public-key-deriver-build.log" 2>&1; then
    v02_publication_fail "The reviewed Sparkle public-key verifier could not be prepared."
fi
readonly derived_public_key="$(
    /usr/bin/printf '%s' "$private_key" |
        /usr/bin/base64 -D 2>/dev/null |
        "$public_key_deriver" 2>/dev/null
)" || v02_publication_fail "The protected Sparkle signing secret is invalid."
[[ "$derived_public_key" == "$shipped_public_key" ]] || \
    v02_publication_fail \
        "The protected Sparkle signing secret does not match the public key shipped in CopyLasso."

readonly archives="$temporary_directory/archives"
readonly generated_appcast="$temporary_directory/$COPYLASSO_V02_PUBLIC_APPCAST_NAME"
/bin/mkdir "$archives"
/bin/cp "$candidate_directory/$COPYLASSO_RELEASE_DMG" \
    "$archives/$COPYLASSO_RELEASE_DMG"
/bin/cp "$release_notes" \
    "$archives/CopyLasso-$COPYLASSO_RELEASE_VERSION.txt"

if ! /usr/bin/printf '%s' "$private_key" |
    /usr/bin/env -u COPYLASSO_SPARKLE_PRIVATE_KEY \
        "$generate_appcast" \
        --ed-key-file - \
        --embed-release-notes \
        --disable-signing-warning \
        --download-url-prefix \
        "https://github.com/$COPYLASSO_V02_REPOSITORY/releases/download/$COPYLASSO_V02_FINAL_TAG/" \
        --versions "$COPYLASSO_RELEASE_BUILD" \
        --maximum-deltas 0 \
        --maximum-versions 1 \
        -o "$generated_appcast" \
        "$archives" \
        > "$temporary_directory/generate.log" 2>&1; then
    v02_publication_fail "Sparkle could not generate authenticated public update metadata."
fi

assert_v02_appcast_contract "$generated_appcast" "$release_notes"
readonly enclosure_signature="$(
    /usr/bin/xmllint --nonet --xpath \
        'string(//*[local-name()="enclosure"]/@*[local-name()="edSignature"])' \
        "$generated_appcast" 2>/dev/null
)"
if ! /usr/bin/printf '%s' "$private_key" |
    /usr/bin/env -u COPYLASSO_SPARKLE_PRIVATE_KEY \
        "$sign_update" --verify --ed-key-file - "$generated_appcast" \
        > "$temporary_directory/feed-verification.log" 2>&1; then
    v02_publication_fail "Sparkle rejected the authenticated public appcast signature."
fi
if ! /usr/bin/printf '%s' "$private_key" |
    /usr/bin/env -u COPYLASSO_SPARKLE_PRIVATE_KEY \
        "$sign_update" --verify --ed-key-file - \
        "$candidate_directory/$COPYLASSO_RELEASE_DMG" "$enclosure_signature" \
        > "$temporary_directory/enclosure-verification.log" 2>&1; then
    v02_publication_fail "Sparkle rejected the authenticated public enclosure signature."
fi
if /usr/bin/printf '%s\n' "$private_key" |
    /usr/bin/grep -Fq -f /dev/stdin "$generated_appcast"; then
    v02_publication_fail "The authenticated public appcast contains private signing material."
fi

/bin/cp "$generated_appcast" "$output"
/bin/chmod 644 "$output"
cleanup
trap - EXIT

echo "Authenticated public v0.2 update metadata created and verified."
