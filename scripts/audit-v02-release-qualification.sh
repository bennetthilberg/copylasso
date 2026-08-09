#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly metadata="$repository_root/Configuration/ReleaseMetadata.xcconfig"
readonly contract="$repository_root/docs/v0.2-product-contract.md"
readonly qualification="$repository_root/docs/v0.2-release-qualification.md"
readonly release_notes="$repository_root/docs/release-notes/0.2.0.md"
readonly entitlements="$repository_root/CopyLasso/CopyLasso.entitlements"
readonly workflow="$repository_root/.github/workflows/release.yml"
readonly success_sound="$repository_root/CopyLasso/Resources/CopyLassoSuccess.wav"
readonly expected_success_sound_digest='e98be6b3eef44bffa5f5759ee83e99efd1ab3dfb820054a3d910be9b54cd2299'
readonly candidate_source_commit='43f1d0c676b08fb24b49fc628213fede90c4ed9d'
readonly expected_candidate_input_tree_digest='baf122b35c5132f31e1df07d1ff0402713f9cabe7ef7b48355289bc29682f39e'
readonly candidate_evidence_tree_pattern=$'\t(\\.github/workflows/prepare-publication\\.yml|docs/release-candidate-qualification\\.md|docs/release-checklist\\.md|docs/release-workflow\\.md|docs/secure-update-operations\\.md|docs/v0\\.2-publication-runbook\\.md|docs/v0\\.2-release-candidate\\.md|docs/v0\\.2-release-qualification\\.md|scripts/audit-v02-publication\\.sh|scripts/audit-v02-release-qualification\\.sh|scripts/ci\\.sh|scripts/create-v02-publication-draft\\.sh|scripts/download-v02-candidate\\.sh|scripts/generate-release-appcast\\.sh|scripts/lib/release-package-verification\\.sh|scripts/lib/v02-publication-transaction\\.sh|scripts/lib/v02-publication-verification\\.sh|scripts/lib/verify-sparkle-signatures\\.swift|scripts/prepare-update-feed\\.sh|scripts/test-ci-contract\\.sh|scripts/test-release-package\\.sh|scripts/test-v02-publication\\.sh|scripts/verify-release-package\\.sh|scripts/verify-v02-candidate-package\\.sh)$'
readonly approved_post_publication_patch_tree_pattern=$'\t(CHANGELOG\\.md|CopyLasso/App/CopyLassoApp\\.swift|CopyLasso/Models/SecureUpdateReleaseNotesPresentation\\.swift|CopyLasso/SharedUI/SecureUpdatePresentation\\.swift|CopyLassoTests/Update/SecureUpdateReleaseNotesPresentationTests\\.swift|CopyLassoUITests/CopyLassoUITests\\.swift|docs/architecture/overview\\.md|docs/manual-qa-and-performance\\.md|docs/secure-update-operations\\.md|docs/testing\\.md)$'
readonly approved_post_publication_runtime_tree_pattern=$'\t(CopyLasso/App/CopyLassoApp\\.swift|CopyLasso/Models/SecureUpdateReleaseNotesPresentation\\.swift|CopyLasso/SharedUI/SecureUpdatePresentation\\.swift)$'
readonly approved_post_v02_security_patch_tree_pattern=$'\t(\\.github/workflows/ci\\.yml|\\.github/workflows/release\\.yml|CopyLasso/Services/VisionOCRService\\.swift|CopyLassoTests/Services/VisionOCRServiceTests\\.swift|CopyLassoUITests/CopyLassoUITests\\.swift|scripts/audit-privacy-security\\.sh|scripts/audit-release-workflow\\.sh|scripts/audit-v02-release-qualification\\.sh|scripts/ci\\.sh|scripts/create-draft-release\\.sh|scripts/lib/project-security-verification\\.sh|scripts/lib/release-package-verification\\.sh|scripts/lib/release-workflow-verification\\.sh|scripts/test-privacy-security\\.sh|scripts/test-release-package\\.sh|scripts/test-release-workflow\\.sh)$'
readonly g46_product_patch_tree_pattern=$'\t(CHANGELOG\\.md|CopyLasso/App/CopyLassoApp\\.swift|CopyLasso/App/GlobalShortcutController\\.swift|CopyLasso/App/SystemGlobalShortcutEventSource\\.swift|CopyLasso/CaptureWorkflow/CaptureCommand\\.swift|CopyLasso/Models/SelectionGeometry\\.swift|CopyLasso/Services/AppKitRegionSelectionService\\.swift|CopyLasso/Services/InteractiveCaptureService\\.swift|CopyLasso/Services/RegionSelectionService\\.swift|CopyLasso/Services/ScreenCapturePermissionService\\.swift|CopyLasso/Services/SystemInteractiveCaptureService\\.swift|CopyLasso/Services/SystemScreenCapturePermissionClient\\.swift|CopyLasso/Services/SystemScreenCaptureService\\.swift|CopyLasso/SharedUI/AboutView\\.swift|CopyLasso/SharedUI/MenuBarMenuView\\.swift|CopyLasso/SharedUI/SettingsView\\.swift|CopyLassoTests/App/GlobalShortcutControllerTests\\.swift|CopyLassoTests/App/MenuBarShellTests\\.swift|CopyLassoTests/CaptureWorkflow/CaptureCommandTests\\.swift|CopyLassoTests/CaptureWorkflow/CapturePermissionFlowTests\\.swift|CopyLassoTests/CaptureWorkflow/CaptureWorkflowIntegrationTests\\.swift|CopyLassoTests/CaptureWorkflow/InteractiveCaptureWorkflowTests\\.swift|CopyLassoTests/Models/MultiDisplayBehaviorTests\\.swift|CopyLassoTests/Models/SelectionGeometryTests\\.swift|CopyLassoTests/Services/AppKitRegionSelectionServiceTests\\.swift|CopyLassoTests/Services/ScreenCapturePermissionServiceTests\\.swift|CopyLassoTests/Services/SystemInteractiveCaptureServiceTests\\.swift|CopyLassoTests/Services/SystemInteractiveSelectionTrackerTests\\.swift|CopyLassoTests/Services/SystemScreenCapturePermissionClientTests\\.swift|CopyLassoTests/Services/SystemScreenCaptureServiceTests\\.swift|CopyLassoTests/TestSupport/CaptureServiceDoubles\\.swift|CopyLassoTests/TestSupport/SettingsDoubles\\.swift|CopyLassoUITests/CopyLassoUITests\\.swift|PRIVACY\\.md|README\\.md|docs/architecture/ADR-002-screen-capture\\.md|docs/architecture/capture-workflow\\.md|docs/architecture/overview\\.md|docs/security-and-privacy-review\\.md|docs/testing\\.md|scripts/audit-g46-product-patch\\.sh|scripts/audit-privacy-security\\.sh|scripts/audit-v02-release-qualification\\.sh|scripts/ci\\.sh|scripts/test-ci-contract\\.sh)$'
readonly g44_release_state_tree_pattern=$'\t(CHANGELOG\\.md|CONTRIBUTING\\.md|PRIVACY\\.md|README\\.md|SECURITY\\.md|docs/architecture/overview\\.md|docs/release-checklist\\.md|docs/release-workflow\\.md|docs/secure-update-operations\\.md|docs/security-and-privacy-review\\.md|docs/testing\\.md|docs/v0\\.2-product-contract\\.md|docs/v0\\.2-release-state\\.md|scripts/audit-brand-release\\.sh|scripts/audit-code-recognition\\.sh|scripts/audit-secure-update-architecture\\.sh|scripts/audit-v02-contract\\.sh|scripts/audit-v02-publication\\.sh|scripts/audit-v02-release-qualification\\.sh|scripts/audit-v02-release-state\\.sh|scripts/ci\\.sh|scripts/test-ci-contract\\.sh|scripts/test-release-metadata\\.sh)$'
readonly g48_patch_tree_pattern=$'\t(\\.github/workflows/prepare-publication\\.yml|\\.github/workflows/release\\.yml|CHANGELOG\\.md|Configuration/ReleaseMetadata\\.xcconfig|PRIVACY\\.md|README\\.md|SECURITY\\.md|docs/architecture/build-configuration\\.md|docs/architecture/overview\\.md|docs/manual-qa-and-performance\\.md|docs/release-candidate-qualification\\.md|docs/release-checklist\\.md|docs/release-notes/0\\.2\\.1\\.md|docs/release-packaging\\.md|docs/release-workflow\\.md|docs/secure-update-operations\\.md|docs/security-and-privacy-review\\.md|docs/testing\\.md|docs/v0\\.2-product-contract\\.md|docs/v0\\.2\\.1-source-qualification\\.md|scripts/audit-brand-release\\.sh|scripts/audit-g48-patch-qualification\\.sh|scripts/audit-release-package\\.sh|scripts/audit-release-workflow\\.sh|scripts/audit-secure-update-architecture\\.sh|scripts/audit-v02-contract\\.sh|scripts/audit-v02-publication\\.sh|scripts/audit-v02-release-qualification\\.sh|scripts/audit-v02-release-state\\.sh|scripts/ci\\.sh|scripts/create-draft-release\\.sh|scripts/lib/release-package-verification\\.sh|scripts/lib/release-workflow-verification\\.sh|scripts/lib/v02-publication-verification\\.sh|scripts/test-ci-contract\\.sh|scripts/test-developer-id-release\\.sh|scripts/test-release-metadata\\.sh|scripts/test-release-package\\.sh|scripts/test-release-workflow\\.sh|scripts/test-v02-publication\\.sh|scripts/verify-release-package\\.sh|scripts/verify-v02-candidate-package\\.sh)$'
readonly g49_publication_tree_pattern=$'\t(\\.github/workflows/prepare-publication\\.yml|docs/release-checklist\\.md|docs/release-workflow\\.md|docs/secure-update-operations\\.md|docs/v0\\.2-publication-runbook\\.md|scripts/audit-g48-patch-qualification\\.sh|scripts/audit-g49-publication\\.sh|scripts/audit-v02-publication\\.sh|scripts/audit-v02-release-qualification\\.sh|scripts/ci\\.sh|scripts/download-v02-candidate\\.sh|scripts/generate-release-appcast\\.sh|scripts/lib/release-package-verification\\.sh|scripts/lib/v020-release-package-metadata\\.sh|scripts/lib/v021-release-package-metadata\\.sh|scripts/lib/v02-publication-transaction\\.sh|scripts/lib/v02-publication-verification\\.sh|scripts/prepare-update-feed\\.sh|scripts/test-ci-contract\\.sh|scripts/test-v02-publication\\.sh|scripts/verify-v02-candidate-package\\.sh)$'
readonly g50_security_hotfix_tree_pattern=$'\t(CopyLasso\\.xcodeproj/project\\.pbxproj|CopyLasso\\.xcodeproj/project\\.xcworkspace/xcshareddata/swiftpm/Package\\.resolved|CopyLasso/Models/AboutMetadata\\.swift|CopyLasso/Resources/Sparkle-2\\.9\\.(4|5)-LICENSE\\.txt|CopyLassoTests/App/MenuBarShellTests\\.swift|CopyLassoUITests/CopyLassoUITests\\.swift|THIRD_PARTY_NOTICES\\.md|docs/architecture/ADR-004-secure-updates\\.md|docs/release-notes/0\\.2\\.2\\.md|scripts/audit-g50-sparkle-hotfix\\.sh|scripts/build-private-update-fixture\\.sh|scripts/fixtures/v0\\.2\\.1-published-release-notes\\.md)$'
readonly g44_release_state_commit='295ea80bdc0d51579840ef9c2bfcad5278f87099'
readonly expected_candidate_baseline_tree_digest='1e4844388bc872b8ac4644a13b00223af1239f431d390130346daa8e914aafa0'
readonly expected_g48_baseline_tree_digest='95d7dfdf8a9545b8ce85568437ffc57d6951344c912945d86f391639a1e105be'
readonly expected_approved_post_publication_runtime_tree_digest='4269c2cc3177b938de424c53b42de94c63528f1a66ec79b97fea0de76ec095c0'
readonly expected_g44_release_state_files_digest='8fefcac6d46e3ec19d11786ab3d5836c3c34fc476a1cad31efbfacc95d977039'
readonly expected_approved_post_candidate_patch_digest='0ed1f744642b4bfe0a6c953c306f31688c117497a8a4e989d1c6a18d907c1ea3'

fail() {
    echo "$1" >&2
    exit 1
}

require_file() {
    [[ -f "$repository_root/$1" ]] || fail "Required v0.2 qualification file is missing: $1"
}

require_text() {
    local relative_path="$1"
    local required_text="$2"

    /usr/bin/grep -Fq -- "$required_text" "$repository_root/$relative_path" || \
        fail "$relative_path is missing required v0.2 qualification text: $required_text"
}

approved_post_candidate_path() {
    local relative_path="$1"
    local tree_line=$'\t'"$relative_path"

    printf '%s\n' "$tree_line" | \
        /usr/bin/grep -Eq "$candidate_evidence_tree_pattern" || \
        printf '%s\n' "$tree_line" | \
            /usr/bin/grep -Eq "$approved_post_publication_patch_tree_pattern" || \
        printf '%s\n' "$tree_line" | \
            /usr/bin/grep -Eq "$approved_post_v02_security_patch_tree_pattern" || \
        printf '%s\n' "$tree_line" | \
            /usr/bin/grep -Eq "$g46_product_patch_tree_pattern" || \
        printf '%s\n' "$tree_line" | \
            /usr/bin/grep -Eq "$g44_release_state_tree_pattern" || \
        printf '%s\n' "$tree_line" | \
            /usr/bin/grep -Eq "$g48_patch_tree_pattern" || \
        printf '%s\n' "$tree_line" | \
            /usr/bin/grep -Eq "$g49_publication_tree_pattern" || \
        printf '%s\n' "$tree_line" | \
            /usr/bin/grep -Eq "$g50_security_hotfix_tree_pattern"
}

for required_file in \
    Configuration/ReleaseMetadata.xcconfig \
    CopyLasso/CopyLasso.entitlements \
    CopyLasso/Resources/CopyLassoSuccess.wav \
    THIRD_PARTY_NOTICES.md \
    README.md \
    CHANGELOG.md \
    PRIVACY.md \
    SECURITY.md \
    docs/v0.2-product-contract.md \
    docs/v0.2-release-qualification.md \
    docs/v0.2-release-candidate.md \
    docs/release-notes/0.2.0.md \
    docs/release-notes/0.2.1.md \
    docs/release-notes/0.2.2.md \
    docs/release-checklist.md; do
    require_file "$required_file"
done

/usr/bin/grep -Eq \
    '^COPYLASSO_RELEASE_VERSION[[:space:]]*=[[:space:]]*0\.2\.2[[:space:]]*$' \
    "$metadata" || fail "G50 must freeze candidate source at version 0.2.2."
/usr/bin/grep -Eq \
    '^COPYLASSO_RELEASE_BUILD[[:space:]]*=[[:space:]]*5[[:space:]]*$' \
    "$metadata" || fail "G50 must freeze candidate source at build 5."

require_text CHANGELOG.md '## 0.2.0 - 2026-07-29'
require_text CHANGELOG.md '## 0.2.1 - 2026-08-09'
require_text README.md 'CopyLasso 0.2.1 is the latest public release.'
require_text README.md 'CopyLasso 0.2.0 was the first updater-enabled public release.'
require_text README.md 'those older application binaries contain'
require_text PRIVACY.md 'Update requests send no screen pixels'
require_text SECURITY.md 'CopyLasso 0.2.x is the currently supported public release line.'
require_text docs/v0.2-product-contract.md \
    '**Implementation status:** Released as 0.2.1 (4) on August 9, 2026.'
require_text docs/v0.2-product-contract.md \
    'G39 concluded no-go, so CopyLasso 0.2.1 contains no LaTeX recognition'
require_text docs/v0.2-release-qualification.md '# CopyLasso v0.2 Source Qualification'
require_text docs/v0.2-release-qualification.md 'Public release remains `0.1.1`.'
require_text docs/v0.2-release-qualification.md 'G42 is a later release gate'
require_text docs/v0.2-release-qualification.md \
    'The exact G42 candidate qualification is recorded in'
require_text docs/v0.2-release-qualification.md \
    '[`v0.2-release-candidate.md`](v0.2-release-candidate.md).'
require_text docs/v0.2-release-candidate.md \
    '# CopyLasso v0.2 Release Candidate Qualification'
require_text docs/v0.2-release-candidate.md '**Candidate:** `v0.2.0-rc.1`'
require_text docs/v0.2-release-candidate.md \
    '**Source commit:** `43f1d0c676b08fb24b49fc628213fede90c4ed9d`'
require_text docs/v0.2-release-candidate.md \
    '**Decision:** Approved by the maintainer for G43 publication'
require_text docs/v0.2-release-candidate.md \
    'Public release remains `0.1.1`; no v0.2 feed or public artifact was published.'
require_text docs/v0.2-release-candidate.md \
    '`0b40f9524389b684124189ce743109429af97baf124e28bf1d12313eba26d807`.'
require_text docs/v0.2-release-candidate.md \
    '| `CopyLasso-0.2.0.dmg` | 3,665,931 | `697cb008cf294b32500e2ad84e5777a51fe8b88916856c5a8e9f1ec4eb74ba19` |'
require_text docs/v0.2-release-candidate.md \
    '| `CopyLasso-0.2.0.dmg.sha256` | 86 | `6dfd44d92f6af1c14d765bc6c827ed3e9a0edd5ffe289c3e74ac6e1dd0c834b0` |'
require_text docs/v0.2-release-candidate.md \
    '| `CopyLasso-0.2.0.dSYM.zip` | 6,094,121 | `b644da8776f857c1f42a95f903b315b7dde418000d173b48829c5ee346bc4754` |'
require_text docs/v0.2-release-candidate.md \
    '| `CopyLasso-0.2.0-verification.zip` | 3,708,469 | `e4d424bdd9675b00ffa647bccdc3f3bc47b43b4d041535c0898f79cf79e3a073` |'
require_text docs/v0.2-release-candidate.md \
    '`a80260d6cd501ffee65ec41cbe1a232b9de662a9b41b4d78a0cd9b361bfe9fe6`.'
require_text docs/v0.2-release-candidate.md '## Release-Delta Smoke'
require_text docs/v0.2-release-candidate.md \
    'The scoped Screen Recording permission was reset only for CopyLasso.'
require_text docs/v0.2-release-candidate.md \
    'automatic updates were enabled in'
require_text docs/v0.2-release-candidate.md \
    'Capture remained usable and copied'
require_text docs/v0.2-release-candidate.md \
    'The controlled QR precedence smoke copied the inert payload without opening a'
require_text docs/v0.2-release-candidate.md \
    'no payload action and no LaTeX command,'
require_text docs/release-notes/0.2.0.md '# CopyLasso 0.2.0'
require_text docs/release-notes/0.2.0.md 'QR, Code 128, Data Matrix, PDF417, and Aztec'
require_text docs/release-notes/0.2.0.md 'CopyLasso 0.1.x does not contain an updater'
require_text docs/release-notes/0.2.0.md 'LaTeX recognition is not included'
require_text docs/release-notes/0.2.1.md '# CopyLasso 0.2.1'
require_text docs/release-notes/0.2.1.md 'No processing indicator is included.'
require_text docs/release-notes/0.2.2.md '# CopyLasso 0.2.2'
require_text docs/release-notes/0.2.2.md 'GHSA-gmj2-gq3j-vqmj'
require_text docs/release-checklist.md '## G41 - v0.2 Feature Qualification'
require_text docs/release-checklist.md '## G42 - v0.2 Release Candidate'
require_text docs/release-checklist.md \
    '- [x] After G41 merges, dispatch the protected workflow from the exact protected-main commit with a new positive `candidate_number`.'
require_text docs/release-checklist.md \
    '- [x] Create and qualify one immutable private `v0.2.0-rc.N` draft, four restricted assets, authenticated update metadata, and browser-quarantined installation without rebuilding.'
require_text docs/release-checklist.md \
    '- [x] Exercise the private staged updater path, classify blockers and accepted gaps, and obtain explicit maintainer approval or rejection. Do not publish.'

require_text THIRD_PARTY_NOTICES.md '## KeyboardShortcuts 3.0.1'
require_text THIRD_PARTY_NOTICES.md '## Sparkle 2.9.5'
require_text CopyLasso.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved \
    '"version" : "3.0.1"'
require_text CopyLasso.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved \
    '"version" : "2.9.5"'
require_text docs/brand-assets.md \
    'The maintainer selected the seventeenth of eighteen project-authored candidates'
require_text CopyLasso/Settings/AppSettingsStore.swift \
    'static let currentSuccessSoundPreferenceVersion = 1'
require_text CopyLasso/Services/VisionBarcodeService.swift \
    'symbologies: [.qr, .code128, .dataMatrix, .pdf417, .aztec]'
require_text CopyLasso/CaptureWorkflow/CaptureCommand.swift \
    'async let textAttempt = recognizeText(in: image)'
require_text CopyLasso/CaptureWorkflow/CaptureCommand.swift \
    'async let codeAttempt = recognizeCodes(in: image)'
require_text CopyLasso/CaptureWorkflow/CaptureCommand.swift \
    'successSoundPlayer.play()'
require_text CopyLasso/Services/SparkleUpdateService.swift 'import Sparkle'
require_text Configuration/CopyLasso-Info.plist \
    '<string>https://updates.copylasso.com/appcast.xml</string>'

git -C "$repository_root" cat-file -e "$candidate_source_commit^{tree}" 2>/dev/null || \
    fail "The qualified candidate commit is unavailable. Fetch full history before qualification."

while IFS= read -r approved_path; do
    approved_post_candidate_path "$approved_path" || \
        fail "An unapproved path differs from the qualified v0.2 candidate: $approved_path"
done < <(git -C "$repository_root" diff --name-only \
    "$candidate_source_commit")

approved_post_candidate_patch_digest="$(
    while IFS= read -r approved_path; do
        if [[ ! -e "$repository_root/$approved_path" && \
            ! -L "$repository_root/$approved_path" ]]; then
            printf 'deleted\t%s\n' "$approved_path"
            continue
        fi
        approved_mode="$(
            git -C "$repository_root" ls-files -s -- "$approved_path" | \
                /usr/bin/awk 'NR == 1 {print $1}'
        )"
        if [[ "$approved_path" == \
            "scripts/audit-v02-release-qualification.sh" || \
            "$approved_path" == "scripts/test-ci-contract.sh" ]]; then
            approved_digest="$(
                /usr/bin/sed -E \
                    -e 's/(expected_approved_post_candidate_patch_digest[^0-9a-f]*)[0-9a-f]{64}/\1<self-normalized>/g' \
                    -e 's/(expected_g48_baseline_tree_digest[^0-9a-f]*)[0-9a-f]{64}/\1<self-normalized>/g' \
                    -e 's/(expected_g44_release_state_files_digest[^0-9a-f]*)[0-9a-f]{64}/\1<self-normalized>/g' \
                    "$repository_root/$approved_path" | \
                    /usr/bin/shasum -a 256 | \
                    /usr/bin/awk '{print $1}'
            )"
        else
            approved_digest="$(
                git -C "$repository_root" hash-object -- "$approved_path"
            )"
        fi
        printf '%s\t%s\t%s\n' \
            "$approved_mode" "$approved_digest" "$approved_path"
    done < <(
        git -C "$repository_root" diff --name-only "$candidate_source_commit" | \
            LC_ALL=C /usr/bin/sort
    ) | \
        /usr/bin/shasum -a 256 | \
        /usr/bin/awk '{print $1}'
)"
[[ "$approved_post_candidate_patch_digest" == \
    "$expected_approved_post_candidate_patch_digest" ]] || \
    fail "The approved post-candidate patch differs from its reviewed digest: $approved_post_candidate_patch_digest"

qualified_candidate_input_tree_digest="$(
    git -C "$repository_root" ls-tree -r --full-tree "$candidate_source_commit" |
        /usr/bin/grep -Ev "$candidate_evidence_tree_pattern" |
        /usr/bin/shasum -a 256 |
        /usr/bin/awk '{print $1}'
)"
[[ "$qualified_candidate_input_tree_digest" == "$expected_candidate_input_tree_digest" ]] || \
    fail "The qualified candidate input tree no longer matches its reviewed digest."

candidate_baseline_tree_digest="$(
    git -C "$repository_root" ls-tree -r --full-tree "$candidate_source_commit" |
        /usr/bin/grep -Ev "$candidate_evidence_tree_pattern" |
        /usr/bin/grep -Ev "$approved_post_publication_patch_tree_pattern" |
        /usr/bin/grep -Ev "$approved_post_v02_security_patch_tree_pattern" |
        /usr/bin/grep -Ev "$g46_product_patch_tree_pattern" |
        /usr/bin/grep -Ev "$g44_release_state_tree_pattern" |
        /usr/bin/shasum -a 256 |
        /usr/bin/awk '{print $1}'
)"
[[ "$candidate_baseline_tree_digest" == "$expected_candidate_baseline_tree_digest" ]] || \
    fail "The frozen candidate baseline no longer matches its reviewed digest."

current_baseline_tree_digest="$(
    git -C "$repository_root" ls-tree -r --full-tree HEAD |
        /usr/bin/grep -Ev "$candidate_evidence_tree_pattern" |
        /usr/bin/grep -Ev "$approved_post_publication_patch_tree_pattern" |
        /usr/bin/grep -Ev "$approved_post_v02_security_patch_tree_pattern" |
        /usr/bin/grep -Ev "$g46_product_patch_tree_pattern" |
        /usr/bin/grep -Ev "$g44_release_state_tree_pattern" |
        /usr/bin/grep -Ev "$g48_patch_tree_pattern" |
        /usr/bin/grep -Ev "$g49_publication_tree_pattern" |
        /usr/bin/grep -Ev "$g50_security_hotfix_tree_pattern" |
        /usr/bin/shasum -a 256 |
        /usr/bin/awk '{print $1}'
)"
[[ "$current_baseline_tree_digest" == "$expected_g48_baseline_tree_digest" ]] || \
    fail "A tracked candidate input outside the approved post-publication patch differs from source commit $candidate_source_commit: $current_baseline_tree_digest"

approved_post_publication_runtime_tree_digest="$(
    git -C "$repository_root" ls-tree -r --full-tree HEAD |
        /usr/bin/grep -E "$approved_post_publication_runtime_tree_pattern" |
        /usr/bin/shasum -a 256 |
        /usr/bin/awk '{print $1}'
)"
[[ "$approved_post_publication_runtime_tree_digest" == \
    "$expected_approved_post_publication_runtime_tree_digest" ]] || \
    fail "The approved G43A runtime patch differs from its reviewed tree digest."

readonly g44_release_state_files=(
    CHANGELOG.md
    CONTRIBUTING.md
    PRIVACY.md
    README.md
    SECURITY.md
    docs/architecture/overview.md
    docs/release-checklist.md
    docs/secure-update-operations.md
    docs/security-and-privacy-review.md
    docs/testing.md
    docs/v0.2-product-contract.md
    docs/v0.2-release-state.md
    scripts/audit-brand-release.sh
    scripts/audit-code-recognition.sh
    scripts/audit-secure-update-architecture.sh
    scripts/audit-v02-contract.sh
    scripts/audit-v02-publication.sh
    scripts/audit-v02-release-state.sh
    scripts/test-release-metadata.sh
)
g44_release_state_files_digest="$(
    for relative_path in "${g44_release_state_files[@]}"; do
        git -C "$repository_root" cat-file -e \
            "$g44_release_state_commit:$relative_path" 2>/dev/null || \
            fail "The approved G44 release-state file is missing: $relative_path"
        file_digest="$(git -C "$repository_root" show \
            "$g44_release_state_commit:$relative_path" | /usr/bin/shasum -a 256 | \
            /usr/bin/awk '{print $1}')"
        /usr/bin/printf '%s\t%s\n' "$relative_path" "$file_digest"
    done | /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}'
)"
[[ "$g44_release_state_files_digest" == "$expected_g44_release_state_files_digest" ]] || \
    fail "The approved G44 release-state files differ from their reviewed digest."
require_text CopyLassoTests/Settings/UserDefaultsSettingsStoreTests.swift \
    'testVersion011PreferencesRemainCompatibleWithVersion020Migration'
require_text CopyLassoTests/Update/UpdateControllerTests.swift \
    'testVersion011UpgradeUsesUpdaterDefaultWhenNoPreferenceExists'
require_text CopyLassoTests/Update/UpdateControllerTests.swift \
    'testVersion011UpgradePreservesExplicitUpdaterOptOut'

actual_success_sound_digest="$(/usr/bin/shasum -a 256 "$success_sound" | \
    /usr/bin/awk '{print $1}')"
[[ "$actual_success_sound_digest" == "$expected_success_sound_digest" ]] || \
    fail "G41 must ship the reviewed candidate-17 success sound bytes."

entitlements_json="$(/usr/bin/plutil -convert json -o - "$entitlements")" || \
    fail "The v0.2 entitlements are invalid."
if ! /usr/bin/jq -e '
    (keys | sort) == [
        "com.apple.security.app-sandbox",
        "com.apple.security.network.client",
        "com.apple.security.temporary-exception.mach-lookup.global-name"
    ] and
    .["com.apple.security.app-sandbox"] == true and
    .["com.apple.security.network.client"] == true and
    .["com.apple.security.temporary-exception.mach-lookup.global-name"] == [
        "$(PRODUCT_BUNDLE_IDENTIFIER)-spks",
        "$(PRODUCT_BUNDLE_IDENTIFIER)-spki"
    ]
    ' <<< "$entitlements_json" >/dev/null; then
    fail "G41 must retain exactly the reviewed updater sandbox capabilities."
fi

sparkle_imports="$({
    /usr/bin/grep -R -l \
        '^[[:space:]]*import[[:space:]]\+Sparkle[[:space:]]*$' \
        "$repository_root/CopyLasso" || true
})"
if [[ "$sparkle_imports" != "$repository_root/CopyLasso/Services/SparkleUpdateService.swift" ]]; then
    fail "Sparkle must remain confined to the reviewed updater adapter."
fi

if /usr/bin/grep -R -nE \
    'URLSession|NSURLConnection|NWConnection|^[[:space:]]*import[[:space:]]+Network[[:space:]]*$' \
    "$repository_root/CopyLasso"; then
    fail "Application-owned networking outside the reviewed updater boundary is prohibited."
fi

if /usr/bin/grep -R -nE \
    'LaTeX|CoreML|MLModel|\.mlmodel(c)?([[:space:]]|$)' \
    "$repository_root/CopyLasso" \
    "$repository_root/CopyLasso.xcodeproj/project.pbxproj"; then
    fail "The accepted G39 no-go prohibits a production LaTeX runtime or model."
fi

for prohibited_pattern in \
    'screenshot.*(write|persist|upload)' \
    'recognized.*(log|persist|upload)' \
    'clipboard.*(log|persist|upload)' \
    'barcode.*(open|launch|execute)' \
    'TODO' \
    'example\.com'; do
    if /usr/bin/grep -R -nEi "$prohibited_pattern" \
        "$contract" "$qualification" "$release_notes"; then
        fail "G41 public qualification files contain prohibited content: $prohibited_pattern"
    fi
done

require_text .github/workflows/release.yml \
    'Omit candidate_number only for a private G50 rehearsal.'
require_text .github/workflows/release.yml 'release_goal=G50'
require_text .github/workflows/release.yml 'release_subdirectory=g50'
require_text .github/workflows/release.yml \
    'release_tag="v${COPYLASSO_G28_VERSION}-g50.${GITHUB_RUN_ID}${GITHUB_RUN_ATTEMPT}"'
if /usr/bin/grep -Eq \
    '(^|[[:space:]])(publish|make_latest|draft:[[:space:]]*false)([[:space:]]|$)' \
    "$workflow"; then
    fail "G50 must not add a publication path to the protected candidate workflow."
fi

echo "CopyLasso v0.2 release qualification audit passed."
