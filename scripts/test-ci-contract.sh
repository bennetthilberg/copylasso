#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ci_script="$repository_root/scripts/ci.sh"
readonly privacy_security_test_script="$repository_root/scripts/test-privacy-security.sh"
readonly brand_audit_script="$repository_root/scripts/audit-brand-release.sh"
readonly release_metadata_test_script="$repository_root/scripts/test-release-metadata.sh"
readonly developer_id_audit_script="$repository_root/scripts/audit-developer-id-release.sh"
readonly release_package_audit_script="$repository_root/scripts/audit-release-package.sh"
readonly release_workflow_audit_script="$repository_root/scripts/audit-release-workflow.sh"
readonly platform_qualification_audit_script="$repository_root/scripts/audit-platform-qualification.sh"
readonly platform_qualification_test_script="$repository_root/scripts/test-platform-qualification.sh"
readonly v02_contract_audit_script="$repository_root/scripts/audit-v02-contract.sh"
readonly v02_release_qualification_audit_script="$repository_root/scripts/audit-v02-release-qualification.sh"
readonly v02_publication_audit_script="$repository_root/scripts/audit-v02-publication.sh"
readonly v02_release_state_audit_script="$repository_root/scripts/audit-v02-release-state.sh"
readonly v02_publication_test_script="$repository_root/scripts/test-v02-publication.sh"
readonly code_recognition_audit_script="$repository_root/scripts/audit-code-recognition.sh"
readonly latex_feasibility_audit_script="$repository_root/scripts/audit-latex-feasibility.sh"
readonly latex_feasibility_test_script="$repository_root/scripts/test-latex-feasibility.sh"
readonly success_sound_audit_script="$repository_root/scripts/audit-success-sound.sh"
readonly secure_update_audit_script="$repository_root/scripts/audit-secure-update-architecture.sh"
readonly secure_update_test_script="$repository_root/scripts/test-secure-update-architecture.sh"
readonly secure_update_signature_script="$repository_root/scripts/test-secure-update-signatures.sh"
readonly draft_appcast_test_script="$repository_root/scripts/test-draft-appcast.sh"
readonly generated_app_cleanup_runner="$repository_root/scripts/run-with-generated-app-cleanup.sh"
readonly ordinary_release_cleanup="$repository_root/scripts/unregister-generated-release.sh"
readonly repeatability_script="$repository_root/scripts/test-repeatability.sh"
readonly workflow="$repository_root/.github/workflows/ci.yml"

fail() {
    echo "$1" >&2
    exit 1
}

checkout_count="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*uses:[[:space:]]+actions/checkout@' "$workflow" || true
})"
full_history_count="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*fetch-depth:[[:space:]]+0[[:space:]]*$' "$workflow" || true
})"
if [[ "$checkout_count" == "0" || "$full_history_count" != "$checkout_count" ]]; then
    fail "Every canonical CI checkout must fetch full history for release qualification."
fi

for qualification_pin in \
    'approved_post_candidate_path' \
    'expected_approved_post_candidate_patch_digest' \
    'approved_post_candidate_patch_digest'; do
    if ! /usr/bin/grep -Fq "$qualification_pin" \
        "$v02_release_qualification_audit_script"; then
        fail "The v0.2 qualification audit is missing post-candidate patch pinning: $qualification_pin"
    fi
done

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

privacy_security_test_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/test-privacy-security\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$privacy_security_test_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/test-privacy-security.sh exactly once."
fi

brand_audit_invocations="$({
    /usr/bin/grep -Ec '^[[:space:]]*\./scripts/audit-brand-release\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$brand_audit_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/audit-brand-release.sh exactly once."
fi
if ! /usr/bin/grep -Fq \
    "'/^## G32 - v0.1.1 Settings Hotfix$/,/^## G33 - Platform And Reinstall Qualification$/p'" \
    "$brand_audit_script"; then
    fail "The brand audit must bound historical G32 checklist accounting at G33."
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

platform_qualification_audit_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/audit-platform-qualification\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$platform_qualification_audit_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/audit-platform-qualification.sh exactly once."
fi

platform_qualification_test_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/test-platform-qualification\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$platform_qualification_test_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/test-platform-qualification.sh exactly once."
fi

v02_contract_audit_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/audit-v02-contract\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$v02_contract_audit_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/audit-v02-contract.sh exactly once."
fi

v02_release_qualification_audit_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/audit-v02-release-qualification\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$v02_release_qualification_audit_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/audit-v02-release-qualification.sh exactly once."
fi
for required_patch_guard in \
    "approved_post_publication_patch_tree_pattern" \
    "approved_post_publication_runtime_tree_pattern" \
    "approved_post_v02_security_patch_tree_pattern" \
    "g44_release_state_tree_pattern" \
    "expected_candidate_baseline_tree_digest='ecbcf39d0cac2b1525e46dc154123eb5418db3a9e790770a36a281b5160775bf'" \
    "expected_approved_post_publication_runtime_tree_digest='388191bdbca550efa34ca64d9f8ebba3f127457313e4f0739d4601919fa9de7d'" \
    "expected_g44_release_state_files_digest='8fefcac6d46e3ec19d11786ab3d5836c3c34fc476a1cad31efbfacc95d977039'" \
    "expected_approved_post_candidate_patch_digest='9238b21930c031d55da2bdbff0718125cf05c877b1207bed564d7a87841a680b'" \
    'cat-file -e "$candidate_source_commit^{tree}"' \
    'The qualified candidate commit is unavailable.' \
    '"$current_baseline_tree_digest" == "$expected_candidate_baseline_tree_digest"' \
    'approved_post_candidate_path "$approved_path"' \
    'hash-object -- "$approved_path"' \
    'expected_approved_post_candidate_patch_digest[^0-9a-f]*' \
    '<self-normalized>' \
    'The approved post-candidate patch differs from its reviewed digest.' \
    '/usr/bin/grep -Ev "$approved_post_v02_security_patch_tree_pattern"' \
    '/usr/bin/grep -Ev "$g44_release_state_tree_pattern"' \
    'The approved G43A runtime patch differs from its reviewed tree digest.'; do
    if ! /usr/bin/grep -Fq "$required_patch_guard" \
        "$v02_release_qualification_audit_script"; then
        fail "The v0.2 qualification audit must pin the exact approved G43A patch."
    fi
done

if /usr/bin/grep -Fq \
    ':(exclude)scripts/audit-v02-release-qualification.sh' \
    "$v02_release_qualification_audit_script" || \
    /usr/bin/grep -Fq \
        ':(exclude)scripts/test-ci-contract.sh' \
        "$v02_release_qualification_audit_script"; then
    fail "The post-candidate digest must pin its own audit and contract scripts."
fi

v02_publication_test_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/test-v02-publication\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$v02_publication_test_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/test-v02-publication.sh exactly once."
fi

v02_publication_audit_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/audit-v02-publication\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$v02_publication_audit_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/audit-v02-publication.sh exactly once."
fi

v02_release_state_audit_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/audit-v02-release-state\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$v02_release_state_audit_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/audit-v02-release-state.sh exactly once."
fi
for required_release_state_guard in \
    'expected_release_commit="43f1d0c676b08fb24b49fc628213fede90c4ed9d"' \
    'expected_release_id="361797888"' \
    'expected_dmg_sha256="697cb008cf294b32500e2ad84e5777a51fe8b88916856c5a8e9f1ec4eb74ba19"' \
    'expected_appcast_sha256="a6be6c899e31e5913d5be315f209884100f709bd0e13d7490da8f07c9ed08ace"' \
    'The Unreleased section must retain the post-v0.2 G43A fix.'; do
    if ! /usr/bin/grep -Fq -- "$required_release_state_guard" \
        "$v02_release_state_audit_script"; then
        fail "The G44 audit must pin the immutable public release and post-release boundary."
    fi
done

code_recognition_audit_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/audit-code-recognition\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$code_recognition_audit_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/audit-code-recognition.sh exactly once."
fi

latex_feasibility_test_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/test-latex-feasibility\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$latex_feasibility_test_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/test-latex-feasibility.sh exactly once."
fi

latex_feasibility_audit_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/audit-latex-feasibility\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$latex_feasibility_audit_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/audit-latex-feasibility.sh exactly once."
fi

if /usr/bin/grep -Fq 'actual_production_digest' "$latex_feasibility_audit_script"; then
    fail "The G39 audit must not pin future production checkouts to the historical G38 tree."
fi
/usr/bin/grep -Fq 'g38-production-tree.manifest' "$latex_feasibility_audit_script" || \
    fail "The G39 audit must bind its historical production boundary to a reviewed manifest."

latex_feasibility_format_paths="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*Tools/LaTeXFeasibility[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$latex_feasibility_format_paths" != "1" ]]; then
    fail "Canonical CI must lint the isolated LaTeX feasibility tool exactly once."
fi

success_sound_audit_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/audit-success-sound\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$success_sound_audit_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/audit-success-sound.sh exactly once."
fi

secure_update_audit_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/audit-secure-update-architecture\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$secure_update_audit_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/audit-secure-update-architecture.sh exactly once."
fi

secure_update_test_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/test-secure-update-architecture\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$secure_update_test_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/test-secure-update-architecture.sh exactly once."
fi

secure_update_signature_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/test-secure-update-signatures\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$secure_update_signature_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/test-secure-update-signatures.sh exactly once."
fi

draft_appcast_test_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/test-draft-appcast\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$draft_appcast_test_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/test-draft-appcast.sh exactly once."
fi

if [[ ! -x "$developer_id_audit_script" ]] || \
    [[ ! -x "$repository_root/scripts/verify-developer-id-app.sh" ]] || \
    [[ ! -x "$repository_root/scripts/test-developer-id-release.sh" ]]; then
    fail "Developer ID release verification scripts must be executable."
fi

if [[ ! -x "$release_metadata_test_script" ]]; then
    fail "Release metadata contract tests must be executable."
fi

if [[ ! -x "$privacy_security_test_script" ]]; then
    fail "Privacy and security project-contract tests must be executable."
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

if [[ ! -x "$platform_qualification_audit_script" ]] || \
    [[ ! -x "$platform_qualification_test_script" ]] || \
    [[ ! -x "$generated_app_cleanup_runner" ]] || \
    [[ ! -x "$ordinary_release_cleanup" ]]; then
    fail "Platform-qualification and generated-app cleanup scripts must be executable."
fi

if [[ ! -x "$v02_contract_audit_script" ]]; then
    fail "The v0.2 product-contract audit must be executable."
fi

if [[ ! -x "$v02_release_qualification_audit_script" ]]; then
    fail "The v0.2 release-qualification audit must be executable."
fi

if [[ ! -x "$v02_publication_audit_script" ]] || \
    [[ ! -x "$v02_publication_test_script" ]]; then
    fail "The v0.2 publication audit and focused tests must be executable."
fi

if [[ ! -x "$code_recognition_audit_script" ]] || \
    [[ ! -x "$repository_root/scripts/generate-code-fixtures.swift" ]]; then
    fail "The code-recognition audit and deterministic fixture generator must be executable."
fi

if [[ ! -x "$latex_feasibility_audit_script" ]] || \
    [[ ! -x "$latex_feasibility_test_script" ]]; then
    fail "The offline LaTeX feasibility test and audit must be executable."
fi
if [[ "$(/usr/bin/head -n 1 "$repository_root/scripts/generate-code-fixtures.swift")" != \
    '#!/usr/bin/env -S xcrun swift' ]]; then
    fail "The executable code-fixture generator must split its xcrun Swift interpreter arguments."
fi

if [[ ! -x "$success_sound_audit_script" ]] || \
    [[ ! -f "$repository_root/scripts/generate-success-sound.swift" ]]; then
    fail "The configurable success-sound audit and generator must be available."
fi

if ! /usr/bin/grep -Fq \
    'COPYLASSO_SUCCESS_SOUND_DEBUG_APP="$derived_data/Build/Products/Debug/CopyLasso.app" \' \
    "$ci_script" || \
    ! /usr/bin/grep -Fq \
      'COPYLASSO_SUCCESS_SOUND_RELEASE_APP="$release_application" \' \
      "$ci_script"; then
    fail "Canonical CI must audit the built Debug and Universal 2 success-sound resources."
fi

if [[ ! -x "$secure_update_audit_script" ]] || \
    [[ ! -x "$secure_update_test_script" ]] || \
    [[ ! -x "$secure_update_signature_script" ]] || \
    [[ ! -x "$draft_appcast_test_script" ]]; then
    fail "Secure-update architecture proof scripts must be executable."
fi

if ! /usr/bin/grep -Fq \
    'COPYLASSO_SPARKLE_TOOLS_DIR="$(/usr/bin/dirname "$sparkle_sign_update")" \' \
    "$ci_script"; then
    fail "Canonical CI must run the signature proof with its resolved Sparkle tools."
fi
if ! /usr/bin/grep -Fq \
    'COPYLASSO_SECURE_UPDATE_DEBUG_APP="$derived_data/Build/Products/Debug/CopyLasso.app" \' \
    "$ci_script"; then
    fail "Canonical CI must audit its updater-enabled Debug application."
fi
if ! /usr/bin/grep -Fq \
    'COPYLASSO_SECURE_UPDATE_RELEASE_APP="$release_application" \' \
    "$ci_script"; then
    fail "Canonical CI must audit its updater-enabled Universal 2 Release application."
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

generated_app_cleanup_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/run-with-generated-app-cleanup\.sh[[:space:]]*\\$' \
        "$ci_script" || true
})"
if [[ "$generated_app_cleanup_invocations" != "1" ]] || \
    ! /usr/bin/grep -Fq '"$release_application" \' "$ci_script" || \
    ! /usr/bin/grep -Fq 'COPYLASSO_GENERATED_CLEANUP_WRAPPED=1 \' "$ci_script"; then
    fail "Canonical CI must safely clean its generated Release registration exactly once."
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

if /usr/bin/grep -Eq 'runs-on:[[:space:]]*macos-14([[:space:]]|$)' "$workflow" || \
    ! /usr/bin/grep -Fq 'runs-on: macos-15' "$workflow" || \
    ! /usr/bin/grep -Fq 'COPYLASSO_MINIMUM_OS_MAJOR: "15"' "$workflow" || \
    ! /usr/bin/grep -Fq './scripts/test-minimum-macos.sh' "$workflow"; then
    fail "Hosted runtime smoke must use macOS 15 while retaining minimum-version checks."
fi

"$repository_root/scripts/test-xctest-harness-retry.sh"

echo "CopyLasso CI repeatability contract passed."
