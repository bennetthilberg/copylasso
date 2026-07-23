#!/bin/bash

set -euo pipefail
umask 077

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/release-workflow-verification.sh
source "$repository_root/scripts/lib/release-workflow-verification.sh"
# shellcheck source=scripts/lib/release-package-verification.sh
source "$repository_root/scripts/lib/release-package-verification.sh"

usage() {
    cat >&2 <<'TEXT'
Usage: build-release-candidate.sh \
  --source-commit <40-character-commit> \
  --handoff /path/under/RUNNER_TEMP/<commit> \
  --output-dir /path/to/repository/dist/<release-mode>/<commit>/run
TEXT
    exit 64
}

source_commit=""
handoff_candidate=""
output_directory=""
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --source-commit)
            [[ "$#" -ge 2 ]] || usage
            source_commit="$2"
            shift 2
            ;;
        --handoff)
            [[ "$#" -ge 2 ]] || usage
            handoff_candidate="$2"
            shift 2
            ;;
        --output-dir)
            [[ "$#" -ge 2 ]] || usage
            output_directory="$2"
            shift 2
            ;;
        *) usage ;;
    esac
done
[[ -n "$source_commit" && -n "$handoff_candidate" && -n "$output_directory" ]] || usage

assert_full_release_commit "$source_commit"
assert_release_source_state \
    "$repository_root" \
    "${GITHUB_REF:-refs/heads/main}" \
    "$source_commit"
assert_release_state_directory "$handoff_candidate"
[[ "$(basename "$handoff_candidate")" == "$source_commit" ]] || \
    protected_release_fail "The release handoff must be named for the exact protected commit."
[[ ! -e "$handoff_candidate" && ! -L "$handoff_candidate" ]] || \
    protected_release_fail "The protected release handoff already exists."

readonly expected_team_identifier="${COPYLASSO_EXPECTED_TEAM_ID:-}"
[[ "$expected_team_identifier" =~ ^[A-Z0-9]{10}$ ]] || \
    protected_release_fail "COPYLASSO_EXPECTED_TEAM_ID must provide the protected release team."
readonly keychain_path="${COPYLASSO_RELEASE_KEYCHAIN_PATH:-}"
[[ -f "$keychain_path" && "$keychain_path" == "${RUNNER_TEMP:-}"/* ]] || \
    protected_release_fail "The temporary protected release Keychain is unavailable."

/bin/mkdir -p "$handoff_candidate"
readonly archive="$handoff_candidate/CopyLasso.xcarchive"
readonly export_directory="$handoff_candidate/export"
readonly application="$export_directory/CopyLasso.app"
readonly source_packages="$handoff_candidate/SourcePackages"

cd "$repository_root"
if ! /usr/bin/xcodebuild -resolvePackageDependencies \
    -project CopyLasso.xcodeproj \
    -scheme CopyLasso \
    -clonedSourcePackagesDirPath "$source_packages" \
    > "$handoff_candidate/package-resolution.log" 2>&1; then
    protected_release_fail "The protected Release dependencies could not be resolved."
fi
if ! /usr/bin/xcodebuild archive \
    -project CopyLasso.xcodeproj \
    -scheme CopyLasso \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$archive" \
    -clonedSourcePackagesDirPath "$source_packages" \
    DEVELOPMENT_TEAM="$expected_team_identifier" \
    CODE_SIGN_STYLE=Manual \
    "CODE_SIGN_IDENTITY=Developer ID Application" \
    "OTHER_CODE_SIGN_FLAGS=--keychain $keychain_path" \
    > "$handoff_candidate/archive.log" 2>&1; then
    protected_release_fail "The protected Release archive could not be created."
fi

readonly runtime_export_options="$handoff_candidate/DeveloperIDCIExportOptions.plist"
cleanup_runtime_export_options() {
    /bin/rm -f "$runtime_export_options"
}
trap cleanup_runtime_export_options EXIT
/bin/cp Configuration/DeveloperIDCIExportOptions.plist "$runtime_export_options"
/usr/bin/plutil -insert teamID -string "$expected_team_identifier" \
    "$runtime_export_options"
if ! /usr/bin/xcodebuild -exportArchive \
    -archivePath "$archive" \
    -exportOptionsPlist "$runtime_export_options" \
    -exportPath "$export_directory" \
    > "$handoff_candidate/export.log" 2>&1; then
    protected_release_fail "The protected Developer ID archive could not be exported."
fi
cleanup_runtime_export_options
trap - EXIT

COPYLASSO_EXPECTED_TEAM_ID="$expected_team_identifier" \
    "$repository_root/scripts/verify-developer-id-app.sh" \
    --pre-notarization "$application" \
    > "$handoff_candidate/pre-notarization-verification.txt"

readonly application_zip="$handoff_candidate/CopyLasso-notarization.zip"
if ! /usr/bin/ditto -c -k --keepParent "$application" "$application_zip"; then
    protected_release_fail "The protected application could not be prepared for notarization."
fi
readonly application_submission="$handoff_candidate/notary-submission.json"
readonly application_log="$handoff_candidate/notary-log.json"
if ! xcrun notarytool submit "$application_zip" \
    --keychain-profile copylasso-notary \
    --keychain "$keychain_path" \
    --wait \
    --output-format json > "$application_submission"; then
    protected_release_fail "The protected application notarization submission did not complete."
fi
readonly application_submission_identifier="$(
    /usr/bin/plutil -extract id raw -o - "$application_submission" 2>/dev/null || true
)"
[[ -n "$application_submission_identifier" ]] || \
    protected_release_fail "The application notarization response has no submission identifier."
if ! xcrun notarytool log "$application_submission_identifier" \
    --keychain-profile copylasso-notary \
    --keychain "$keychain_path" \
    "$application_log" > "$handoff_candidate/notary-log-fetch.log" 2>&1; then
    protected_release_fail "The protected application notarization log could not be saved."
fi
assert_release_notary_records "$application_submission" "$application_log"

if ! xcrun stapler staple "$application" > "$handoff_candidate/staple.log" 2>&1; then
    protected_release_fail "The protected application notarization ticket could not be stapled."
fi
COPYLASSO_EXPECTED_TEAM_ID="$expected_team_identifier" \
    "$repository_root/scripts/verify-developer-id-app.sh" \
    --post-notarization "$application" \
    > "$handoff_candidate/post-notarization-verification.txt"

COPYLASSO_EXPECTED_TEAM_ID="$expected_team_identifier" \
    "$repository_root/scripts/package-release.sh" \
    --handoff "$handoff_candidate" \
    --payload-commit "$source_commit" \
    --output-dir "$output_directory"

echo "Protected release candidate built and verified for the exact protected commit."
