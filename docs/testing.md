# Testing CopyLasso

CopyLasso's canonical unsigned build and unit-test pipeline is:

```sh
./scripts/ci.sh
```

The pipeline lints all Swift source, resolves the exact package dependency, builds Debug and both XCTest bundles, runs the unit suite serially with timeouts, inspects required build and privacy boundaries, builds Universal 2 Release, and verifies both executable slices. It does not launch the unsigned UI-test runner or alter macOS privacy state.

## Controlled Permission And Selection UI Coverage

Signed UI tests use Debug-only permission doubles. They cover prior-request and previously-granted recovery wording, singleton reuse, System Settings failure instructions, retry routing, Cancel, menu availability, keyboard actions, and accessibility identifiers without calling Core Graphics permission functions or changing real TCC state.

Ordinary signed UI tests use deterministic Debug-only selection and capture doubles so shell tests never unexpectedly cover the desktop or touch TCC. Tests launched with `--g13-live-selection` use the production AppKit service with controlled permission and in-memory capture. They verify that the overlay is accessible, cancellation removes it, a valid drag reaches production OCR and then the pending formatting boundary, the command becomes reusable, and the clipboard remains unchanged.

The controlled launch arguments begin with `--g12-` and `--g13-` and are compiled out of Release. CI inspects the Release executable to prevent them from leaking. The application uses the real production permission and selection services unless the existing `--g10-g11-ui-testing` boundary selects their controlled alternatives; `--g13-live-selection` explicitly restores the real selection adapter for overlay UI coverage.

Run the signed UI suite through Xcode with the shared `CopyLasso` scheme and **My Mac**, or use a locally signed `xcodebuild test` invocation. Keep the development team only in ignored `Local.xcconfig`; never paste signing identity details into logs or documentation.

## Real Screen Recording Permission Matrix

Use one stably Apple Development-signed Debug application for the entire matrix. Changing its signing requirement or bundle identifier can create a different macOS privacy identity and invalidate the result.

First clear CopyLasso-owned development state from **Settings > Reset Local Development State…**, quit CopyLasso, and then reset only the Debug bundle's Screen Recording decision:

```sh
/usr/bin/tccutil reset ScreenCapture io.github.bennetthilberg.copylasso.debug
```

This command changes macOS privacy state and must never run automatically in tests or CI.

Verify in this order:

1. Launch CopyLasso normally. Confirm there is no Screen Recording prompt or recovery panel before a user command.
2. With another application frontmost, invoke **Capture Text**, choose **Deny** in the macOS dialog, and confirm one CopyLasso recovery panel appears. Selection must not begin, and the clipboard must remain unchanged.
3. Invoke Capture Text again from both the menu and shortcut. Confirm macOS does not stack request dialogs, CopyLasso reuses one recovery panel, and each attempt returns the coordinator to idle.
4. Choose **Open System Settings**. Confirm the Screen & System Audio Recording pane opens. Enable CopyLasso and follow the actual macOS **Quit & Reopen** prompt if one appears; otherwise return to CopyLasso and explicitly choose **Try Again**. CopyLasso must not retry automatically. If **Later** was chosen and access is still unavailable, **Try Again** reports that CopyLasso must be quit and reopened rather than appearing inert.
5. After any required relaunch, invoke Capture Text. Confirm authorization presents the production selection overlay. Cancel with Escape and verify the overlay disappears, the frontmost application remains unchanged, the clipboard is unchanged, and the command returns to idle.
6. Disable CopyLasso in Screen & System Audio Recording and relaunch it. Invoke Capture Text and confirm the recovery copy says access was previously available and may have been turned off; it must not claim definitive revocation.
7. Repeat recovery while an ordinary full-screen application is frontmost. Confirm presenting or updating CopyLasso's nonactivating panel does not change the frontmost application. Only **Open System Settings** intentionally changes focus.
8. Confirm macOS did not show the ScreenCaptureKit private-window-picker-bypass warning and that no Accessibility, Input Monitoring, Microphone, or clipboard access was introduced.

Core Graphics preflight may remain positive inside a process after permission is disabled. G12 records revocation once preflight reflects it, normally after relaunch. The G14 capture path treats an actual ScreenCaptureKit denial as authoritative when preflight is stale.

### G12 Verified Result

The production matrix passed July 10, 2026 on macOS 26.5.1 (`25F80`) with Xcode 26.6 (`17F113`) and one stably Apple Development-signed Debug identity:

- Ordinary launch caused no Screen Recording prompt or recovery panel.
- The first shortcut request displayed only the macOS Screen Recording dialog. Choosing **Deny** produced one CopyLasso recovery panel after the system response.
- Three subsequent shortcut attempts reused that panel and produced no additional system dialog.
- **Open System Settings** opened Screen & System Audio Recording directly. Choosing **Later** after enabling access caused no automatic retry; the explicit retry guidance correctly required a relaunch.
- The designated signing requirement matched across clean build locations. After relaunch, three authorized shortcut requests reached the temporary selection boundary and returned with no overlay, pixels, OCR, clipboard change, or visible feedback.
- After revocation and relaunch, CopyLasso used the cautious previously-observed-access wording. The panel and its retry update appeared over a full-screen TextEdit Space while Launch Services still reported that CopyLasso was not frontmost.
- No ScreenCaptureKit private-window-picker warning, Accessibility, Input Monitoring, Microphone, capture, OCR, or pasteboard behavior occurred.

During the revocation check, macOS initially relaunched a retired scaffold from Xcode's default DerivedData because that duplicate bundle remained registered with Launch Services. Its normal window and missing `LSUIElement` identified it as stale, while the current G12 build was verified dockless and free of the retired placeholder. Unregistering only the stale generated build and registering the current signed bundle restored the intended test. Keep one Debug copy registered when validating **Quit & Reopen** so Launch Services cannot choose an obsolete duplicate with the same bundle identifier.

## Expected Permission Observations

| Direct observation and local history | CopyLasso observation |
| --- | --- |
| Preflight granted | Granted; record previously observed access |
| Not granted; never requested in this preferences history | Not granted; first user command may request access |
| Not granted; a request was recorded | Not granted after a prior request; macOS does not expose denied versus pending |
| Not granted; access was previously observed | Not granted after previously observed access; access may have been turned off |

Permission history contains only the two booleans needed for these neutral labels. It contains no pixels, recognized text, raw platform error, or definitive copy of macOS authorization state.

## Real Selection Overlay Matrix

Use the same stably signed Debug app after Screen Recording access is enabled. For the isolated overlay regression matrix, use the existing controlled UI boundary so downstream capture produces only its deterministic blank image; retaining one stable app avoids mixing selection evidence with permission-identity churn.

1. On the primary display, invoke Capture Text from both the menu and shortcut. Verify the overlay is clear before mouse-down, the cursor is a crosshair, and only the area outside the active rectangle dims after dragging begins.
2. Exercise forward and reverse drags, a click, a sub-four-point drag, exactly four points, Escape before dragging, Escape during dragging, and every display-edge clamp.
3. Connect an extended display and repeat a selection there. Record fresh display identifiers, AppKit frames, Core Graphics bounds, and backing scales; never hardcode runtime identifiers.
4. Drag from each display toward the other. The rectangle must stop at the initiating display edge, and only that display may dim.
5. Repeat menu and shortcut selection at least 20 times across valid, click, and Escape outcomes. Every outcome must remove all panels, restore the cursor, leave the command reusable, and leave the clipboard unchanged.
6. Repeat with Finder, a browser, TextEdit, another Space, and a full-screen Space frontmost. Starting and cancelling selection must not activate CopyLasso or switch Spaces.
7. Change a display resolution or disconnect an extended display during selection. The active operation must cancel once, remove all panels, and rebuild fresh descriptors on the next request.
8. Terminate CopyLasso during selection and verify no panel, dim, cursor override, observer, controller, or continuation remains. Use Xcode's memory graph or debugger to confirm the completed controller and surfaces are released.
9. Inspect light, dark, increased-contrast, and VoiceOver behavior. The black-and-white border and crosshair must remain distinguishable, and the overlay must expose its selection label and Escape help.
10. Confirm no pixel file, retained image, pasteboard write, Accessibility prompt, or Input Monitoring prompt occurs. The controlled blank-image path should now produce distinct no-text feedback while preserving the clipboard; real successful clipboard output belongs to the separate G17 matrix below.

### G13 Production Verification Record

On July 10, 2026, the production adapter was exercised on macOS 26.5.1 with Xcode 26.6. Fresh enumeration reported the Dell primary as display ID `4`, AppKit and Core Graphics bounds `(0, 0, 1920, 1080)`, 1× backing scale, and a matching 100-point backing conversion; System Profiler reported 1920 × 1080 at 144 Hz.

- Both the status menu and configured global shortcut presented exactly one accessible overlay while TextEdit remained frontmost.
- Escape, click cancellation, a valid 220 × 120-point drag, and 20 mixed signed UI sessions removed all panels, restored command availability, and left the clipboard unchanged.
- The same shortcut behavior passed with TextEdit in an `AXFullScreen` Space without activating CopyLasso or switching Spaces.
- Quitting during selection removed the sole overlay and process. Accessibility inspection found zero CopyLasso windows after every ordinary completion or cancellation.
- The final unit pipelines passed 106 tests on both `arm64` and `x86_64`; Release contained `arm64` and `x86_64` and no Debug G13 controls.

The temporary Sidecar display was not physically available for a fresh G13 run. The exact G07 Sidecar evidence remains in ADR-003, pure tests cover the 2× negative-origin shape and both cross-display clamps, and `testLiveSelectionCleansUpAfterCrossDisplayDrags` runs only when more than one real display is present. It was explicitly skipped in the one-display G13 environment and must be rerun during G19 rather than treated as passing evidence.

## Real Region Capture Matrix

Use a stably signed Debug build with Screen Recording enabled. Invoke the real adapter only with an ordinary app run or the explicit `--g14-live-capture` manual control; ordinary UI tests use an in-memory substitute.

1. Select a known high-contrast grid after placing it at recorded display coordinates. Confirm the returned image dimensions equal the outward-rounded backing-pixel rectangle and compare corner, border, and interior pixels.
2. Repeat at every physically available backing scale and with fractional selection edges. Confirm the service uses the selected display rather than the primary display.
3. Verify the captured image contains no border, dim treatment, or CopyLasso cursor. The production capture starts only after accessibility inspection reports no overlay windows.
4. Revoke access while running and confirm a real `SCStreamError.userDeclined` overrides stale preflight, presents likely-revoked recovery, skips OCR, and returns to idle.
5. Disconnect or reconfigure the selected display between selection and capture. Confirm display/scale/bounds validation fails safely and no image reaches OCR.
6. Repeat capture at least 20 times. Inspect the app container and temporary directories for image files and confirm the image is released after the OCR call.

### G14 Unattended Verification Record

Deterministic tests validate outward-rounded crop geometry, 1×/2× scale propagation, cursor/audio exclusion, current-display validation, exact in-memory pixel data and dimensions, nil/incorrect output, framework error mapping, capture-to-OCR forwarding, cancellation, and authoritative denial recovery. Both configurations compile the same production adapter; Debug UI runs substitute only the capture client to avoid touching real TCC.

A fresh successful live crop could not be performed unattended: the Debug Screen Recording toggle was off, and the workstation auto-locked after G13. Two signed XCUITest attempts failed before invoking the command because Xcode could not traverse a locked menu bar; `loginwindow` was frontmost. These attempts are recorded as unavailable infrastructure evidence, not product failures or passes. G06 remains the latest successful real ScreenCaptureKit pixel proof, and the G14 production matrix must be rerun after unlock before G18/G24 release evidence can pass.

## Production Vision OCR Matrix

G15 recognition is verified without changing Screen Recording permission. The unit bundle contains project-owned fixture images and invokes the same `VisionOCRService` used by Debug and Release.

The required automated matrix covers:

1. Exact normalized text for clean multiline, small, light-on-dark, and rasterized-application fixtures.
2. At least 90% character similarity, every expected token, and at most one unexpected token for the moderate-low-contrast fixture.
3. The exact required phrase, every expected token, and at most one unexpected token for the generated photographic sign.
4. Empty success for a blank image, distinct from a typed engine failure.
5. Recognition of a deliberately enlarged 2400 x 1000 fixture.
6. Confidence within 0...1 and normalized bounds for every returned observation.
7. An injected performer proving execution occurs off the main thread.
8. Cancellation before and after Vision request installation, exactly-once `VNRequest.cancel()`, typed cancellation, return within one second, and release of a 4000 x 2000 input image.
9. Static confinement of Vision to the production OCR service and absence of logging, image encoding, persistence, pasteboard, or network code in that service.

The direct off-main thread assertion is deterministic and runs in both canonical architecture jobs; it replaces a subjective Instruments-only judgment for this boundary. Instruments remains useful during G24 performance QA, where the entire live workflow can be profiled after the outstanding real-capture matrix is available.

### G15 Production Verification Record

On July 11, 2026, both canonical pipelines passed 129 of 129 tests with zero failures or skips on arm64 and x86_64. The focused production OCR suite passed 13 of 13 tests, including every fixture threshold, the enlarged fixture, typed empty/failure behavior, off-main execution, cancellation, and image release. The same built OCR suite passed 13 of 13 under a process sandbox that denied every network operation. Both Release slices contain the production service, while CI confines Vision to that file and rejects OCR logging or captured-image persistence paths.

## Plain-Text Assembly Matrix

G16 formatting tests use only neutral observations and do not execute Vision or screen capture. They cover empty and whitespace-only input, unordered words, multiple lines, uneven baselines, separated blocks, exact duplicates, repeated text in distinct positions, low-confidence text, twenty high-confidence observations, literal markup-like characters, malformed geometry, project fixture layouts, and unsupported multi-column input in several permutations.

The required policy is conservative: only exact same-text/same-bounds detections are deduplicated, while every other nonempty observation remains in output regardless of confidence. Multi-column, table, vertical, and complex layouts may read imperfectly but must produce the same string for the same observation set and must never crash. See [Plain-Text Assembly](architecture/text-assembly.md) for the complete rules.

## Clipboard and Feedback Matrix

G17 unit coverage uses an isolated AppKit pasteboard plus a fault-injecting backend. It verifies one plain-string item and one change-count increment on success, rejection of empty text before pasteboard access, explicit prepared-write failure, no prior-pasteboard read in production source, and no rich-text representation. Workflow tests verify success writes once, no text never writes, clipboard failure never records a successful write, bounded preview derivation, feedback-failure recovery, repeated use, and busy rejection until HUD dismissal.

The app-hosted feedback suite orders the production panel front while another process is frontmost. It verifies that the panel is visible, borderless, nonactivating, unable to become key or main, mouse-transparent, status-bar level, compatible with Spaces/full-screen apps, and removed after dismissal without changing the frontmost process. Model tests verify distinct success/no-text/failure wording, 80-character grapheme-safe truncation, automatic preview release, singleton host reuse, and stale-timer protection.

### Signed G17 Manual Matrix

This live matrix requires an unlocked graphical session and granted Screen Recording access:

1. Put a unique value on the clipboard, invoke Capture Text, and cancel with Escape. Paste into TextEdit and confirm the unique value remains.
2. Select a known paragraph, wait for the success HUD to disappear, and paste into both TextEdit and a browser text field. Confirm plain text, sensible line breaks, and exactly one clipboard replacement.
3. Select a region with no visible text. Confirm the no-text HUD is distinct and the prior clipboard remains.
4. Keep Finder, TextEdit, and a full-screen application frontmost in separate runs. Confirm the HUD appears without activation, key-window change, sound, notification request, or menu opening.
5. Confirm the menu symbol changes only for the HUD lifetime, the preview is readable with VoiceOver, long text is truncated with one ellipsis, and no preview remains after dismissal.
6. Repeat success, no-text, and cancellation three times each and confirm Capture Text returns to enabled after every result.

On the unattended July 11, 2026 run, the workstation was locked and no interactive user session was available. The deterministic app-hosted focus/panel checks ran, but the two-application paste and VoiceOver portions remain mandatory live evidence before release.
