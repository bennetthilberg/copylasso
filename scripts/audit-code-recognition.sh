#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly adapter="$repository_root/CopyLasso/Services/VisionBarcodeService.swift"
readonly observation="$repository_root/CopyLasso/Models/RecognizedCodeObservation.swift"
readonly assembler="$repository_root/CopyLasso/Models/CodePayloadAssembler.swift"
readonly workflow="$repository_root/CopyLasso/CaptureWorkflow/CaptureCommand.swift"
readonly menu="$repository_root/CopyLasso/SharedUI/MenuBarMenuView.swift"
readonly settings="$repository_root/CopyLasso/SharedUI/SettingsView.swift"
readonly shortcut_store="$repository_root/CopyLasso/Settings/GlobalShortcutStore.swift"
readonly feedback="$repository_root/CopyLasso/Models/FeedbackPresentationContent.swift"
readonly generator="$repository_root/scripts/generate-code-fixtures.swift"
readonly fixtures="$repository_root/CopyLassoTests/Fixtures"

fail() {
    echo "$1" >&2
    exit 1
}

for required_file in \
    "$adapter" \
    "$observation" \
    "$assembler" \
    "$workflow" \
    "$generator" \
    "$repository_root/CopyLasso/Models/CaptureMode.swift" \
    "$repository_root/CopyLassoTests/Models/CodePayloadAssemblerTests.swift" \
    "$repository_root/CopyLassoTests/Services/VisionBarcodeServiceTests.swift"; do
    [[ -f "$required_file" ]] || fail "Required code-recognition file is missing: $required_file"
done

vision_barcode_files="$({
    /usr/bin/grep -R -lE \
        'VNDetectBarcodesRequest|VNBarcodeSymbology|VNBarcodeObservation' \
        "$repository_root/CopyLasso" || true
})"
if [[ "$vision_barcode_files" != "$adapter" ]]; then
    fail "Vision barcode APIs must remain confined to VisionBarcodeService.swift."
fi

for required_adapter_contract in \
    'VNDetectBarcodesRequestRevision3' \
    'symbologies: [.qr, .code128, .dataMatrix, .pdf417, .aztec]' \
    'Task.detached(priority: .userInitiated)' \
    'observation.payloadStringValue' \
    'observation.boundingBox'; do
    /usr/bin/grep -Fq "$required_adapter_contract" "$adapter" || \
        fail "The Vision barcode adapter is missing: $required_adapter_contract"
done

for required_assembler_contract in \
    'observation.symbology.isSupported' \
    '!payload.isEmpty' \
    'observation.boundingBox.width > 0' \
    'observation.boundingBox.height > 0' \
    'payload.contains("\n") || payload.contains("\r")' \
    'orderedPayloads.joined(separator: "\n")'; do
    /usr/bin/grep -Fq "$required_assembler_contract" "$assembler" || \
        fail "The pure code-payload assembler is missing: $required_assembler_contract"
done

if /usr/bin/grep -nE \
    '\.trimmingCharacters|URL\(|URLSession|NSWorkspace|openURL|canOpenURL|UIApplication|AVCapture|NSOpenPanel|fileImporter|FileManager|UserDefaults|Data\.write|write\(to:|print\(|debugPrint\(|NSLog\(|os_log|Logger\(' \
    "$adapter" "$observation" "$assembler"; then
    fail "Code payload handling must not interpret, act on, persist, transmit, or log content."
fi

for required_workflow_contract in \
    'perform(mode: CaptureMode)' \
    'retryLastRequest()' \
    'barcodeService.recognizeCodes(in: image)' \
    'codePayloadAssembler.assemble(observations)' \
    'mode == .text ? .success(preview: preview) : .codeSuccess(preview: preview)'; do
    /usr/bin/grep -Fq "$required_workflow_contract" "$workflow" || \
        fail "The shared capture workflow is missing: $required_workflow_contract"
done

for required_ui_contract in \
    "$menu:Capture Code" \
    "$menu:.globalKeyboardShortcut(.captureCode)" \
    "$settings:Shortcuts" \
    "$settings:Capture Code" \
    "$settings:codeShortcutRecorderLabel" \
    "$shortcut_store:static let captureCode = Self(\"captureCode\")" \
    "$feedback:Copied Code" \
    "$feedback:No Code Found" \
    "$feedback:Capture Codes Separately" \
    "$feedback:Code Capture Failed"; do
    contract_file="${required_ui_contract%%:*}"
    required_text="${required_ui_contract#*:}"
    /usr/bin/grep -Fq "$required_text" "$contract_file" || \
        fail "The Capture Code UI contract is missing: $required_text"
done

readonly expected_fixture_records=(
    "4b359a470614f8c335f5ff32cfcf743398d0936d974ab04d52f4e654148db355 code-aztec.png"
    "877151946b27acbfaf0e5cb4c9a6b62363622de95d6c614efc9f7953d8225b92 code-code128.png"
    "1f0529db00cb70c7e51340991eae5250cefad7a270ca521c77c140424752a527 code-data-matrix.png"
    "3568ec36f5a46231e1682bca309da8828ca336daef7729e2ad191bce59da1497 code-pdf417.png"
    "1d978e8b7dac9820a1393e529de829e80c93cebecedb20bab3f4ad703c54504d code-qr.png"
)

temporary_directory="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/copylasso-code-fixtures.XXXXXX")"
trap 'rm -rf "$temporary_directory"' EXIT
CLANG_MODULE_CACHE_PATH="$temporary_directory/clang-module-cache" \
    SWIFT_MODULE_CACHE_PATH="$temporary_directory/swift-module-cache" \
    xcrun swift "$generator" "$temporary_directory"

for fixture_record in "${expected_fixture_records[@]}"; do
    expected_digest="${fixture_record%% *}"
    fixture_name="${fixture_record#* }"
    fixture="$fixtures/$fixture_name"
    generated_fixture="$temporary_directory/$fixture_name"
    [[ -f "$fixture" ]] || fail "Required code fixture is missing: $fixture_name"
    actual_digest="$(/usr/bin/shasum -a 256 "$fixture" | /usr/bin/awk '{print $1}')"
    if [[ "$actual_digest" != "$expected_digest" ]]; then
        fail "The reviewed code fixture digest changed: $fixture_name"
    fi
    /usr/bin/cmp -s "$fixture" "$generated_fixture" || \
        fail "The code fixture is not byte-for-byte reproducible: $fixture_name"
done

entitlements_json="$(/usr/bin/plutil -convert json -o - \
    "$repository_root/CopyLasso/CopyLasso.entitlements")" || \
    fail "The CopyLasso entitlements are invalid."
if ! /usr/bin/jq -e '
    (keys | sort) == [
        "com.apple.security.app-sandbox",
        "com.apple.security.network.client",
        "com.apple.security.temporary-exception.mach-lookup.global-name"
    ]
    ' <<< "$entitlements_json" >/dev/null; then
    fail "Capture Code must not add an entitlement."
fi

for documentation_contract in \
    "$repository_root/README.md:Capture Code is present in current source but is not part of the public CopyLasso 0.1.1 download." \
    "$repository_root/CHANGELOG.md:Capture Code" \
    "$repository_root/PRIVACY.md:Code payloads are recognized locally" \
    "$repository_root/SECURITY.md:CopyLasso never opens or acts on a recognized code payload." \
    "$repository_root/docs/architecture/capture-workflow.md:## Capture Code" \
    "$repository_root/docs/security-and-privacy-review.md:## G38 Code Recognition Review" \
    "$repository_root/docs/testing.md:## G38 On-Screen Code Recognition" \
    "$repository_root/docs/v0.2-product-contract.md:Capture Code are implemented in source but are not part of the public CopyLasso 0.1.1 download."; do
    documentation_file="${documentation_contract%%:*}"
    required_text="${documentation_contract#*:}"
    /usr/bin/grep -Fq "$required_text" "$documentation_file" || \
        fail "Code-recognition documentation is missing: $required_text"
done

if /usr/bin/grep -R -nE \
    'Capture Code (is|are) (available now|shipping|included in 0\.1\.1)' \
    "$repository_root/README.md" \
    "$repository_root/CHANGELOG.md" \
    "$repository_root/PRIVACY.md" \
    "$repository_root/SECURITY.md" \
    "$repository_root/docs"; then
    fail "Public documentation must not claim that CopyLasso 0.1.1 includes Capture Code."
fi

echo "CopyLasso on-screen code-recognition audit passed."
