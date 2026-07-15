#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly export_options="$repository_root/Configuration/DeveloperIDExportOptions.plist"
readonly verifier="$repository_root/scripts/verify-developer-id-app.sh"
readonly verifier_library="$repository_root/scripts/lib/developer-id-verification.sh"
readonly focused_tests="$repository_root/scripts/test-developer-id-release.sh"
readonly signing_documentation="$repository_root/docs/developer-id-signing.md"
readonly release_checklist="$repository_root/docs/release-checklist.md"

fail() {
    echo "$1" >&2
    exit 1
}

require_text() {
    local file="$1"
    local required="$2"
    /usr/bin/grep -Fq -- "$required" "$file" ||
        fail "Required Developer ID text is missing: $required"
}

cd "$repository_root"

[[ -f "$export_options" ]] || fail "Developer ID export options are missing."
[[ -x "$verifier" ]] || fail "Developer ID application verifier is missing or not executable."
[[ -r "$verifier_library" ]] || fail "Developer ID verification library is missing."
[[ -x "$focused_tests" ]] || fail "Developer ID focused tests are missing or not executable."
[[ -f "$signing_documentation" ]] || fail "Developer ID signing documentation is missing."

/usr/bin/plutil -lint "$export_options" >/dev/null
[[ "$(/usr/bin/plutil -extract method raw -o - "$export_options")" == "developer-id" ]] ||
    fail "The export method must be developer-id."
[[ "$(/usr/bin/plutil -extract destination raw -o - "$export_options")" == "export" ]] ||
    fail "The Developer ID destination must be export."
[[ "$(/usr/bin/plutil -extract signingStyle raw -o - "$export_options")" == "automatic" ]] ||
    fail "Developer ID export must use automatic signing."
[[ "$(/usr/bin/plutil -extract manageAppVersionAndBuildNumber raw -o - "$export_options")" == "false" ]] ||
    fail "Developer ID export must preserve the reviewed version and build."

for prohibited_key in teamID signingCertificate provisioningProfiles installerSigningCertificate; do
    if /usr/bin/plutil -extract "$prohibited_key" raw -o - "$export_options" >/dev/null 2>&1; then
        fail "Developer ID export options must not commit $prohibited_key."
    fi
done
debug_identifier_count="$(/usr/bin/grep -c 'PRODUCT_BUNDLE_IDENTIFIER = io.github.bennetthilberg.copylasso.debug;' CopyLasso.xcodeproj/project.pbxproj)"
release_identifier_count="$(/usr/bin/grep -c 'PRODUCT_BUNDLE_IDENTIFIER = io.github.bennetthilberg.copylasso;' CopyLasso.xcodeproj/project.pbxproj)"
if [[ "$debug_identifier_count" != 1 || "$release_identifier_count" != 1 ]]; then
    fail "Debug and Release must retain their distinct fixed bundle identifiers."
fi
hardened_runtime_count="$(/usr/bin/grep -c 'ENABLE_HARDENED_RUNTIME = YES;' CopyLasso.xcodeproj/project.pbxproj)"
entitlements_count="$(/usr/bin/grep -c 'CODE_SIGN_ENTITLEMENTS = CopyLasso/CopyLasso.entitlements;' CopyLasso.xcodeproj/project.pbxproj)"
if [[ "$hardened_runtime_count" != 2 || "$entitlements_count" != 2 ]]; then
    fail "Debug and Release must retain Hardened Runtime and the reviewed entitlements file."
fi

require_text "$signing_documentation" 'Developer ID Application'
require_text "$signing_documentation" 'copylasso-notary'
require_text "$signing_documentation" 'notarytool store-credentials'
require_text "$signing_documentation" 'login.keychain-db'
require_text "$signing_documentation" 'Team API key'
require_text "$signing_documentation" 'Developer role'
require_text "$signing_documentation" '--key-id "$COPYLASSO_NOTARY_KEY_ID"'
require_text "$signing_documentation" '--issuer "$COPYLASSO_NOTARY_ISSUER_ID"'
require_text "$signing_documentation" 'COPYLASSO_EXPECTED_TEAM_ID'
require_text "$signing_documentation" 'G26_OUTPUT="$HOME/Library/Developer/CopyLasso/G26/$G26_COMMIT"'
require_text "$signing_documentation" 'notary-submission.json'
require_text "$signing_documentation" 'notarytool log "$COPYLASSO_SUBMISSION_ID"'
require_text "$signing_documentation" 'notary-log.json'
require_text "$signing_documentation" 'notarytool submit'
require_text "$signing_documentation" 'stapler staple'
require_text "$signing_documentation" 'verify-developer-id-app.sh'
require_text "$signing_documentation" 'Configuration/DeveloperIDExportOptions.plist'
require_text "$signing_documentation" 'Do not print or commit'
require_text "$release_checklist" 'without recording the identifier itself'
require_text "$verifier" '>"$temporary_directory/requirement-$architecture.txt"'
require_text "$verifier" 'assert_nested_developer_id_signature'
require_text "$verifier" '--architecture "$architecture"'
require_text "$verifier" '--entitlements - --xml'
require_text "$verifier" 'COPYLASSO_EXPECTED_TEAM_ID'
require_text "$verifier" 'bundle_contains_mach_o "$nested_bundle"'

if /usr/bin/grep -Fq -- '--apple-id' "$signing_documentation"; then
    fail "Developer ID signing documentation must use the approved API-key profile."
fi

echo "CopyLasso Developer ID release audit passed."
