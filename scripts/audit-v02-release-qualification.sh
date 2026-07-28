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
    docs/release-checklist.md; do
    require_file "$required_file"
done

/usr/bin/grep -Eq \
    '^COPYLASSO_RELEASE_VERSION[[:space:]]*=[[:space:]]*0\.2\.0[[:space:]]*$' \
    "$metadata" || fail "G41 must freeze CopyLasso at version 0.2.0."
/usr/bin/grep -Eq \
    '^COPYLASSO_RELEASE_BUILD[[:space:]]*=[[:space:]]*3[[:space:]]*$' \
    "$metadata" || fail "G41 must freeze CopyLasso at build 3."

require_text CHANGELOG.md '## 0.2.0 - Unreleased'
require_text README.md 'CopyLasso 0.1.1 is the latest public release.'
require_text README.md 'Current source is release-qualified as CopyLasso 0.2.0 (3).'
require_text README.md 'The first updater-enabled release must be installed manually'
require_text PRIVACY.md 'Update requests send no screen pixels'
require_text SECURITY.md 'No public v0.2 update feed or updater-enabled release exists yet.'
require_text docs/v0.2-product-contract.md \
    '**Implementation status:** Release-qualified in source as 0.2.0 (3); not publicly released.'
require_text docs/v0.2-product-contract.md \
    'G39 concluded no-go, so CopyLasso 0.2.0 contains no LaTeX recognition'
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
require_text docs/release-checklist.md '## G41 - v0.2 Feature Qualification'
require_text docs/release-checklist.md '## G42 - v0.2 Release Candidate'
require_text docs/release-checklist.md \
    '- [x] After G41 merges, dispatch the protected workflow from the exact protected-main commit with a new positive `candidate_number`.'
require_text docs/release-checklist.md \
    '- [x] Create and qualify one immutable private `v0.2.0-rc.N` draft, four restricted assets, authenticated update metadata, and browser-quarantined installation without rebuilding.'
require_text docs/release-checklist.md \
    '- [x] Exercise the private staged updater path, classify blockers and accepted gaps, and obtain explicit maintainer approval or rejection. Do not publish.'

require_text THIRD_PARTY_NOTICES.md '## KeyboardShortcuts 3.0.1'
require_text THIRD_PARTY_NOTICES.md '## Sparkle 2.9.4'
require_text CopyLasso.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved \
    '"version" : "3.0.1"'
require_text CopyLasso.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved \
    '"version" : "2.9.4"'
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

git -C "$repository_root" cat-file -e "$candidate_source_commit^{commit}" || \
    fail "The approved v0.2 candidate source commit is unavailable."
while IFS= read -r changed_path; do
    case "$changed_path" in
        docs/release-candidate-qualification.md | \
            docs/release-checklist.md | \
            docs/release-workflow.md | \
            docs/v0.2-release-candidate.md | \
            docs/v0.2-release-qualification.md | \
            scripts/audit-v02-release-qualification.sh)
            ;;
        *)
            fail "A tracked path outside the G42 evidence boundary changed after the candidate: $changed_path"
            ;;
    esac
done < <(git -C "$repository_root" diff --name-only "$candidate_source_commit" --)
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
    'leave blank only for a private G42 rehearsal'
require_text .github/workflows/release.yml 'release_goal=G42'
require_text .github/workflows/release.yml 'release_subdirectory=g42'
require_text .github/workflows/release.yml \
    'release_tag="v${COPYLASSO_G28_VERSION}-g42.${GITHUB_RUN_ID}${GITHUB_RUN_ATTEMPT}"'
if /usr/bin/grep -Eq \
    '(^|[[:space:]])(publish|make_latest|draft:[[:space:]]*false)([[:space:]]|$)' \
    "$workflow"; then
    fail "G41 must not add a publication path to the protected candidate workflow."
fi

echo "CopyLasso v0.2 release qualification audit passed."
