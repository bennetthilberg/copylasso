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

fail() {
    echo "$1" >&2
    exit 1
}

require_file() {
    [[ -f "$repository_root/$1" ]] || fail "Required G41 file is missing: $1"
}

require_text() {
    local relative_path="$1"
    local required_text="$2"

    /usr/bin/grep -Fq "$required_text" "$repository_root/$relative_path" || \
        fail "$relative_path is missing required G41 text: $required_text"
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
require_text docs/release-notes/0.2.0.md '# CopyLasso 0.2.0'
require_text docs/release-notes/0.2.0.md 'QR, Code 128, Data Matrix, PDF417, and Aztec'
require_text docs/release-notes/0.2.0.md 'CopyLasso 0.1.x does not contain an updater'
require_text docs/release-notes/0.2.0.md 'LaTeX recognition is not included'
require_text docs/release-checklist.md '## G41 - v0.2 Feature Qualification'
require_text docs/release-checklist.md '## G42 - v0.2 Release Candidate'

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
