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
readonly g46_product_patch_audit_script="$repository_root/scripts/audit-g46-product-patch.sh"
readonly g48_patch_qualification_audit_script="$repository_root/scripts/audit-g48-patch-qualification.sh"
readonly g49_publication_audit_script="$repository_root/scripts/audit-g49-publication.sh"
readonly g50_sparkle_hotfix_audit_script="$repository_root/scripts/audit-g50-sparkle-hotfix.sh"
readonly g50_publication_audit_script="$repository_root/scripts/audit-g50-publication.sh"
readonly g50_publication_test_script="$repository_root/scripts/test-g50-publication.sh"
readonly v02_publication_test_script="$repository_root/scripts/test-v02-publication.sh"
readonly code_recognition_audit_script="$repository_root/scripts/audit-code-recognition.sh"
readonly multilingual_ocr_audit_script="$repository_root/scripts/audit-multilingual-ocr.sh"
readonly capture_history_audit_script="$repository_root/scripts/audit-capture-history.sh"
readonly interface_copy_audit_script="$repository_root/scripts/audit-interface-copy.sh"
readonly v03_release_qualification_audit_script="$repository_root/scripts/audit-v03-release-qualification.sh"
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

v03_release_qualification_audit_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/audit-v03-release-qualification\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$v03_release_qualification_audit_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/audit-v03-release-qualification.sh exactly once."
fi
for required_patch_guard in \
    "approved_post_publication_patch_tree_pattern" \
    "approved_post_publication_runtime_tree_pattern" \
    "approved_post_v02_security_patch_tree_pattern" \
    "g46_product_patch_tree_pattern" \
    "g44_release_state_tree_pattern" \
    "g48_patch_tree_pattern" \
    "g50_publication_tree_pattern" \
    "g51_multilingual_ocr_tree_pattern" \
    "g52_capture_history_tree_pattern" \
    "g52_capture_history_coverage_tree_pattern" \
    "g53_interface_copy_tree_pattern" \
    "g54_release_qualification_tree_pattern" \
    "expected_candidate_baseline_tree_digest='1e4844388bc872b8ac4644a13b00223af1239f431d390130346daa8e914aafa0'" \
    "expected_g48_baseline_tree_digest='6a19b6d447e87870956772e7dcdaa11dedd02c0ce1f98d3ed02e766cf29cd9de'" \
    "expected_approved_post_publication_runtime_tree_digest='4269c2cc3177b938de424c53b42de94c63528f1a66ec79b97fea0de76ec095c0'" \
    "g51_source_base_commit='5491bdc2ebf60872e0fababdc70c377e54a2e6f8'" \
    "expected_g44_release_state_files_digest='8fefcac6d46e3ec19d11786ab3d5836c3c34fc476a1cad31efbfacc95d977039'" \
    "expected_approved_post_candidate_patch_digest='5099ba73f4a10d2122190fc84ef437dd682f6a7b98b43f487a235a04911ccf41'" \
    'cat-file -e "$candidate_source_commit^{tree}"' \
    'The qualified candidate commit is unavailable.' \
    'cat-file -e "$g51_source_base_commit^{tree}"' \
    'The pre-G51 source commit is unavailable.' \
    '"$current_baseline_tree_digest" == "$expected_g48_baseline_tree_digest"' \
    'approved_post_candidate_path "$approved_path"' \
    'hash-object -- "$approved_path"' \
    'expected_approved_post_candidate_patch_digest[^0-9a-f]*' \
    'expected_g48_baseline_tree_digest[^0-9a-f]*' \
    'expected_g44_release_state_files_digest[^0-9a-f]*' \
    '<self-normalized>' \
    'The approved post-candidate patch differs from its reviewed digest:' \
    '/usr/bin/grep -Ev "$approved_post_v02_security_patch_tree_pattern"' \
    '/usr/bin/grep -Ev "$g46_product_patch_tree_pattern"' \
    '/usr/bin/grep -Ev "$g44_release_state_tree_pattern"' \
    '/usr/bin/grep -Ev "$g48_patch_tree_pattern"' \
    '/usr/bin/grep -Ev "$g50_security_hotfix_tree_pattern"' \
    '/usr/bin/grep -Ev "$g50_publication_tree_pattern"' \
    '/usr/bin/grep -Ev "$g51_multilingual_ocr_tree_pattern"' \
    '/usr/bin/grep -Ev "$g52_capture_history_tree_pattern"' \
    '/usr/bin/grep -Ev "$g52_capture_history_coverage_tree_pattern"' \
    '/usr/bin/grep -Ev "$g53_interface_copy_tree_pattern"' \
    'ls-tree -r --full-tree "$g51_source_base_commit"' \
    'The approved G43A runtime patch differs from its reviewed tree digest.'; do
    if ! /usr/bin/grep -Fq "$required_patch_guard" \
        "$v02_release_qualification_audit_script"; then
        fail "The v0.2 qualification audit must pin the exact approved post-candidate patch."
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

g46_product_patch_audit_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/audit-g46-product-patch\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$g46_product_patch_audit_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/audit-g46-product-patch.sh exactly once."
fi
g48_patch_qualification_audit_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/audit-g48-patch-qualification\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$g48_patch_qualification_audit_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/audit-g48-patch-qualification.sh exactly once."
fi
g49_publication_audit_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/audit-g49-publication\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$g49_publication_audit_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/audit-g49-publication.sh exactly once."
fi
g50_sparkle_hotfix_audit_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/audit-g50-sparkle-hotfix\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$g50_sparkle_hotfix_audit_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/audit-g50-sparkle-hotfix.sh exactly once."
fi
g50_publication_test_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/test-g50-publication\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$g50_publication_test_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/test-g50-publication.sh exactly once."
fi
g50_publication_audit_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/audit-g50-publication\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$g50_publication_audit_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/audit-g50-publication.sh exactly once."
fi
for required_g50_publication_guard in \
    'v0.2.2-rc.1' \
    '81016fe43ee617b5f251564b03904137a4447266' \
    'copylasso_prepare_v022_publication' \
    'must not publish, tag, replace, or deploy'; do
    if ! /usr/bin/grep -Fq -- "$required_g50_publication_guard" \
        "$g50_publication_audit_script"; then
        fail "The G50 publication audit is missing its guard: $required_g50_publication_guard"
    fi
done
for required_g50_guard in \
    'COPYLASSO_RELEASE_VERSION="0.2.2"' \
    '2.9.5' \
    '79bc9e872948e47877e76f194cb0c8e0412b0b90' \
    'GHSA-gmj2-gq3j-vqmj' \
    '--maximum-deltas'; do
    if ! /usr/bin/grep -Fq -- "$required_g50_guard" \
        "$g50_sparkle_hotfix_audit_script"; then
        fail "The G50 audit is missing its security hotfix guard: $required_g50_guard"
    fi
done
for required_g49_guard in \
    '0.2.1' \
    'copylasso_prepare_publication' \
    '813de17c739097217aad55a5a35c04ea3c73d99f' \
    'Phase 1 must not publish'; do
    if ! /usr/bin/grep -Fq -- "$required_g49_guard" \
        "$g49_publication_audit_script"; then
        fail "The G49 audit is missing its publication guard: $required_g49_guard"
    fi
done
for required_g48_guard in \
    '0.2.1' \
    'release_goal=G55' \
    'No processing indicator is included.' \
    'COPYLASSO_V02_FINAL_TAG="v0.2.1"'; do
    if ! /usr/bin/grep -Fq -- "$required_g48_guard" \
        "$g48_patch_qualification_audit_script"; then
        fail "The G48 audit is missing its patch-qualification guard: $required_g48_guard"
    fi
done
for required_g46_guard in \
    'Check for Updates(\.\.\.|…)' \
    '700 words maximum' \
    'rendered release notes' \
    '/usr/sbin/screencapture' \
    'arguments: ["-i", "-s", "-x", "-t", "png", "/dev/null"]' \
    'process.standardOutput = FileHandle.nullDevice' \
    'CGEvent(source: nil)?.location' \
    'CGEventSource.buttonState(' \
    'Thread.sleep(forTimeInterval: 0.001)' \
    'NSEvent\.add(Global|Local)MonitorForEvents' \
    'let endedOnDifferentDisplay =' \
    'expectedDisplayBounds' \
    'SystemInteractiveSelectionTracker' \
    'screenCaptureService.capture(selection)' \
    'interactiveCaptureService.prepareForCaptureTransition()' \
    'func authoritativeObservation() async' \
    '_ = try await SCShareableContent.current' \
    'resolveInteractiveCapture(using: service)' \
    'CGDisplay(Hide|Show)Cursor' \
    'captureCommand.performFromGlobalShortcut()' \
    'Data.*write\(to:'; do
    if ! /usr/bin/grep -Fq -- "$required_g46_guard" \
        "$g46_product_patch_audit_script"; then
        fail "The G46 audit is missing its product-patch guard: $required_g46_guard"
    fi
done
for required_g46_ci_guard in \
    'static let selectionStyleMask: NSWindow.StyleMask = .borderless' \
    'readonly expected_capture_api_files="$permission_client' \
    'ScreenCaptureKit APIs must remain confined to the production permission and in-memory capture services.' \
    'Debug display and selection-overlay APIs must remain confined to the AppKit fixture service.'; do
    if ! /usr/bin/grep -Fq -- "$required_g46_ci_guard" "$ci_script"; then
        fail "Canonical CI is missing its Debug-only AppKit fixture guard: $required_g46_ci_guard"
    fi
done
for required_release_state_guard in \
    'expected_release_commit="81016fe43ee617b5f251564b03904137a4447266"' \
    'expected_release_id="368002551"' \
    'expected_dmg_sha256="9ac432f956418dd37e04de014867a7fc20d1daeecc80f6fe1db1e9c53b19de2a"' \
    'expected_appcast_sha256="ad10db1486d4874701905ad3be2acc05f5025377328107a0aeabe552a9500cd6"' \
    'Release ID: `367570430`' \
    'Release ID: `361797888`' \
    'The 0.3.0 draft must identify the post-v0.2.2 multilingual source work.' \
    'The dated 0.2.2 section must retain the Sparkle security hotfix.'; do
    if ! /usr/bin/grep -Fq -- "$required_release_state_guard" \
        "$v02_release_state_audit_script"; then
        fail "The release-state audit must pin current v0.2.2 and historical v0.2.1/v0.2.0 boundaries."
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

multilingual_ocr_audit_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/audit-multilingual-ocr\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$multilingual_ocr_audit_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/audit-multilingual-ocr.sh exactly once."
fi
for multilingual_guard in \
    'Vision text APIs must remain confined to the OCR service and language catalog.' \
    'Multilingual OCR must not bundle a model or language pack.' \
    'Multilingual OCR must not add a network path.' \
    'public 0.2.2 download yet.'; do
    if ! /usr/bin/grep -Fq "$multilingual_guard" "$multilingual_ocr_audit_script"; then
        fail "The multilingual OCR audit is missing: $multilingual_guard"
    fi
done

capture_history_audit_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/audit-capture-history\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$capture_history_audit_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/audit-capture-history.sh exactly once."
fi
for history_guard in \
    'AES.GCM.seal' \
    'kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly' \
    'Save Capture History' \
    'Capture-history code must not add networking or logging.'; do
    if ! /usr/bin/grep -Fq "$history_guard" "$capture_history_audit_script"; then
        fail "The capture-history audit is missing: $history_guard"
    fi
done

interface_copy_audit_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/audit-interface-copy\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$interface_copy_audit_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/audit-interface-copy.sh exactly once."
fi
for interface_copy_guard in \
    'CopyLasso-authored interface copy must not contain an ellipsis.' \
    'The interface-copy audit must detect interpolated, escaped, and multiline Swift strings.' \
    'The interface-copy audit must not confuse Swift range operators with interface copy.' \
    'interpolated_copy_fixture=' \
    'escaped_copy_fixture=' \
    'multiline_copy_fixture=' \
    'range_operator_fixture=' \
    'Authenticated release notes and captured content remain unmodified.' \
    'Check for Updates'; do
    if ! /usr/bin/grep -Fq "$interface_copy_guard" "$interface_copy_audit_script"; then
        fail "The interface-copy audit is missing: $interface_copy_guard"
    fi
done

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

if [[ ! -x "$capture_history_audit_script" ]]; then
    fail "The capture-history security audit must be executable."
fi

if [[ ! -x "$interface_copy_audit_script" ]]; then
    fail "The interface-copy audit must be executable."
fi

if [[ ! -x "$v03_release_qualification_audit_script" ]]; then
    fail "The v0.3 release-qualification audit must be executable."
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
