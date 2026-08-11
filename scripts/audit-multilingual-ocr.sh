#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

fail() {
    echo "$1" >&2
    exit 1
}

readonly catalog='CopyLasso/Services/OCRLanguageCatalog.swift'
readonly service='CopyLasso/Services/VisionOCRService.swift'
readonly preferences='CopyLasso/Models/OCRRecognitionPreferences.swift'
readonly editor_model='CopyLasso/Models/OCRLanguageSelectionDraft.swift'
readonly settings_store='CopyLasso/Settings/AppSettingsStore.swift'
readonly settings_controller='CopyLasso/Settings/SettingsController.swift'
readonly settings_view='CopyLasso/SharedUI/SettingsView.swift'
readonly editor_view='CopyLasso/SharedUI/OCRLanguageEditorView.swift'
readonly capture_command='CopyLasso/CaptureWorkflow/CaptureCommand.swift'
readonly app='CopyLasso/App/CopyLassoApp.swift'
readonly contract='docs/v0.3-product-contract.md'

for required_file in \
    "$catalog" \
    "$service" \
    "$preferences" \
    "$editor_model" \
    "$settings_store" \
    "$settings_controller" \
    "$settings_view" \
    "$editor_view" \
    "$contract"; do
    [[ -f "$required_file" ]] || fail "Missing multilingual OCR source: $required_file"
done

readonly expected_vision_files="$catalog
$service"
vision_files="$({ /usr/bin/grep -R -l 'VNRecognizeTextRequest' CopyLasso || true; } | LC_ALL=C /usr/bin/sort)"
[[ "$vision_files" == "$expected_vision_files" ]] || \
    fail "Vision text APIs must remain confined to the OCR service and language catalog."

for required_catalog_contract in \
    'VNRecognizeTextRequestRevision3' \
    'request.recognitionLevel = .accurate' \
    'supportedRecognitionLanguages()'; do
    /usr/bin/grep -Fq "$required_catalog_contract" "$catalog" || \
        fail "The runtime language catalog is missing: $required_catalog_contract"
done

for required_service_contract in \
    'request.recognitionLanguages = configuration.recognitionLanguages' \
    'request.automaticallyDetectsLanguage = configuration.automaticallyDetectsLanguage' \
    'preferences.automaticallyDetectsLanguage' \
    'usesLanguageCorrection: true'; do
    /usr/bin/grep -Fq "$required_service_contract" "$service" || \
        fail "The Vision OCR configuration is missing: $required_service_contract"
done

for required_preference_contract in \
    'static let englishUSIdentifier = "en-US"' \
    'languageIdentifiers.count > 1' \
    'recognition.languagePreferenceVersion' \
    'recognition.languageIdentifiers'; do
    if ! /usr/bin/grep -Fq "$required_preference_contract" "$preferences" "$settings_store"; then
        fail "The OCR preference contract is missing: $required_preference_contract"
    fi
done

for required_capture_contract in \
    'activeOCRRecognitionPreferences = ocrPreferencesReader.ocrRecognitionPreferences' \
    'preferences: activeOCRRecognitionPreferences' \
    'ocrPreferencesReader: settingsController'; do
    if ! /usr/bin/grep -Fq "$required_capture_contract" "$capture_command" "$app"; then
        fail "Capture does not snapshot and apply OCR preferences: $required_capture_contract"
    fi
done

for required_fallback_contract in \
    'final class SettingsController: OCRRecognitionPreferencesReading' \
    'if isOCRLanguageCatalogAvailable {'; do
    /usr/bin/grep -Fq "$required_fallback_contract" "$settings_controller" || \
        fail "The runtime English fallback must preserve saved language preferences: $required_fallback_contract"
done

for required_ui_contract in \
    'Section("Recognition")' \
    'Text Languages' \
    'Search languages' \
    'Recognition Priority' \
    'Reset to English' \
    'copylasso.languages.done'; do
    if ! /usr/bin/grep -Fq "$required_ui_contract" "$settings_view" "$editor_view"; then
        fail "The accessible language editor is missing: $required_ui_contract"
    fi
done

for required_test in \
    'testConfiguredLanguagesRecognizeRepresentativeScripts' \
    'testAcceptedCaptureSnapshotsRecognitionPreferencesForThatOperation' \
    'testResetRestoresEnglishOnlyRecognition'; do
    /usr/bin/grep -R -Fq "$required_test" CopyLassoTests || \
        fail "Multilingual OCR coverage is missing: $required_test"
done

if /usr/bin/find CopyLasso -type f \( \
    -iname '*.mlmodel' -o -iname '*.mlpackage' -o -iname '*.onnx' -o \
    -iname '*.tflite' -o -iname '*.ort' -o -iname '*.weights' \
    \) -print -quit | /usr/bin/grep -q .; then
    fail "Multilingual OCR must not bundle a model or language pack."
fi

if /usr/bin/grep -nE 'URLSession|NWConnection|WebKit|https?://' \
    "$catalog" "$service" "$preferences" "$editor_model" \
    "$settings_store" "$settings_controller" "$editor_view"; then
    fail "Multilingual OCR must not add a network path."
fi

for required_documentation in \
    '0.2.2 remains the latest public release' \
    'does not download language packs' \
    'does not add translation' \
    'language detection is enabled only when more than one language is selected'; do
    /usr/bin/grep -Fq "$required_documentation" "$contract" || \
        fail "The v0.3 contract is missing: $required_documentation"
done

for public_boundary in \
    'CopyLasso 0.2.2 is the latest public release' \
    'public 0.2.2 download yet.'; do
    /usr/bin/grep -Fq "$public_boundary" README.md || \
        fail "README source/public status is inaccurate: $public_boundary"
done

echo "Multilingual OCR audit passed."
