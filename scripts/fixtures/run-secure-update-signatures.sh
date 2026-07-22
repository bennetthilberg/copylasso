#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && /bin/pwd -P)"
readonly tools_dir="${COPYLASSO_SPARKLE_TOOLS_DIR:-}"

fail() {
    echo "$1" >&2
    exit 1
}

[[ "$#" == "0" ]] || fail "Unexpected sandboxed signature fixture argument."
[[ -n "$tools_dir" ]] || fail "Set COPYLASSO_SPARKLE_TOOLS_DIR to Sparkle's bin directory."
readonly sign_update="$tools_dir/sign_update"
readonly generate_appcast="$tools_dir/generate_appcast"
readonly sparkle_artifact_dir="$(cd "$tools_dir/.." && /bin/pwd)"
readonly sparkle_frameworks="$sparkle_artifact_dir/Sparkle.xcframework/macos-arm64_x86_64"
readonly parser_probe_source="$repository_root/scripts/fixtures/SignedAppcastParserProbe.m"
[[ -x "$sign_update" ]] || fail "Sparkle sign_update is unavailable."
[[ -x "$generate_appcast" ]] || fail "Sparkle generate_appcast is unavailable."
[[ -d "$sparkle_frameworks/Sparkle.framework" ]] || fail "Sparkle framework is unavailable."
[[ -f "$parser_probe_source" ]] || fail "Signed appcast parser probe is unavailable."

readonly temporary_directory="$(/usr/bin/mktemp -d "${TMPDIR:-/private/tmp}/copylasso-g35-signatures.XXXXXX")"
trap '/bin/rm -rf "$temporary_directory"' EXIT

readonly signing_key="$temporary_directory/signing-key"
readonly wrong_key="$temporary_directory/wrong-key"
/usr/bin/openssl rand -base64 32 > "$signing_key"
/usr/bin/openssl rand -base64 32 > "$wrong_key"
/bin/chmod 600 "$signing_key" "$wrong_key"

readonly archive="$temporary_directory/CopyLasso-0.2.0.dmg"
/usr/bin/printf 'CopyLasso local secure-update fixture\n' > "$archive"
archive_signature="$("$sign_update" --ed-key-file "$signing_key" -p "$archive" 2>/dev/null)"
[[ -n "$archive_signature" ]] || fail "Sparkle did not produce an archive signature."
"$sign_update" --verify --ed-key-file "$signing_key" \
    "$archive" "$archive_signature" >/dev/null 2>&1 || \
    fail "Sparkle rejected its signed archive fixture."

readonly tampered_archive="$temporary_directory/CopyLasso-0.2.0-tampered.dmg"
/bin/cp "$archive" "$tampered_archive"
/usr/bin/printf 'tampered\n' >> "$tampered_archive"
if "$sign_update" --verify --ed-key-file "$signing_key" \
    "$tampered_archive" "$archive_signature" >/dev/null 2>&1; then
    fail "Sparkle accepted a tampered archive fixture."
fi
if "$sign_update" --verify --ed-key-file "$wrong_key" \
    "$archive" "$archive_signature" >/dev/null 2>&1; then
    fail "Sparkle accepted an archive signed by a different key."
fi

readonly feed="$temporary_directory/appcast.xml"
/usr/bin/printf '%s\n' \
    '<?xml version="1.0" encoding="utf-8"?>' \
    '<rss version="2.0"><channel><title>CopyLasso local fixture</title></channel></rss>' \
    > "$feed"
"$sign_update" --ed-key-file "$signing_key" "$feed" >/dev/null 2>&1 || \
    fail "Sparkle could not sign the local appcast fixture."
"$sign_update" --verify --ed-key-file "$signing_key" "$feed" >/dev/null 2>&1 || \
    fail "Sparkle rejected its signed appcast fixture."

readonly tampered_feed="$temporary_directory/appcast-tampered.xml"
/bin/cp "$feed" "$tampered_feed"
/usr/bin/sed -i '' \
    's/CopyLasso local fixture/CopyLasso tampered fixture/' \
    "$tampered_feed"
if "$sign_update" --verify --ed-key-file "$signing_key" "$tampered_feed" >/dev/null 2>&1; then
    fail "Sparkle accepted a tampered appcast fixture."
fi
if "$sign_update" --verify --ed-key-file "$wrong_key" "$feed" >/dev/null 2>&1; then
    fail "Sparkle accepted an appcast signed by a different key."
fi

readonly malformed_feed="$temporary_directory/appcast-malformed.xml"
/usr/bin/printf '<rss><channel>' > "$malformed_feed"
"$sign_update" --ed-key-file "$signing_key" "$malformed_feed" >/dev/null 2>&1 || \
    fail "Sparkle could not sign the malformed appcast fixture."
"$sign_update" --verify --ed-key-file "$signing_key" "$malformed_feed" >/dev/null 2>&1 || \
    fail "Sparkle did not authenticate the signed malformed appcast fixture."

readonly parser_probe="$temporary_directory/signed-appcast-parser-probe"
/usr/bin/xcrun clang \
    -fobjc-arc \
    -F "$sparkle_frameworks" \
    -framework Foundation \
    -framework Sparkle \
    "$parser_probe_source" \
    -o "$parser_probe"
DYLD_FRAMEWORK_PATH="$sparkle_frameworks" "$parser_probe" accept "$feed" || \
    fail "Sparkle did not parse the authenticated well-formed appcast control."
DYLD_FRAMEWORK_PATH="$sparkle_frameworks" "$parser_probe" reject "$malformed_feed" || \
    fail "Sparkle parsed an authenticated malformed appcast fixture."

# The package must expose the reviewed feed-generation tool even though G35
# deliberately does not generate or publish a production appcast.
"$generate_appcast" --help >/dev/null 2>&1 || fail "Sparkle generate_appcast is unusable."

echo "CopyLasso offline Sparkle signature fixtures passed."
