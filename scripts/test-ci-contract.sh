#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ci_script="$repository_root/scripts/ci.sh"
readonly brand_audit_script="$repository_root/scripts/audit-brand-release.sh"
readonly release_metadata_test_script="$repository_root/scripts/test-release-metadata.sh"
readonly developer_id_audit_script="$repository_root/scripts/audit-developer-id-release.sh"
readonly release_package_audit_script="$repository_root/scripts/audit-release-package.sh"
readonly release_workflow_audit_script="$repository_root/scripts/audit-release-workflow.sh"
readonly repeatability_script="$repository_root/scripts/test-repeatability.sh"
readonly workflow="$repository_root/.github/workflows/ci.yml"

fail() {
    echo "$1" >&2
    exit 1
}

repeatability_invocations="$({
    /usr/bin/grep -Ec '^[[:space:]]*\./scripts/test-repeatability\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$repeatability_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/test-repeatability.sh exactly once."
fi

contract_invocations="$({
    /usr/bin/grep -Ec '^[[:space:]]*\./scripts/test-ci-contract\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$contract_invocations" != "1" ]]; then
    fail "Canonical CI must run its repeatability contract exactly once."
fi

brand_audit_invocations="$({
    /usr/bin/grep -Ec '^[[:space:]]*\./scripts/audit-brand-release\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$brand_audit_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/audit-brand-release.sh exactly once."
fi

release_metadata_test_invocations="$({
    /usr/bin/grep -Ec '^[[:space:]]*\./scripts/test-release-metadata\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$release_metadata_test_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/test-release-metadata.sh exactly once."
fi

developer_id_audit_invocations="$({
    /usr/bin/grep -Ec '^[[:space:]]*\./scripts/audit-developer-id-release\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$developer_id_audit_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/audit-developer-id-release.sh exactly once."
fi

developer_id_test_invocations="$({
    /usr/bin/grep -Ec '^[[:space:]]*\./scripts/test-developer-id-release\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$developer_id_test_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/test-developer-id-release.sh exactly once."
fi

release_package_audit_invocations="$({
    /usr/bin/grep -Ec '^[[:space:]]*\./scripts/audit-release-package\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$release_package_audit_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/audit-release-package.sh exactly once."
fi

release_package_test_invocations="$({
    /usr/bin/grep -Ec '^[[:space:]]*\./scripts/test-release-package\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$release_package_test_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/test-release-package.sh exactly once."
fi

release_workflow_audit_invocations="$({
    /usr/bin/grep -Ec '^[[:space:]]*\./scripts/audit-release-workflow\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$release_workflow_audit_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/audit-release-workflow.sh exactly once."
fi

release_workflow_test_invocations="$({
    /usr/bin/grep -Ec '^[[:space:]]*\./scripts/test-release-workflow\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$release_workflow_test_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/test-release-workflow.sh exactly once."
fi

if [[ ! -x "$developer_id_audit_script" ]] || \
    [[ ! -x "$repository_root/scripts/verify-developer-id-app.sh" ]] || \
    [[ ! -x "$repository_root/scripts/test-developer-id-release.sh" ]]; then
    fail "Developer ID release verification scripts must be executable."
fi

if [[ ! -x "$release_metadata_test_script" ]]; then
    fail "Release metadata contract tests must be executable."
fi

if [[ ! -x "$release_package_audit_script" ]] || \
    [[ ! -x "$repository_root/scripts/package-release.sh" ]] || \
    [[ ! -x "$repository_root/scripts/verify-release-package.sh" ]] || \
    [[ ! -x "$repository_root/scripts/compare-release-packages.sh" ]] || \
    [[ ! -x "$repository_root/scripts/test-release-package.sh" ]]; then
    fail "Release-package verification scripts must be executable."
fi

if [[ ! -x "$release_workflow_audit_script" ]] || \
    [[ ! -x "$repository_root/scripts/test-release-workflow.sh" ]] || \
    [[ ! -x "$repository_root/scripts/build-release-candidate.sh" ]] || \
    [[ ! -x "$repository_root/scripts/create-draft-release.sh" ]]; then
    fail "Protected-release workflow scripts must be executable."
fi

if ! /usr/bin/grep -Fq \
    'COPYLASSO_BRAND_AUDIT_OUTPUT="$derived_data/brand-release-audit" \' \
    "$ci_script"; then
    fail "Each canonical architecture must isolate its brand-audit output."
fi

if ! /usr/bin/grep -Fq 'audit_output_parent_canonical' "$brand_audit_script" || \
    ! /usr/bin/grep -Fq 'cd "$audit_output_parent" 2>/dev/null && /bin/pwd -P' \
        "$brand_audit_script"; then
    fail "The brand audit must canonicalize its cleanup path before accepting it."
fi

if [[ ! -x "$repository_root/scripts/retry-xctest-harness.sh" ]] || \
    [[ ! -x "$repository_root/scripts/test-xctest-harness-retry.sh" ]]; then
    fail "Canonical CI must retain its focused XCTest harness retry contract."
fi

harness_retry_invocations="$({
    /usr/bin/grep -Ec '^[[:space:]]*\./scripts/retry-xctest-harness\.sh[[:space:]]*\\$' \
        "$ci_script" || true
})"
if [[ "$harness_retry_invocations" != "1" ]]; then
    fail "Canonical CI must guard its primary XCTest launch exactly once."
fi

test_host_icon_suppressions="$({
    /usr/bin/grep -Fc 'ASSETCATALOG_COMPILER_APPICON_NAME=' "$ci_script" || true
})"
if [[ "$test_host_icon_suppressions" != "1" ]]; then
    fail "Canonical CI must isolate the headless XCTest host from Icon Services exactly once."
fi

if /usr/bin/grep -Fq '/Applications/Xcode.app' "$brand_audit_script" || \
    ! /usr/bin/grep -Fq 'DEVELOPER_DIR:-$(/usr/bin/xcode-select -p)' \
        "$brand_audit_script"; then
    fail "The brand audit must locate Icon Composer from the active Xcode developer directory."
fi

if ! /usr/bin/grep -Fq 'COPYLASSO_CI_ARCH="$requested_architecture" \' "$ci_script" || \
    ! /usr/bin/grep -Fq 'COPYLASSO_REPEAT_DERIVED_DATA_PATH="$derived_data" \' "$ci_script" || \
    ! /usr/bin/grep -Fq 'COPYLASSO_REPEAT_COUNT=3 \' "$ci_script"; then
    fail "Canonical CI must pass its architecture, existing DerivedData, and exact repeat count."
fi

build_for_testing_line="$(/usr/bin/grep -n '^xcodebuild build-for-testing' "$ci_script" | \
    /usr/bin/cut -d: -f1)"
repeatability_line="$(/usr/bin/grep -nE \
    '^[[:space:]]*\./scripts/test-repeatability\.sh[[:space:]]*$' "$ci_script" | \
    /usr/bin/cut -d: -f1)"
offline_line="$(/usr/bin/grep -nE \
    '^[[:space:]]*\./scripts/test-offline\.sh[[:space:]]*$' "$ci_script" | \
    /usr/bin/cut -d: -f1)"
release_line="$(/usr/bin/grep -n '^echo "Building Universal 2 Release"' "$ci_script" | \
    /usr/bin/cut -d: -f1)"
if ((repeatability_line <= build_for_testing_line || repeatability_line >= release_line)); then
    fail "Repeatability must reuse the built unit bundle before the Release build."
fi

offline_block="$(/usr/bin/sed -n "$((offline_line - 2)),${offline_line}p" "$ci_script")"
if ! /usr/bin/grep -Fq 'COPYLASSO_CI_ARCH="$requested_architecture" \' \
    <<< "$offline_block" || \
    ! /usr/bin/grep -Fq 'COPYLASSO_OFFLINE_DERIVED_DATA_PATH="$derived_data" \' \
        <<< "$offline_block"; then
    fail "Canonical offline tests must receive the requested architecture and existing DerivedData."
fi

if ! /usr/bin/grep -Fq '/usr/bin/xcodebuild test-without-building \' \
    "$repeatability_script" || \
    /usr/bin/grep -Eq '/usr/bin/xcodebuild (build|build-for-testing|test) ' \
        "$repeatability_script" || \
    ! /usr/bin/grep -Fq -- '-only-testing:CopyLassoTests' "$repeatability_script" || \
    /usr/bin/grep -Fq 'CopyLassoUITests' "$repeatability_script"; then
    fail "Repeatability must run only the already-built unit bundle without UI tests."
fi

workflow_ci_invocations="$({
    /usr/bin/grep -Ec '^[[:space:]]*run: \./scripts/ci\.sh[[:space:]]*$' "$workflow" || true
})"
if [[ "$workflow_ci_invocations" != "1" ]] || \
    ! /usr/bin/grep -Fq 'architecture: arm64' "$workflow" || \
    ! /usr/bin/grep -Fq 'architecture: x86_64' "$workflow" || \
    ! /usr/bin/grep -Fq 'COPYLASSO_CI_ARCH: ${{ matrix.architecture }}' "$workflow"; then
    fail "Both GitHub architecture jobs must enter through canonical CI."
fi

"$repository_root/scripts/test-xctest-harness-retry.sh"

echo "CopyLasso CI repeatability contract passed."
