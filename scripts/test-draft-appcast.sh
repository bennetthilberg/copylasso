#!/bin/bash

set -euo pipefail
umask 077

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
# shellcheck source=scripts/lib/release-metadata.sh
source "$repository_root/scripts/lib/release-metadata.sh"
readonly generator="$repository_root/scripts/generate-draft-appcast.sh"
readonly tools_directory="${COPYLASSO_SPARKLE_TOOLS_DIR:-}"

fail() {
    echo "$1" >&2
    exit 1
}

[[ -x "$generator" ]] || fail "The authenticated draft appcast generator is unavailable."
[[ -x "$tools_directory/generate_appcast" && -x "$tools_directory/sign_update" ]] || \
    fail "Set COPYLASSO_SPARKLE_TOOLS_DIR to Sparkle's reviewed tools."

readonly temporary_directory="$(/usr/bin/mktemp -d "${TMPDIR:-/private/tmp}/copylasso-g36-appcast-tests.XXXXXX")"
cleanup() {
    /bin/rm -rf "$temporary_directory"
}
trap cleanup EXIT
readonly app="$temporary_directory/source/CopyLasso.app"
readonly info="$app/Contents/Info.plist"
readonly executable="$app/Contents/MacOS/CopyLasso"
readonly dmg="$temporary_directory/$COPYLASSO_RELEASE_DMG"
readonly notes="$temporary_directory/notes.txt"
readonly appcast="$temporary_directory/$COPYLASSO_RELEASE_APPCAST"
readonly download_tag="v$COPYLASSO_RELEASE_VERSION-rc.42"
/bin/mkdir -p "$app/Contents/MacOS"

readonly private_key="$(/usr/bin/openssl rand -base64 32 | /usr/bin/tr -d '\n')"
readonly public_key="$(
    COPYLASSO_TEST_SPARKLE_KEY="$private_key" /usr/bin/swift -e '
      import CryptoKit
      import Foundation
      let data = Data(base64Encoded: ProcessInfo.processInfo.environment["COPYLASSO_TEST_SPARKLE_KEY"]!)!
      let key = try! Curve25519.Signing.PrivateKey(rawRepresentation: data)
      print(key.publicKey.rawRepresentation.base64EncodedString())
    '
)"
[[ -n "$public_key" ]] || fail "The test-only Sparkle keypair could not be created."

/usr/bin/plutil -create xml1 "$info"
/usr/bin/plutil -insert CFBundleExecutable -string CopyLasso "$info"
/usr/bin/plutil -insert CFBundleIdentifier -string io.github.bennetthilberg.copylasso "$info"
/usr/bin/plutil -insert CFBundleName -string CopyLasso "$info"
/usr/bin/plutil -insert CFBundleShortVersionString -string "$COPYLASSO_RELEASE_VERSION" "$info"
/usr/bin/plutil -insert CFBundleVersion -string "$COPYLASSO_RELEASE_BUILD" "$info"
/usr/bin/plutil -insert LSMinimumSystemVersion -string 14.0 "$info"
/usr/bin/plutil -insert SUPublicEDKey -string "$public_key" "$info"
/usr/bin/plutil -insert SURequireSignedFeed -bool true "$info"
/bin/cp /usr/bin/true "$executable"
/bin/chmod 755 "$executable"
/usr/bin/codesign --force --deep --sign - "$app" >/dev/null 2>&1
/usr/bin/hdiutil create -quiet -fs HFS+ -srcfolder "$temporary_directory/source" "$dmg"
/usr/bin/printf 'Private authenticated update fixture.\n' > "$notes"

missing_secret_output="$({
    env -u COPYLASSO_SPARKLE_PRIVATE_KEY "$generator" \
        --application "$app" \
        --dmg "$dmg" \
        --release-notes "$notes" \
        --download-tag "$download_tag" \
        --output "$appcast" \
        --sparkle-tools-dir "$tools_directory" 2>&1
} || true)"
[[ "$missing_secret_output" == 'The protected Sparkle signing secret is unavailable.' ]] || \
    fail "The draft appcast generator must fail closed without its protected secret."

readonly mismatched_private_key="$(/usr/bin/openssl rand -base64 32 | /usr/bin/tr -d '\n')"
mismatched_key_output="$({
    COPYLASSO_SPARKLE_PRIVATE_KEY="$mismatched_private_key" "$generator" \
        --application "$app" \
        --dmg "$dmg" \
        --release-notes "$notes" \
        --download-tag "$download_tag" \
        --output "$appcast" \
        --sparkle-tools-dir "$tools_directory" 2>&1
} || true)"
[[ "$mismatched_key_output" == \
    'The protected Sparkle signing secret does not match the public key shipped in CopyLasso.' ]] || \
    fail "The generator must reject a signing seed that does not match the shipped public key."
[[ ! -e "$appcast" ]] || \
    fail "A mismatched signing seed must not create authenticated update metadata."

COPYLASSO_SPARKLE_PRIVATE_KEY="$private_key" "$generator" \
    --application "$app" \
    --dmg "$dmg" \
    --release-notes "$notes" \
    --download-tag "$download_tag" \
    --output "$appcast" \
    --sparkle-tools-dir "$tools_directory" >/dev/null
[[ -s "$appcast" ]] || fail "The authenticated draft appcast was not created."
readonly enclosure_url="$(
    /usr/bin/xmllint --nonet --xpath \
        'string(//*[local-name()="enclosure"]/@url)' "$appcast" 2>/dev/null
)"
[[ "$enclosure_url" == \
    "https://github.com/bennetthilberg/copylasso/releases/download/$download_tag/$COPYLASSO_RELEASE_DMG" ]] || \
    fail "The authenticated draft appcast must download from its exact private draft tag."
if /usr/bin/grep -Fq -- "$private_key" "$appcast"; then
    fail "The test-only private key leaked into generated metadata."
fi

existing_output="$({
    COPYLASSO_SPARKLE_PRIVATE_KEY="$private_key" "$generator" \
        --application "$app" \
        --dmg "$dmg" \
        --release-notes "$notes" \
        --download-tag "$download_tag" \
        --output "$appcast" \
        --sparkle-tools-dir "$tools_directory" 2>&1
} || true)"
[[ "$existing_output" == 'The authenticated draft appcast output already exists.' ]] || \
    fail "The generator must refuse to replace authenticated metadata."

readonly feed_mutation="$temporary_directory/feed-mutation.xml"
/bin/cp "$appcast" "$feed_mutation"
/usr/bin/sed -i '' 's/Private authenticated update fixture/Mutated update fixture/' "$feed_mutation"
if /usr/bin/printf '%s' "$private_key" | \
    "$tools_directory/sign_update" --verify --ed-key-file - "$feed_mutation" >/dev/null 2>&1; then
    fail "Sparkle accepted mutated authenticated draft metadata."
fi

echo "CopyLasso authenticated draft appcast tests passed."
