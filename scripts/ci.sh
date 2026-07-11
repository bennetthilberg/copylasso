#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly project_path="$repository_root/CopyLasso.xcodeproj"
readonly scheme="CopyLasso"
readonly requested_architecture="${COPYLASSO_CI_ARCH:-$(uname -m)}"
readonly derived_data="${COPYLASSO_DERIVED_DATA_PATH:-$repository_root/.build/ci-$requested_architecture}"

case "$requested_architecture" in
    arm64 | x86_64) ;;
    *)
        echo "Unsupported CI architecture: $requested_architecture" >&2
        exit 1
        ;;
esac

case "$derived_data" in
    "$repository_root"/.build/*) ;;
    *)
        echo "Derived data must remain under $repository_root/.build." >&2
        exit 1
        ;;
esac

if [[ "$(xcodebuild -version | /usr/bin/head -n 1)" != "Xcode 26.6" ]]; then
    echo "CopyLasso CI requires Xcode 26.6." >&2
    xcodebuild -version >&2
    exit 1
fi

cd "$repository_root"
rm -rf "$derived_data"
mkdir -p "$derived_data"

echo "Linting Swift sources"
xcrun swift-format lint --recursive --strict \
    CopyLasso \
    CopyLassoTests \
    CopyLassoUITests

echo "Auditing privacy, security, entitlements, and dependencies"
./scripts/audit-privacy-security.sh

readonly committed_development_team_pattern='^[[:space:]]*"?DEVELOPMENT_TEAM(\[[^]]+\])?"?[[:space:]]*=[[:space:]]*[A-Z0-9]{10};'

if /usr/bin/grep -Eq "$committed_development_team_pattern" \
    CopyLasso.xcodeproj/project.pbxproj; then
    echo "A concrete Apple development team must not be committed to the Xcode project." >&2
    exit 1
fi

for required_source_group in App CaptureWorkflow Services Models Settings SharedUI; do
    if [[ ! -d "CopyLasso/$required_source_group" ]]; then
        echo "Required source group is missing: $required_source_group" >&2
        exit 1
    fi
done

if /usr/bin/grep -R -nE \
    '^[[:space:]]*import[[:space:]]+(AppKit|SwiftUI|ScreenCaptureKit|Vision|KeyboardShortcuts|ServiceManagement)[[:space:]]*$' \
    CopyLasso/Models CopyLasso/CaptureWorkflow; then
    echo "Models and capture-workflow state must not import UI, shortcut, or live platform frameworks." >&2
    exit 1
fi

readonly package_resolved="CopyLasso.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
if [[ ! -f "$package_resolved" ]] || \
    ! /usr/bin/grep -q '"location" : "https://github.com/sindresorhus/KeyboardShortcuts"' "$package_resolved" || \
    ! /usr/bin/grep -q '"revision" : "49c3fc04ea827f816df67843bfcc57286b47ff06"' "$package_resolved" || \
    ! /usr/bin/grep -q '"version" : "3.0.1"' "$package_resolved"; then
    echo "KeyboardShortcuts must remain resolved exactly to 3.0.1." >&2
    exit 1
fi

if ! /usr/bin/grep -q 'kind = exactVersion;' CopyLasso.xcodeproj/project.pbxproj || \
    ! /usr/bin/grep -q 'version = 3.0.1;' CopyLasso.xcodeproj/project.pbxproj || \
    ! /usr/bin/grep -q 'KeyboardShortcuts 3.0.1' THIRD_PARTY_NOTICES.md || \
    ! /usr/bin/grep -q 'License: MIT' THIRD_PARTY_NOTICES.md; then
    echo "The exact shortcut dependency and its MIT notice must remain documented." >&2
    exit 1
fi

service_management_imports="$({ /usr/bin/grep -R -l \
    '^[[:space:]]*import[[:space:]]\+ServiceManagement[[:space:]]*$' CopyLasso || true; })"
if [[ "$service_management_imports" != "CopyLasso/Services/LaunchAtLoginService.swift" ]]; then
    echo "ServiceManagement must remain confined to LaunchAtLoginService.swift." >&2
    exit 1
fi

readonly permission_service='CopyLasso/Services/ScreenCapturePermissionService.swift'
permission_api_files="$({ /usr/bin/grep -R -lE \
    'CGPreflightScreenCaptureAccess|CGRequestScreenCaptureAccess' CopyLasso || true; })"
if [[ "$permission_api_files" != "$permission_service" ]] || \
    ! /usr/bin/grep -q 'CGPreflightScreenCaptureAccess' "$permission_service" || \
    ! /usr/bin/grep -q 'CGRequestScreenCaptureAccess' "$permission_service"; then
    echo "Core Graphics Screen Recording permission APIs must remain confined to the production permission service." >&2
    exit 1
fi

readonly prohibited_capture_runtime_pattern='SCContentSharingPicker|CGWindowListCreateImage|CGDisplayCreateImage|--g06-capture-spike|--g07-selection-spike|sharingType[[:space:]]*=[[:space:]]*\.none|NSWindow\.SharingType\.none'
if /usr/bin/grep -R -nE "$prohibited_capture_runtime_pattern" CopyLasso; then
    echo "A prohibited capture, OCR, pasteboard, or retired experiment API remains in the application target." >&2
    exit 1
fi

readonly ocr_service='CopyLasso/Services/VisionOCRService.swift'
ocr_api_files="$({ /usr/bin/grep -R -lE \
    'import[[:space:]]+Vision|VNRecognizeTextRequest|VNImageRequestHandler' CopyLasso || true; })"
if [[ "$ocr_api_files" != "$ocr_service" ]] || \
    ! /usr/bin/grep -q 'VNRecognizeTextRequestRevision3' "$ocr_service" || \
    ! /usr/bin/grep -q 'request.recognitionLevel = .accurate' "$ocr_service" || \
    ! /usr/bin/grep -q 'recognitionLanguages: \["en-US"\]' "$ocr_service" || \
    ! /usr/bin/grep -q 'automaticallyDetectsLanguage: false' "$ocr_service" || \
    ! /usr/bin/grep -q 'usesLanguageCorrection: true' "$ocr_service"; then
    echo "Vision OCR must remain confined to the configured production service." >&2
    exit 1
fi

if /usr/bin/grep -nE 'print\(|debugPrint\(|NSLog\(|os_log|Logger\(' "$ocr_service"; then
    echo "The OCR service must not log recognized content or image metadata." >&2
    exit 1
fi

readonly capture_service='CopyLasso/Services/SystemScreenCaptureService.swift'
capture_api_files="$({ /usr/bin/grep -R -lE \
    'import[[:space:]]+ScreenCaptureKit|SCScreenshotManager|SCShareableContent|SCContentFilter|SCStreamConfiguration' CopyLasso || true; })"
if [[ "$capture_api_files" != "$capture_service" ]] || \
    ! /usr/bin/grep -q 'SCScreenshotManager.captureImage' "$capture_service" || \
    ! /usr/bin/grep -q 'configuration.showsCursor = request.showsCursor' "$capture_service" || \
    ! /usr/bin/grep -q 'configuration.capturesAudio = request.capturesAudio' "$capture_service"; then
    echo "ScreenCaptureKit APIs must remain confined to the production in-memory capture service." >&2
    exit 1
fi

readonly prohibited_image_persistence_pattern='CGImageDestination|NSBitmapImageRep|representation\(using:|pngRepresentation|jpegRepresentation|CIContext.*write|Data.*write\(to:'
if /usr/bin/grep -R -nE "$prohibited_image_persistence_pattern" CopyLasso; then
    echo "The application target must not encode or persist captured pixels." >&2
    exit 1
fi

readonly selection_service='CopyLasso/Services/AppKitRegionSelectionService.swift'
selection_api_files="$({ /usr/bin/grep -R -lE \
    'CGDisplayBounds|didChangeScreenParametersNotification|NSCursor\.crosshair|RegionSelectionPanel' CopyLasso || true; })"
if [[ "$selection_api_files" != "$selection_service" ]] || \
    ! /usr/bin/grep -q 'styleMask: \[.borderless, .nonactivatingPanel\]' "$selection_service" || \
    ! /usr/bin/grep -q 'panel.level = .screenSaver' "$selection_service" || \
    ! /usr/bin/grep -q 'panel.collectionBehavior = \[.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle\]' "$selection_service"; then
    echo "Production display and selection-overlay APIs must remain confined to the AppKit selection service." >&2
    exit 1
fi

readonly multi_display_tests='CopyLassoTests/Models/MultiDisplayBehaviorTests.swift'
if [[ ! -e "$multi_display_tests" ]] || \
    ! /usr/bin/grep -q 'displayPointSize' CopyLasso/Models/SelectionGeometry.swift || \
    ! /usr/bin/grep -q 'expectedDisplayPointSize' "$capture_service" || \
    ! /usr/bin/grep -q 'testEverySyntheticDisplayPreservesIdentityAndLocalPixelsThroughCapturePlanning' "$multi_display_tests" || \
    ! /usr/bin/grep -q 'testCurrentDisplayChangesRejectTheOriginalRequestForEveryScale' "$multi_display_tests" || \
    /usr/bin/grep -q 'visibleFrame' "$selection_service"; then
    echo "G19 must retain complete-frame overlays and full display-snapshot validation." >&2
    exit 1
fi

readonly feedback_panel='CopyLasso/SharedUI/FeedbackPanel.swift'
screen_list_files="$({ /usr/bin/grep -R -l 'NSScreen\.screens' CopyLasso || true; } | /usr/bin/sort)"
expected_screen_list_files="$(/usr/bin/printf '%s\n%s' "$selection_service" "$feedback_panel" | /usr/bin/sort)"
if [[ "$screen_list_files" != "$expected_screen_list_files" ]]; then
    echo "Display enumeration must remain confined to selection and HUD placement." >&2
    exit 1
fi

if [[ -e CopyLasso/Services/PendingRegionSelectionService.swift ]] || \
    [[ -e CopyLasso/Services/PendingScreenCaptureService.swift ]] || \
    [[ -e CopyLasso/Services/PendingOCRService.swift ]] || \
    [[ ! -e "$ocr_service" ]] || \
    ! /usr/bin/grep -q 'ocrService: VisionOCRService()' CopyLasso/App/CopyLassoApp.swift; then
    echo "G15 must use production selection, capture, and Vision OCR without retired pending services." >&2
    exit 1
fi

readonly text_assembler='CopyLasso/Models/TextAssembler.swift'
if [[ ! -e "$text_assembler" ]] || \
    ! /usr/bin/grep -q 'textAssembler: TextAssembler()' CopyLasso/App/CopyLassoApp.swift || \
    /usr/bin/grep -qE '^[[:space:]]*import[[:space:]]+(AppKit|SwiftUI|ScreenCaptureKit|Vision)' "$text_assembler" || \
    /usr/bin/grep -qE '^[[:space:]]*import[[:space:]]+Vision' CopyLassoTests/Models/TextAssemblerTests.swift; then
    echo "G16 text assembly must remain pure, platform-neutral, and active in the workflow." >&2
    exit 1
fi

readonly clipboard_service='CopyLasso/Services/ClipboardService.swift'
pasteboard_api_files="$({ /usr/bin/grep -R -l 'NSPasteboard' CopyLasso || true; })"
if [[ "$pasteboard_api_files" != "$clipboard_service" ]] || \
    ! /usr/bin/grep -q 'NSPasteboard = \.general' "$clipboard_service" || \
    ! /usr/bin/grep -q 'replaceWithPlainText' "$clipboard_service" || \
    ! /usr/bin/grep -q 'forType: \.string' "$clipboard_service" || \
    /usr/bin/grep -qE 'pasteboardItems|data\(forType:|string\(forType:|readObjects|canReadObject' "$clipboard_service"; then
    echo "General pasteboard access must remain write-only, plain-text-only, and confined to the clipboard service." >&2
    exit 1
fi

if [[ ! -e "$feedback_panel" ]] || \
    ! /usr/bin/grep -q 'styleMask: \[\.borderless, \.nonactivatingPanel\]' "$feedback_panel" || \
    ! /usr/bin/grep -q 'panel.ignoresMouseEvents = true' "$feedback_panel" || \
    ! /usr/bin/grep -q 'panel.level = \.statusBar' "$feedback_panel" || \
    ! /usr/bin/grep -q 'panel.orderFrontRegardless()' "$feedback_panel" || \
    /usr/bin/grep -qE 'NSApp\.activate|NSSound|UserNotifications|UNUserNotification' "$feedback_panel"; then
    echo "G17 feedback must use one silent, nonactivating, mouse-transparent HUD." >&2
    exit 1
fi

if ! /usr/bin/grep -q 'clipboardService: SystemClipboardService()' CopyLasso/App/CopyLassoApp.swift || \
    ! /usr/bin/grep -q 'feedbackService: feedbackController' CopyLasso/App/CopyLassoApp.swift || \
    ! /usr/bin/grep -q 'feedbackModel: feedbackController.model' CopyLasso/App/CopyLassoApp.swift; then
    echo "The production clipboard, HUD, and temporary menu state must remain wired at the app root." >&2
    exit 1
fi

readonly capture_command='CopyLasso/CaptureWorkflow/CaptureCommand.swift'
readonly capture_coordinator='CopyLasso/CaptureWorkflow/CaptureCoordinator.swift'
readonly workflow_integration_tests='CopyLassoTests/CaptureWorkflow/CaptureWorkflowIntegrationTests.swift'
if [[ ! -e "$workflow_integration_tests" ]] || \
    ! /usr/bin/grep -q 'runPrivateOperation' "$capture_command" || \
    ! /usr/bin/grep -q 'CaptureOperationInterruption' "$capture_command" || \
    ! /usr/bin/grep -q 'testTwentyFiveConsecutiveSuccessfulCapturesRemainReusable' "$workflow_integration_tests" || \
    ! /usr/bin/grep -q 'testTwentyAlternatingSuccessAndCancellationCyclesPreserveClipboardOnCancellation' "$workflow_integration_tests" || \
    ! /usr/bin/grep -q 'testPixelsAndUnboundedTextAreReleasedBeforeHeldFeedback' "$workflow_integration_tests" || \
    ! /usr/bin/grep -q 'testMenuAndShortcutRouteThroughTheExactSameSuccessfulCommand' "$workflow_integration_tests"; then
    echo "G18 must retain its private operation boundary and end-to-end stress integration suite." >&2
    exit 1
fi

readonly lifecycle_controller='CopyLasso/App/ApplicationLifecycleController.swift'
readonly lifecycle_logger='CopyLasso/Services/CaptureLifecycleLogger.swift'
readonly lifecycle_tests='CopyLassoTests/CaptureWorkflow/CaptureLifecycleTests.swift'
readonly lifecycle_controller_tests='CopyLassoTests/App/ApplicationLifecycleControllerTests.swift'
lifecycle_log_files="$({ /usr/bin/grep -R -lE '^[[:space:]]*import[[:space:]]+OSLog|=[[:space:]]*Logger\(' CopyLasso || true; })"
if [[ "$lifecycle_log_files" != "$lifecycle_logger" ]] || \
    [[ ! -e "$lifecycle_controller" ]] || \
    [[ ! -e "$lifecycle_tests" ]] || \
    [[ ! -e "$lifecycle_controller_tests" ]] || \
    ! /usr/bin/grep -q 'cancelActiveOperation' "$capture_command" || \
    ! /usr/bin/grep -q 'NSWorkspace.sessionDidResignActiveNotification' "$lifecycle_controller" || \
    ! /usr/bin/grep -q 'lifecycleController.start()' CopyLasso/App/CopyLassoApp.swift || \
    ! /usr/bin/grep -q 'testSystemInterruptionCancelsPendingCaptureWithoutDownstreamWork' "$lifecycle_tests" || \
    ! /usr/bin/grep -q 'testSystemEventSourceMapsWorkspaceAndApplicationNotificationsAndStopsCleanly' "$lifecycle_controller_tests" || \
    /usr/bin/grep -F -q '\(' "$lifecycle_logger" || \
    /usr/bin/grep -qE 'CGImage|RecognizedText|SelectionResult|NSPasteboard|rawError|preview' "$lifecycle_logger"; then
    echo "G20 must retain owned lifecycle cancellation and fixed content-free diagnostics." >&2
    exit 1
fi

readonly accessibility_appearance='CopyLasso/SharedUI/AccessibilityAppearance.swift'
readonly accessibility_tests='CopyLassoTests/SharedUI/AccessibilityAppearanceTests.swift'
readonly accessibility_documentation='docs/architecture/accessibility-and-appearance.md'
if [[ ! -e "$accessibility_appearance" ]] || \
    [[ ! -e "$accessibility_tests" ]] || \
    [[ ! -e "$accessibility_documentation" ]] || \
    ! /usr/bin/grep -q 'accessibilityDisplayShouldIncreaseContrast' "$accessibility_appearance" || \
    ! /usr/bin/grep -q 'accessibilityDisplayShouldReduceMotion' "$accessibility_appearance" || \
    ! /usr/bin/grep -q 'appearanceProvider.currentAppearance.selectionOverlayStyle' \
      CopyLasso/Services/AppKitRegionSelectionService.swift || \
    ! /usr/bin/grep -q 'style.outerBorderWidth' \
      CopyLasso/Services/AppKitRegionSelectionService.swift || \
    ! /usr/bin/grep -q 'FeedbackPanelLayout.contentHeight' \
      CopyLasso/SharedUI/FeedbackPanel.swift || \
    ! /usr/bin/grep -q 'animationBehavior = .none' CopyLasso/SharedUI/FeedbackPanel.swift || \
    ! /usr/bin/grep -q 'animationBehavior = .none' \
      CopyLasso/SharedUI/PermissionRecoveryPanel.swift || \
    ! /usr/bin/grep -q 'AccessibilityAuditCopy.shortcutRecorderLabel' \
      CopyLasso/SharedUI/OnboardingView.swift || \
    ! /usr/bin/grep -q 'AccessibilityAuditCopy.shortcutRecorderLabel' \
      CopyLasso/SharedUI/SettingsView.swift || \
    ! /usr/bin/grep -q 'testProductionPanelExpandsVerticallyForWrappedPreviewInsteadOfClipping' \
      CopyLassoTests/SharedUI/FeedbackPanelControllerTests.swift || \
    ! /usr/bin/grep -q 'testOnboardingExposesCompoundControlNamesAndCompletesFromTheKeyboard' \
      CopyLassoUITests/CopyLassoUITests.swift || \
    /usr/bin/grep -R -q 'animationBehavior = .utilityWindow' CopyLasso/SharedUI || \
    /usr/bin/grep -q 'lineLimit(2)' CopyLasso/SharedUI/FeedbackPanel.swift || \
    /usr/bin/grep -q 'frame(width: 560, height: 620)' CopyLasso/SharedUI/OnboardingView.swift || \
    /usr/bin/grep -q 'frame(width: 520, height: 560)' CopyLasso/SharedUI/SettingsView.swift; then
    echo "G21 must retain accessible controls, adaptive text, contrast, and motion-free panels." >&2
    exit 1
fi

if /usr/bin/grep -qE 'CGImage|RecognizedTextObservation|SelectionResult|CaptureFeedback' \
    "$capture_coordinator"; then
    echo "CaptureCoordinator must remain free of geometry, pixels, recognized text, and feedback payloads." >&2
    exit 1
fi

if /usr/bin/grep -nE 'print\(|debugPrint\(|NSLog\(|os_log|Logger\(|UserDefaults' \
    "$clipboard_service" "$feedback_panel" CopyLasso/Models/FeedbackPreview.swift \
    CopyLasso/Models/FeedbackPresentationContent.swift; then
    echo "Clipboard text and feedback previews must not be logged or persisted." >&2
    exit 1
fi

if /usr/bin/grep -R -n 'WindowGroup' CopyLasso; then
    echo "The dockless shell must not restore a normal launch window." >&2
    exit 1
fi

if ! /usr/bin/grep -q 'MenuBarExtra' CopyLasso/App/CopyLassoApp.swift || \
    ! /usr/bin/grep -q 'menuBarExtraStyle(.menu)' CopyLasso/App/CopyLassoApp.swift; then
    echo "The application must expose the native pull-down menu-bar shell." >&2
    exit 1
fi

if /usr/bin/grep -q 'EXCLUDED_SOURCE_FILE_NAMES' CopyLasso.xcodeproj/project.pbxproj; then
    echo "Debug and Release must compile the same production-neutral source architecture." >&2
    exit 1
fi

echo "Resolving package dependencies"
xcodebuild -resolvePackageDependencies \
    -project "$project_path" \
    -scheme "$scheme" \
    -clonedSourcePackagesDirPath "$derived_data/SourcePackages"

readonly destination="platform=macOS,arch=$requested_architecture"
common_arguments=(
    -project "$project_path"
    -scheme "$scheme"
    -destination "$destination"
    -derivedDataPath "$derived_data"
    -clonedSourcePackagesDirPath "$derived_data/SourcePackages"
    CODE_SIGNING_ALLOWED=NO
)

echo "Building Debug for $requested_architecture"
xcodebuild build \
    "${common_arguments[@]}" \
    -configuration Debug

probe_arguments=('SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited)')
if [[ "${COPYLASSO_CI_FAILURE_PROBE:-false}" == "true" ]]; then
    probe_arguments=('SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) COPYLASSO_CI_FAILURE_PROBE')
    echo "Controlled CI failure probe enabled"
fi

echo "Building unit-test and UI-test bundles"
xcodebuild build-for-testing \
    "${common_arguments[@]}" \
    -configuration Debug \
    "${probe_arguments[@]}"

echo "Running unit tests"
xcodebuild test-without-building \
    "${common_arguments[@]}" \
    -configuration Debug \
    -parallel-testing-enabled NO \
    -test-timeouts-enabled YES \
    -default-test-execution-time-allowance 60 \
    -maximum-test-execution-time-allowance 120 \
    -only-testing:CopyLassoTests \
    -resultBundlePath "$derived_data/UnitTests.xcresult" \
    "${probe_arguments[@]}"

echo "Running the complete unit bundle with networking denied"
COPYLASSO_OFFLINE_DERIVED_DATA_PATH="$derived_data" \
    ./scripts/test-offline.sh

echo "Inspecting required build settings"
xcodebuild -showBuildSettings \
    -project "$project_path" \
    -scheme "$scheme" \
    -configuration Debug \
    CODE_SIGNING_ALLOWED=NO \
    > "$derived_data/debug-build-settings.txt"
xcodebuild -showBuildSettings \
    -project "$project_path" \
    -scheme "$scheme" \
    -configuration Release \
    CODE_SIGNING_ALLOWED=NO \
    > "$derived_data/release-build-settings.txt"

assert_setting() {
    local settings_file="$1"
    local setting_name="$2"
    local expected_value="$3"

    if ! /usr/bin/grep -Eq "^[[:space:]]+$setting_name = $expected_value$" "$settings_file"; then
        echo "Expected $setting_name to equal $expected_value." >&2
        exit 1
    fi
}

assert_setting "$derived_data/debug-build-settings.txt" MACOSX_DEPLOYMENT_TARGET 14.0
assert_setting "$derived_data/debug-build-settings.txt" SWIFT_VERSION 6.0
assert_setting "$derived_data/debug-build-settings.txt" SWIFT_STRICT_CONCURRENCY complete
assert_setting "$derived_data/debug-build-settings.txt" SWIFT_TREAT_WARNINGS_AS_ERRORS YES
assert_setting "$derived_data/debug-build-settings.txt" GCC_TREAT_WARNINGS_AS_ERRORS YES
assert_setting "$derived_data/debug-build-settings.txt" ENABLE_APP_SANDBOX YES
assert_setting "$derived_data/debug-build-settings.txt" CODE_SIGN_ENTITLEMENTS CopyLasso/CopyLasso.entitlements
assert_setting "$derived_data/debug-build-settings.txt" PRODUCT_BUNDLE_IDENTIFIER io.github.bennetthilberg.copylasso.debug
assert_setting "$derived_data/debug-build-settings.txt" INFOPLIST_FILE Configuration/CopyLasso-Info.plist
assert_setting "$derived_data/debug-build-settings.txt" INFOPLIST_KEY_LSUIElement YES
assert_setting "$derived_data/release-build-settings.txt" PRODUCT_BUNDLE_IDENTIFIER io.github.bennetthilberg.copylasso
assert_setting "$derived_data/release-build-settings.txt" ENABLE_APP_SANDBOX YES
assert_setting "$derived_data/release-build-settings.txt" CODE_SIGN_ENTITLEMENTS CopyLasso/CopyLasso.entitlements
assert_setting "$derived_data/release-build-settings.txt" ENABLE_HARDENED_RUNTIME YES
assert_setting "$derived_data/release-build-settings.txt" INFOPLIST_FILE Configuration/CopyLasso-Info.plist
assert_setting "$derived_data/release-build-settings.txt" INFOPLIST_KEY_LSUIElement YES
assert_setting "$derived_data/release-build-settings.txt" ARCHS "arm64 x86_64"
assert_setting "$derived_data/release-build-settings.txt" ONLY_ACTIVE_ARCH NO

readonly debug_info_plist="$derived_data/Build/Products/Debug/CopyLasso.app/Contents/Info.plist"
if [[ "$(/usr/bin/plutil -extract LSUIElement raw -o - "$debug_info_plist")" != "true" ]]; then
    echo "The Debug application is not configured as a dockless agent." >&2
    exit 1
fi
if [[ "$(/usr/bin/plutil -extract NSScreenCaptureUsageDescription raw -o - "$debug_info_plist")" != "CopyLasso captures the screen region you select to recognize text locally." ]]; then
    echo "The Debug application is missing its screen-capture usage description." >&2
    exit 1
fi

echo "Building Universal 2 Release"
xcodebuild build \
    -project "$project_path" \
    -scheme "$scheme" \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$derived_data" \
    -clonedSourcePackagesDirPath "$derived_data/SourcePackages" \
    CODE_SIGNING_ALLOWED=NO

readonly release_info_plist="$derived_data/Build/Products/Release/CopyLasso.app/Contents/Info.plist"
if [[ "$(/usr/bin/plutil -extract LSUIElement raw -o - "$release_info_plist")" != "true" ]]; then
    echo "The Release application is not configured as a dockless agent." >&2
    exit 1
fi
if [[ "$(/usr/bin/plutil -extract NSScreenCaptureUsageDescription raw -o - "$release_info_plist")" != "CopyLasso captures the screen region you select to recognize text locally." ]]; then
    echo "The Release application is missing its screen-capture usage description." >&2
    exit 1
fi

readonly release_executable="$derived_data/Build/Products/Release/CopyLasso.app/Contents/MacOS/CopyLasso"
if [[ ! -x "$release_executable" ]]; then
    echo "Release executable was not produced." >&2
    exit 1
fi

linked_non_system="$({ /usr/bin/otool -L "$release_executable" | \
    /usr/bin/awk '/^\t/{print $1}' | \
    /usr/bin/grep -vE '^(/System/Library/|/usr/lib/)' || true; })"
if [[ -n "$linked_non_system" ]]; then
    echo "Release links an unexpected non-system dynamic library." >&2
    exit 1
fi

if /usr/bin/nm -u "$release_executable" | \
    /usr/bin/grep -qE 'NSURLSession|NWConnection|_nw_|CFHTTP|WebKit|_socket$'; then
    echo "Release contains an unexpected network-client symbol." >&2
    exit 1
fi

if /usr/bin/strings "$release_executable" | /usr/bin/grep -qE -- '--g10-g11-|--g12-|--g13-|--g14-|--g15-|--g16-|--g17-'; then
    echo "Debug-only UI-test controls leaked into Release." >&2
    exit 1
fi

readonly debug_module="$derived_data/Build/Products/Debug/CopyLasso.swiftmodule/$requested_architecture-apple-macos.swiftmodule"
if [[ ! -f "$debug_module" ]] || \
    ! /usr/bin/grep -a -q 'CaptureCoordinator' "$debug_module" || \
    ! /usr/bin/grep -a -q 'DisplayGeometry' "$debug_module" || \
    ! /usr/bin/grep -a -q 'CaptureCommand' "$debug_module" || \
    ! /usr/bin/grep -a -q 'SystemScreenCapturePermissionService' "$debug_module" || \
    ! /usr/bin/grep -a -q 'AppKitRegionSelectionService' "$debug_module" || \
    ! /usr/bin/grep -a -q 'SystemScreenCaptureService' "$debug_module" || \
    ! /usr/bin/grep -a -q 'VisionOCRService' "$debug_module" || \
    ! /usr/bin/grep -a -q 'TextAssembler' "$debug_module" || \
    ! /usr/bin/grep -a -q 'SystemClipboardService' "$debug_module" || \
    ! /usr/bin/grep -a -q 'FeedbackPanelController' "$debug_module" || \
    ! /usr/bin/grep -a -q 'PermissionRecoveryPanelController' "$debug_module" || \
    ! /usr/bin/grep -a -q 'SettingsController' "$debug_module" || \
    ! /usr/bin/grep -a -q 'GlobalShortcutController' "$debug_module" || \
    ! /usr/bin/grep -a -q 'ApplicationLifecycleController' "$debug_module" || \
    ! /usr/bin/grep -a -q 'SystemCaptureLifecycleLogger' "$debug_module" || \
    ! /usr/bin/grep -a -q 'AccessibilityAppearance' "$debug_module" || \
    ! /usr/bin/grep -a -q 'SystemAccessibilityAppearanceProvider' "$debug_module"; then
    echo "Debug is missing the production-neutral workflow architecture." >&2
    exit 1
fi

for release_architecture in arm64 x86_64; do
    release_module="$derived_data/Build/Products/Release/CopyLasso.swiftmodule/$release_architecture-apple-macos.swiftmodule"
    if [[ ! -f "$release_module" ]]; then
        echo "Release Swift module is missing $release_architecture." >&2
        exit 1
    fi
    if ! /usr/bin/grep -a -q 'CaptureCoordinator' "$release_module" || \
        ! /usr/bin/grep -a -q 'DisplayGeometry' "$release_module" || \
        ! /usr/bin/grep -a -q 'CaptureCommand' "$release_module" || \
        ! /usr/bin/grep -a -q 'SystemScreenCapturePermissionService' "$release_module" || \
        ! /usr/bin/grep -a -q 'AppKitRegionSelectionService' "$release_module" || \
        ! /usr/bin/grep -a -q 'SystemScreenCaptureService' "$release_module" || \
        ! /usr/bin/grep -a -q 'VisionOCRService' "$release_module" || \
        ! /usr/bin/grep -a -q 'TextAssembler' "$release_module" || \
        ! /usr/bin/grep -a -q 'SystemClipboardService' "$release_module" || \
        ! /usr/bin/grep -a -q 'FeedbackPanelController' "$release_module" || \
        ! /usr/bin/grep -a -q 'PermissionRecoveryPanelController' "$release_module" || \
        ! /usr/bin/grep -a -q 'SettingsController' "$release_module" || \
        ! /usr/bin/grep -a -q 'GlobalShortcutController' "$release_module" || \
        ! /usr/bin/grep -a -q 'ApplicationLifecycleController' "$release_module" || \
        ! /usr/bin/grep -a -q 'SystemCaptureLifecycleLogger' "$release_module" || \
        ! /usr/bin/grep -a -q 'AccessibilityAppearance' "$release_module" || \
        ! /usr/bin/grep -a -q 'SystemAccessibilityAppearanceProvider' "$release_module"; then
        echo "Release is missing the production-neutral workflow architecture for $release_architecture." >&2
        exit 1
    fi
done

readonly release_architectures="$(xcrun lipo -archs "$release_executable")"
for required_architecture in arm64 x86_64; do
    if [[ " $release_architectures " != *" $required_architecture "* ]]; then
        echo "Release executable is missing $required_architecture." >&2
        exit 1
    fi
done

echo "CopyLasso CI passed for $requested_architecture; Release architectures: $release_architectures"
