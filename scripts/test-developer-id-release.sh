#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly audit_script="$repository_root/scripts/audit-developer-id-release.sh"
readonly verifier_script="$repository_root/scripts/verify-developer-id-app.sh"
readonly verifier_library="$repository_root/scripts/lib/developer-id-verification.sh"
readonly export_options="$repository_root/Configuration/DeveloperIDExportOptions.plist"
readonly signing_documentation="$repository_root/docs/developer-id-signing.md"

fail() {
    echo "$1" >&2
    exit 1
}

[[ -x "$audit_script" ]] || fail "Developer ID release audit is missing or not executable."
[[ -x "$verifier_script" ]] || fail "Developer ID application verifier is missing or not executable."
[[ -r "$verifier_library" ]] || fail "Developer ID verification library is missing."
[[ -r "$export_options" ]] || fail "Developer ID export options are missing."
[[ -r "$signing_documentation" ]] || fail "Developer ID signing documentation is missing."

# shellcheck source=scripts/lib/developer-id-verification.sh
source "$verifier_library"

declare -F bundle_contains_mach_o >/dev/null ||
    fail "The verifier must distinguish code-bearing bundles from resource-only bundles."

expect_failure() {
    local expected_message="$1"
    shift
    local output

    if output="$("$@" 2>&1)"; then
        fail "Expected command to fail: $*"
    fi
    if [[ "$output" != *"$expected_message"* ]]; then
        fail "Expected failure containing '$expected_message', received '$output'."
    fi
}

readonly temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/copylasso-g26-tests.XXXXXX")"
trap 'rm -rf "$temporary_directory"' EXIT

mkdir -p "$temporary_directory/resource-only.bundle/Contents/Resources"
echo 'localized resources' > "$temporary_directory/resource-only.bundle/Contents/Resources/content.txt"
if bundle_contains_mach_o "$temporary_directory/resource-only.bundle"; then
    fail "A resource-only bundle must not be classified as nested executable code."
fi
mkdir -p "$temporary_directory/code-bearing.bundle/Contents/MacOS"
cp /bin/echo "$temporary_directory/code-bearing.bundle/Contents/MacOS/Helper"
bundle_contains_mach_o "$temporary_directory/code-bearing.bundle" ||
    fail "A bundle containing Mach-O code must be classified as nested executable code."

readonly valid_info="$temporary_directory/Info.plist"
cat > "$valid_info" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>CopyLasso</string>
    <key>CFBundleIdentifier</key>
    <string>io.github.bennetthilberg.copylasso</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
</dict>
</plist>
PLIST

assert_release_metadata "$valid_info"

cp "$valid_info" "$temporary_directory/wrong-bundle.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier io.github.bennetthilberg.copylasso.debug' \
    "$temporary_directory/wrong-bundle.plist"
expect_failure "production bundle identifier" assert_release_metadata \
    "$temporary_directory/wrong-bundle.plist"

cp "$valid_info" "$temporary_directory/wrong-version.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 0.2.0' \
    "$temporary_directory/wrong-version.plist"
expect_failure "version 0.1.0" assert_release_metadata "$temporary_directory/wrong-version.plist"

cp "$valid_info" "$temporary_directory/wrong-build.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleVersion 2' "$temporary_directory/wrong-build.plist"
expect_failure "build 1" assert_release_metadata "$temporary_directory/wrong-build.plist"

cp "$valid_info" "$temporary_directory/missing-bundle.plist"
/usr/libexec/PlistBuddy -c 'Delete :CFBundleIdentifier' "$temporary_directory/missing-bundle.plist"
expect_failure "bundle identifier is missing" assert_release_metadata "$temporary_directory/missing-bundle.plist"

cp "$valid_info" "$temporary_directory/missing-version.plist"
/usr/libexec/PlistBuddy -c 'Delete :CFBundleShortVersionString' "$temporary_directory/missing-version.plist"
expect_failure "version is missing" assert_release_metadata "$temporary_directory/missing-version.plist"

cp "$valid_info" "$temporary_directory/missing-build.plist"
/usr/libexec/PlistBuddy -c 'Delete :CFBundleVersion' "$temporary_directory/missing-build.plist"
expect_failure "build is missing" assert_release_metadata "$temporary_directory/missing-build.plist"

assert_universal_architectures "arm64 x86_64"
assert_universal_architectures "x86_64 arm64"
expect_failure "arm64 and x86_64" assert_universal_architectures "arm64"
expect_failure "arm64 and x86_64" assert_universal_architectures "x86_64"
expect_failure "arm64 and x86_64" assert_universal_architectures "arm64 x86_64 i386"
expect_failure "arm64 and x86_64" assert_universal_architectures ""

readonly valid_entitlements="$temporary_directory/valid-entitlements.plist"
cat > "$valid_entitlements" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
</dict>
</plist>
PLIST

assert_release_entitlements "$valid_entitlements"

cp "$valid_entitlements" "$temporary_directory/string-sandbox-entitlements.plist"
/usr/libexec/PlistBuddy -c 'Delete :com.apple.security.app-sandbox' \
    -c 'Add :com.apple.security.app-sandbox string true' \
    "$temporary_directory/string-sandbox-entitlements.plist"
expect_failure "Boolean true value" assert_release_entitlements \
    "$temporary_directory/string-sandbox-entitlements.plist"

cp "$valid_entitlements" "$temporary_directory/debug-entitlements.plist"
/usr/libexec/PlistBuddy -c 'Add :com.apple.security.get-task-allow bool true' \
    "$temporary_directory/debug-entitlements.plist"
expect_failure "get-task-allow" assert_release_entitlements \
    "$temporary_directory/debug-entitlements.plist"

cp "$valid_entitlements" "$temporary_directory/network-entitlements.plist"
/usr/libexec/PlistBuddy -c 'Add :com.apple.security.network.client bool true' \
    "$temporary_directory/network-entitlements.plist"

cp "$valid_entitlements" "$temporary_directory/missing-sandbox.plist"
/usr/libexec/PlistBuddy -c 'Delete :com.apple.security.app-sandbox' "$temporary_directory/missing-sandbox.plist"
expect_failure "must retain App Sandbox" assert_release_entitlements "$temporary_directory/missing-sandbox.plist"

cp "$valid_entitlements" "$temporary_directory/disabled-sandbox.plist"
/usr/libexec/PlistBuddy -c 'Set :com.apple.security.app-sandbox false' "$temporary_directory/disabled-sandbox.plist"
expect_failure "must retain App Sandbox" assert_release_entitlements "$temporary_directory/disabled-sandbox.plist"

echo 'not a property list' > "$temporary_directory/malformed-entitlements.plist"
expect_failure "not a valid property list" assert_release_entitlements "$temporary_directory/malformed-entitlements.plist"
expect_failure "only the reviewed App Sandbox capability" assert_release_entitlements \
    "$temporary_directory/network-entitlements.plist"

readonly valid_signature="$temporary_directory/valid-signature.txt"
cat > "$valid_signature" <<'TEXT'
Executable=/private/example/CopyLasso
Identifier=io.github.bennetthilberg.copylasso
Format=app bundle with Mach-O universal (x86_64 arm64)
CodeDirectory v=20500 size=123 flags=0x10000(runtime) hashes=1+7 location=embedded
Signature size=9000
Authority=Developer ID Application: Redacted
Authority=Developer ID Certification Authority
Authority=Apple Root CA
Timestamp=Jul 15, 2026 at 12:00:00 PM
TeamIdentifier=REDACTED
TEXT

readonly expected_team_identifier="REDACTED"
assert_developer_id_signature "$valid_signature"
expect_failure "approved release team" assert_developer_id_signature \
    "$valid_signature" "DIFFERENT"

sed 's/(runtime)/(library-validation,runtime)/' "$valid_signature" > \
    "$temporary_directory/multiple-runtime-flags.txt"
assert_developer_id_signature "$temporary_directory/multiple-runtime-flags.txt"

assert_nested_developer_id_signature "$valid_signature" "REDACTED"
assert_nested_developer_id_signature "$temporary_directory/multiple-runtime-flags.txt" "REDACTED"

sed '/Developer ID Application/d' "$valid_signature" > "$temporary_directory/nested-development-signature.txt"
expect_failure "nested code is not signed with Developer ID Application" \
    assert_nested_developer_id_signature "$temporary_directory/nested-development-signature.txt" "REDACTED"

sed '/Timestamp=/d' "$valid_signature" > "$temporary_directory/nested-no-timestamp.txt"
expect_failure "nested Developer ID signature is missing a secure timestamp" \
    assert_nested_developer_id_signature "$temporary_directory/nested-no-timestamp.txt" "REDACTED"

sed 's/flags=0x10000(runtime)/flags=0x0(none)/' "$valid_signature" > \
    "$temporary_directory/nested-no-runtime.txt"
expect_failure "nested Developer ID signature is missing Hardened Runtime" \
    assert_nested_developer_id_signature "$temporary_directory/nested-no-runtime.txt" "REDACTED"

sed 's/TeamIdentifier=REDACTED/TeamIdentifier=DIFFERENT/' "$valid_signature" > \
    "$temporary_directory/nested-wrong-team.txt"
expect_failure "nested Developer ID signature does not match the application team" \
    assert_nested_developer_id_signature "$temporary_directory/nested-wrong-team.txt" "REDACTED"

sed '/Developer ID Application/d' "$valid_signature" > "$temporary_directory/development-signature.txt"
expect_failure "Developer ID Application" assert_developer_id_signature \
    "$temporary_directory/development-signature.txt"

sed 's/Identifier=io.github.bennetthilberg.copylasso/Identifier=io.github.bennetthilberg.copylasso.debug/' "$valid_signature" > "$temporary_directory/debug-signature.txt"
expect_failure "production identifier" assert_developer_id_signature "$temporary_directory/debug-signature.txt"

sed '/Timestamp=/d' "$valid_signature" > "$temporary_directory/no-timestamp.txt"
expect_failure "secure timestamp" assert_developer_id_signature "$temporary_directory/no-timestamp.txt"

sed 's/flags=0x10000(runtime)/flags=0x0(none)/' "$valid_signature" > \
    "$temporary_directory/no-runtime.txt"
expect_failure "Hardened Runtime" assert_developer_id_signature "$temporary_directory/no-runtime.txt"

sed '/TeamIdentifier=/d' "$valid_signature" > "$temporary_directory/no-team.txt"
expect_failure "team identifier" assert_developer_id_signature "$temporary_directory/no-team.txt"

readonly valid_requirement="$temporary_directory/valid-requirement.txt"
cat > "$valid_requirement" <<'TEXT'
designated => identifier "io.github.bennetthilberg.copylasso" and anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.13] and certificate leaf[subject.OU] = "REDACTED"
TEXT
assert_release_requirement "$valid_requirement" "REDACTED"
sed 's/$/)/' "$valid_requirement" > "$temporary_directory/parenthesized-team-requirement.txt"
assert_release_requirement "$temporary_directory/parenthesized-team-requirement.txt" "REDACTED"
sed 's/subject.OU] = "REDACTED"/subject.OU] = REDACTED/' "$valid_requirement" > \
    "$temporary_directory/unquoted-team-requirement.txt"
assert_release_requirement "$temporary_directory/unquoted-team-requirement.txt" "REDACTED"
echo 'designated => identifier "io.github.bennetthilberg.copylasso.debug" and anchor apple generic' > \
    "$temporary_directory/debug-requirement.txt"

sed 's/anchor apple generic/anchor trusted/' "$valid_requirement" > "$temporary_directory/wrong-anchor-requirement.txt"
expect_failure "generic anchor" assert_release_requirement "$temporary_directory/wrong-anchor-requirement.txt"

sed 's/1.2.840.113635.100.6.1.13/1.2.3.4/' "$valid_requirement" > "$temporary_directory/wrong-certificate-requirement.txt"
expect_failure "constrained to Developer ID Application" assert_release_requirement "$temporary_directory/wrong-certificate-requirement.txt"
expect_failure "production identifier" assert_release_requirement \
    "$temporary_directory/debug-requirement.txt"

sed 's/subject.OU] = "REDACTED"/subject.OU] = "DIFFERENT"/' "$valid_requirement" > \
    "$temporary_directory/wrong-team-requirement.txt"
expect_failure "does not match the application team" assert_release_requirement \
    "$temporary_directory/wrong-team-requirement.txt" "REDACTED"

readonly valid_gatekeeper="$temporary_directory/valid-gatekeeper.txt"
cat > "$valid_gatekeeper" <<'TEXT'
/private/example/CopyLasso.app: accepted
source=Notarized Developer ID
origin=Developer ID Application: Redacted
TEXT
assert_notarized_gatekeeper "$valid_gatekeeper"

sed 's/Notarized Developer ID/Developer ID/' "$valid_gatekeeper" > \
    "$temporary_directory/unstapled-gatekeeper.txt"

sed 's/: accepted/: rejected/' "$valid_gatekeeper" > "$temporary_directory/rejected-gatekeeper.txt"
expect_failure "did not accept" assert_notarized_gatekeeper "$temporary_directory/rejected-gatekeeper.txt"

sed '/origin=/d' "$valid_gatekeeper" > "$temporary_directory/missing-origin-gatekeeper.txt"
expect_failure "did not recognize" assert_notarized_gatekeeper "$temporary_directory/missing-origin-gatekeeper.txt"
expect_failure "Notarized Developer ID" assert_notarized_gatekeeper \
    "$temporary_directory/unstapled-gatekeeper.txt"

echo "Developer ID release contract tests passed."
