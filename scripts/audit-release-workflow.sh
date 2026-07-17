#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly workflow="$repository_root/.github/workflows/release.yml"
readonly ci_workflow="$repository_root/.github/workflows/ci.yml"
readonly source_verifier="$repository_root/scripts/verify-release-workflow-source.sh"
readonly credential_preparer="$repository_root/scripts/prepare-release-keychain.sh"
readonly credential_cleanup="$repository_root/scripts/cleanup-release-keychain.sh"
readonly candidate_builder="$repository_root/scripts/build-release-candidate.sh"
readonly ci_export_options="$repository_root/Configuration/DeveloperIDCIExportOptions.plist"
readonly draft_creator="$repository_root/scripts/create-draft-release.sh"
readonly verification_library="$repository_root/scripts/lib/release-workflow-verification.sh"
readonly focused_tests="$repository_root/scripts/test-release-workflow.sh"
readonly documentation="$repository_root/docs/release-workflow.md"
readonly release_checklist="$repository_root/docs/release-checklist.md"

fail() {
    echo "$1" >&2
    exit 1
}

require_text() {
    local file="$1"
    local text="$2"

    /usr/bin/grep -Fq -- "$text" "$file" || \
        fail "Protected-release contract text is missing: $text"
}

for executable in \
    "$source_verifier" \
    "$credential_preparer" \
    "$credential_cleanup" \
    "$candidate_builder" \
    "$draft_creator" \
    "$focused_tests"; do
    [[ -x "$executable" ]] || \
        fail "Protected-release script is missing or not executable: $(basename "$executable")"
done
for readable in \
    "$workflow" \
    "$ci_workflow" \
    "$ci_export_options" \
    "$verification_library" \
    "$documentation" \
    "$release_checklist"; do
    [[ -r "$readable" ]] || \
        fail "Protected-release contract file is missing: $(basename "$readable")"
done

/usr/bin/plutil -lint "$ci_export_options" >/dev/null
[[ "$(/usr/bin/plutil -extract method raw -o - "$ci_export_options")" == "developer-id" ]] || \
    fail "The hosted release export method must be developer-id."
[[ "$(/usr/bin/plutil -extract destination raw -o - "$ci_export_options")" == "export" ]] || \
    fail "The hosted release destination must be export."
[[ "$(/usr/bin/plutil -extract signingStyle raw -o - "$ci_export_options")" == "manual" ]] || \
    fail "The hosted release export must use the imported identity without an Xcode account."
[[ "$(/usr/bin/plutil -extract signingCertificate raw -o - "$ci_export_options")" == \
    "Developer ID Application" ]] || \
    fail "The hosted release export must select Developer ID Application."
for prohibited_key in teamID provisioningProfiles installerSigningCertificate; do
    if /usr/bin/plutil -extract "$prohibited_key" raw -o - "$ci_export_options" >/dev/null 2>&1; then
        fail "Hosted release export options must not commit $prohibited_key."
    fi
done

require_text "$workflow" 'workflow_dispatch:'
for prohibited_trigger in pull_request: pull_request_target: push: repository_dispatch: workflow_run:; do
    if /usr/bin/grep -Eq "^[[:space:]]*${prohibited_trigger}[[:space:]]*$" "$workflow"; then
        fail "The protected release workflow has a prohibited trigger: $prohibited_trigger"
    fi
done
require_text "$ci_workflow" 'workflow_call:'
require_text "$workflow" 'uses: ./.github/workflows/ci.yml'
require_text "$workflow" 'needs: quality-gate'
require_text "$workflow" 'environment:'
require_text "$workflow" 'name: release'
require_text "$workflow" 'cancel-in-progress: false'

contents_write_count="$(/usr/bin/grep -Ec '^[[:space:]]*contents: write[[:space:]]*$' "$workflow")"
[[ "$contents_write_count" == "1" ]] || \
    fail "Only the protected draft job may receive contents write permission."
require_text "$workflow" 'permissions:'
require_text "$workflow" 'contents: read'

require_text "$workflow" 'actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0'
require_text "$workflow" 'ref: ${{ github.sha }}'
require_text "$workflow" 'fetch-depth: 0'
require_text "$workflow" 'persist-credentials: false'
while IFS= read -r action_target; do
    case "$action_target" in
        ./*) ;;
        *@????????????????????????????????????????) ;;
        *) fail "The privileged release workflow contains a mutable action reference: $action_target" ;;
    esac
done < <(/usr/bin/sed -nE 's/^[[:space:]]*uses:[[:space:]]*([^[:space:]]+).*$/\1/p' "$workflow")

for secret in \
    COPYLASSO_DEVELOPER_ID_P12_BASE64 \
    COPYLASSO_DEVELOPER_ID_P12_PASSWORD \
    COPYLASSO_NOTARY_KEY_BASE64 \
    COPYLASSO_NOTARY_KEY_ID \
    COPYLASSO_NOTARY_ISSUER_ID \
    COPYLASSO_EXPECTED_TEAM_ID; do
    secret_count="$(/usr/bin/grep -Fc 'secrets.'"$secret" "$workflow")"
    [[ "$secret_count" -ge 1 ]] || \
        fail "The protected release workflow is missing an environment secret: $secret"
    if /usr/bin/grep -Fq "secrets.$secret" "$ci_workflow"; then
        fail "Ordinary CI must never receive protected release secrets: $secret"
    fi
done

require_text "$workflow" './scripts/verify-release-workflow-source.sh'
require_text "$workflow" './scripts/prepare-release-keychain.sh'
require_text "$workflow" './scripts/build-release-candidate.sh'
require_text "$workflow" './scripts/cleanup-release-keychain.sh'
require_text "$workflow" './scripts/create-draft-release.sh'
require_text "$workflow" 'if: always()'

build_line="$(/usr/bin/grep -n './scripts/build-release-candidate.sh' "$workflow" | /usr/bin/cut -d: -f1)"
cleanup_line="$(/usr/bin/grep -n './scripts/cleanup-release-keychain.sh' "$workflow" | /usr/bin/cut -d: -f1)"
draft_line="$(/usr/bin/grep -n './scripts/create-draft-release.sh' "$workflow" | /usr/bin/cut -d: -f1)"
if ((cleanup_line <= build_line || draft_line <= cleanup_line)); then
    fail "Credential cleanup must follow packaging and precede draft creation."
fi

for required_prepare_text in \
    'assert_release_secret_contract' \
    'assert_release_state_directory' \
    'security create-keychain' \
    'security import' \
    'security set-key-partition-list' \
    'notarytool store-credentials copylasso-notary' \
    'notarytool history' \
    'cleanup_raw_credentials'; do
    require_text "$credential_preparer" "$required_prepare_text"
done
for required_cleanup_text in \
    'cleanup_failed=' \
    'security default-keychain' \
    'security list-keychains' \
    'security delete-keychain' \
    'rm -rf "$state_directory"' \
    'Temporary release credentials were removed.'; do
    require_text "$credential_cleanup" "$required_cleanup_text"
done

for required_build_text in \
    'xcodebuild archive' \
    'xcodebuild -exportArchive' \
    'Configuration/DeveloperIDCIExportOptions.plist' \
    'verify-developer-id-app.sh' \
    'notarytool submit' \
    'notarytool log' \
    'stapler staple' \
    'package-release.sh' \
    'assert_release_workflow_assets'; do
    require_text "$candidate_builder" "$required_build_text"
done

for required_draft_text in \
    'draft=true' \
    'prerelease=true' \
    'make_latest=false' \
    'release upload' \
    '--method DELETE' \
    'assert_release_draft_record'; do
    require_text "$draft_creator" "$required_draft_text"
done
if /usr/bin/grep -Eiq -- \
    'release (publish|edit.+--draft=false)|--clobber|make_latest=true' \
    "$draft_creator" "$workflow"; then
    fail "The G28 workflow must never publish, overwrite, or promote its draft."
fi

for required_documentation_text in \
    'protected branches only' \
    'required reviewer' \
    'self-review allowed' \
    'Team API key' \
    'password-protected PKCS#12' \
    'workflow_dispatch' \
    'refs/heads/main' \
    'pull-request workflow has no release trigger' \
    'credential cleanup' \
    'Draft creation is transactional' \
    'Never publish the G28 rehearsal' \
    'G29' \
    'G30'; do
    require_text "$documentation" "$required_documentation_text"
done
require_text "$release_checklist" 'Keep the dSYM and verification bundle restricted to the draft'

if /usr/bin/grep -Eq 'set -x|TeamIdentifier=[A-Z0-9]{10}|[[:alnum:]._%+-]+@[[:alnum:].-]+\.[A-Za-z]{2,}|[a-z]{4}-[a-z]{4}-[a-z]{4}-[a-z]{4}' \
    "$workflow" \
    "$source_verifier" \
    "$credential_preparer" \
    "$credential_cleanup" \
    "$candidate_builder" \
    "$draft_creator" \
    "$verification_library" \
    "$documentation"; then
    fail "Protected-release public files contain unsafe tracing or credential-like material."
fi

echo "Protected-release workflow static audit passed."
