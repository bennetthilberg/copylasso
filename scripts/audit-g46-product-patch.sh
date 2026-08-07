#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"

fail() {
    echo "$1" >&2
    exit 1
}

require_text() {
    local relative_path="$1"
    local required_text="$2"

    /usr/bin/grep -Fq -- "$required_text" "$repository_root/$relative_path" || \
        fail "$relative_path is missing required G46 text: $required_text"
}

if git -C "$repository_root" grep -nE \
    'Check for Updates(\.\.\.|…)' -- ':!roadmap.md'; then
    fail 'Check for Updates must not retain a trailing ellipsis.'
fi

for source in \
    CopyLasso/SharedUI/MenuBarMenuView.swift \
    CopyLasso/SharedUI/SettingsView.swift; do
    require_text "$source" 'Button("Check for Updates")'
done
require_text CopyLassoUITests/CopyLassoUITests.swift '"Check for Updates",'
require_text README.md '**Check for Updates** in Settings or the menu checks immediately;'

privacy_words="$(/usr/bin/wc -w < "$repository_root/PRIVACY.md" | /usr/bin/tr -d ' ')"
[[ "$privacy_words" -le 700 ]] || \
    fail "PRIVACY.md must remain concise (700 words maximum; found $privacy_words)."
for privacy_boundary in \
    'Update requests send no screen pixels' \
    'Success sound playback receives no captured pixels, recognized content, or clipboard text.' \
    'Code payloads are recognized locally' \
    'manually install public CopyLasso 0.2.0 once'; do
    require_text PRIVACY.md "$privacy_boundary"
done

require_text CopyLasso/SharedUI/AboutView.swift \
    'static let iconTitleSpacing: CGFloat = 18'
require_text CopyLasso/SharedUI/AboutView.swift \
    'VStack(spacing: AboutLayout.iconTitleSpacing)'

for release_note_contract in \
    CopyLasso/Models/SecureUpdateReleaseNotesPresentation.swift \
    CopyLasso/SharedUI/SecureUpdatePresentation.swift \
    CopyLassoTests/Update/SecureUpdateReleaseNotesPresentationTests.swift; do
    [[ -s "$repository_root/$release_note_contract" ]] || \
        fail "The authenticated Markdown release-note correction is missing: $release_note_contract"
done
require_text CHANGELOG.md \
    'Update offers now render authenticated release notes in a bounded, scrollable native panel'
require_text README.md \
    'the app shows the authenticated version, rendered release notes, and exact download size before any download;'
require_text README.md \
    'Current unreleased source replaces that handoff with macOS'
require_text PRIVACY.md \
    'derives only'
require_text PRIVACY.md \
    'then captures that rectangle in'
require_text docs/architecture/capture-workflow.md \
    'Native interactive selection and bounded in-memory capture'
require_text docs/architecture/overview.md \
    'Fixed system interactive capture G46'
require_text docs/security-and-privacy-review.md \
    '| Selector subprocess misuse |'
require_text docs/testing.md \
    '## G46 Production Interactive Capture'

readonly application='CopyLasso/App/CopyLassoApp.swift'
readonly global_shortcut_controller='CopyLasso/App/GlobalShortcutController.swift'
readonly capture_command='CopyLasso/CaptureWorkflow/CaptureCommand.swift'
readonly interactive_capture_contract='CopyLasso/Services/InteractiveCaptureService.swift'
readonly system_capture='CopyLasso/Services/SystemInteractiveCaptureService.swift'
readonly screen_capture='CopyLasso/Services/SystemScreenCaptureService.swift'

for system_capture_contract in \
    'URL(fileURLWithPath: "/usr/sbin/screencapture")' \
    'arguments: ["-i", "-s", "-x", "-t", "png", "/dev/null"]' \
    'process.standardInput = FileHandle.nullDevice' \
    'process.standardOutput = FileHandle.nullDevice' \
    'process.standardError = FileHandle.nullDevice' \
    'try process.run()' \
    'CGEventSource.flagsState(.combinedSessionState).contains(.maskControl)' \
    'CGEventSource.keyState(.combinedSessionState, key: 49)' \
    'NSEvent.addGlobalMonitorForEvents(' \
    'matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]' \
    'let location = cgEvent.location' \
    'controlModifierActive = cgEvent.flags.contains(.maskControl)' \
    'spaceModifierActive: spaceModifierProvider()' \
    'SystemInteractivePointerTransition' \
    'SystemInteractiveSelectionTracker' \
    'let endedOnDifferentDisplay =' \
    'selectionResultFromCoreGraphics(' \
    'wasCancelledForControlModifier' \
    'process.interrupt()' \
    'screenCaptureService.capture(selection)' \
    'prepared.session.cancel()'; do
    require_text "$system_capture" "$system_capture_contract"
done

require_text \
    'CopyLassoTests/Services/SystemInteractiveSelectionTrackerTests.swift' \
    'testCrossDisplayReleaseFailsClosedInsteadOfCroppingTheVisibleRectangle'

if /usr/bin/grep -nE \
    'CGEventTap|\.keyDown|\.keyUp|\.flagsChanged' \
    "$repository_root/$system_capture"; then
    fail 'Selection tracking must not add an intercepting or keyboard event monitor.'
fi

for screen_capture_contract in \
    'let expectedDisplayBounds: CGRect' \
    'bounds: display.frame' \
    'rectsMatch(display.bounds, request.expectedDisplayBounds)'; do
    require_text "$screen_capture" "$screen_capture_contract"
done

for workflow_contract in \
    'interactiveCaptureService.prepareForCaptureTransition()' \
    'let outcome = try await service.capture()' \
    'permissionService.recordCaptureSuccess()' \
    'interactiveCaptureService.cancelCapture()'; do
    require_text "$capture_command" "$workflow_contract"
done

require_text "$interactive_capture_contract" 'protocol InteractiveCaptureService: AnyObject'
require_text "$application" 'interactiveCaptureService = SystemInteractiveCaptureService()'
require_text "$application" 'selectionService = nil'
require_text "$application" 'screenCaptureService = nil'
require_text "$application" 'runtimeOptions.usesLegacyCaptureWorkflow'
require_text "$application" 'interactiveCaptureService: interactiveCaptureService'

require_text "$global_shortcut_controller" 'guard event == .keyDown else {'
require_text "$global_shortcut_controller" 'captureCommand.performFromGlobalShortcut()'

system_selector_files="$({ /usr/bin/grep -R -lF '/usr/sbin/screencapture' \
    "$repository_root/CopyLasso" || true; })"
[[ "$system_selector_files" == "$repository_root/$system_capture" ]] || \
    fail 'The fixed system selector executable must remain confined to its narrow service.'

process_files="$({ /usr/bin/grep -R -lE '\bProcess\(\)' \
    "$repository_root/CopyLasso" || true; })"
[[ "$process_files" == "$repository_root/$system_capture" ]] || \
    fail 'Capture subprocess creation must remain confined to its narrow service.'

if /usr/bin/grep -nE \
    '(/bin/(sh|bash|zsh)|-c["'\'' ]|NSTask|temporaryDirectory|Data.*write\(to:|NSPasteboard|Pipe\(|standardOutput = outputPipe|/dev/stdout|CGImageSource|ImageIO|print\(|debugPrint\(|NSLog\(|os_log|Logger\()' \
    "$repository_root/$system_capture"; then
    fail 'The system selector must not use a shell, screenshot transport, pasteboard output, or logging.'
fi

if /usr/bin/grep -nF 'SIGKILL' "$repository_root/$system_capture"; then
    echo "G46 native-selector cancellation must permit clean macOS teardown." >&2
    exit 1
fi

if /usr/bin/grep -nE \
    'NSApp\.activate|makeKeyAndOrderFront|makeKey\(|orderFrontRegardless|addLocalMonitorForEvents|CGEventTapCreate|CGEvent\.tapCreate|CGRequest(Listen|Post)EventAccess|CGWarpMouseCursorPosition|CGDisplay(Hide|Show)Cursor|CGS[A-Z]|SLS[A-Z]' \
    "$repository_root/$system_capture" \
    "$repository_root/$capture_command" \
    "$repository_root/$global_shortcut_controller"; then
    fail 'The production system-selector path must preserve focus and avoid private or synthetic-input APIs.'
fi

echo 'CopyLasso G46 product patch audit passed.'
