# Testing CopyLasso

CopyLasso's canonical unsigned build and unit-test pipeline is:

```sh
./scripts/ci.sh
```

The pipeline lints all Swift source, resolves the exact package dependency, builds Debug and both XCTest bundles, runs the unit suite serially with timeouts, inspects required build and privacy boundaries, builds Universal 2 Release, and verifies both executable slices. It does not launch the unsigned UI-test runner or alter macOS privacy state.

## Controlled Permission And Selection UI Coverage

Signed UI tests use Debug-only permission doubles. They cover prior-request and previously-granted recovery wording, singleton reuse, System Settings failure instructions, retry routing, Cancel, menu availability, keyboard actions, and accessibility identifiers without calling Core Graphics permission functions or changing real TCC state.

Ordinary signed UI tests use deterministic Debug-only selection and capture doubles so shell tests never unexpectedly cover the desktop or touch TCC. Tests launched with `--g13-live-selection` use the production AppKit service with controlled permission and in-memory capture. They verify that the overlay is accessible, cancellation removes it, a valid drag reaches the deterministic downstream workflow and no-text feedback, the command becomes reusable, and the clipboard remains unchanged.

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
5. After any required relaunch, invoke Capture Text. Confirm authorization presents the production selection overlay and temporarily activates CopyLasso. Cancel with Escape and verify the overlay disappears, the previously frontmost application is restored before completion, the clipboard is unchanged, and the command returns to idle.
6. Disable CopyLasso in Screen & System Audio Recording and relaunch it. Invoke Capture Text and confirm the recovery copy says access was previously available and may have been turned off; it must not claim definitive revocation.
7. Repeat recovery while an ordinary full-screen application is frontmost. Confirm presenting or updating CopyLasso's nonactivating panel does not change the frontmost application. Only **Open System Settings** intentionally changes focus.
8. Confirm macOS did not show the ScreenCaptureKit private-window-picker-bypass warning and that no Accessibility, Input Monitoring, Microphone, or clipboard access was introduced.

Core Graphics preflight may remain positive inside a process after permission is disabled. G12 records revocation once preflight reflects it, normally after relaunch. The G14 capture path treats an actual ScreenCaptureKit denial as authoritative when preflight is stale. Ordinary capture requests retain that denial; an explicit **Try Again** permits one fresh preflight observation. The denial remains authoritative after cancellation, a too-small selection, or capture failure and clears only after a successful ScreenCaptureKit capture.

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

1. On the primary display, invoke Capture Text from both the menu and shortcut. Verify CopyLasso temporarily becomes active, the normal-sized system crosshair replaces the pointer before mouse-down and remains throughout the drag, no second pointer is drawn, and only the area outside the active rectangle dims after dragging begins.
2. Exercise forward and reverse drags, a click, a sub-four-point drag, exactly four points, Escape before dragging, Escape during dragging, and every display-edge clamp.
3. Connect an extended display and repeat a selection there, including invoking while the pointer is on one display and starting the drag on the other. Press Escape during that drag and confirm the clicked display receives it immediately. Record fresh display identifiers, AppKit frames, Core Graphics bounds, and backing scales; never hardcode runtime identifiers.
4. Drag from each display toward the other. The rectangle must stop at the initiating display edge, and only that display may dim.
5. Repeat menu and shortcut selection at least 20 times across valid, click, and Escape outcomes. Every outcome must remove all panels, restore the cursor, leave the command reusable, and leave the clipboard unchanged.
6. Repeat with Finder, a browser, TextEdit, another Space, and a full-screen Space frontmost. CopyLasso may become active only while selection is visible; every success, click, Escape, and failure must restore the originating app before downstream capture or feedback and must not switch Spaces.
7. Change a display resolution or disconnect an extended display during selection. The active operation must cancel once, remove all panels, and rebuild fresh descriptors on the next request.
8. Terminate CopyLasso during selection and verify no panel, dim, cursor override, observer, controller, or continuation remains. Use Xcode's memory graph or debugger to confirm the completed controller and surfaces are released.
9. Inspect light, dark, increased-contrast, Reduce Motion, and VoiceOver behavior. The thin gray dashed outline must retain its subtle two-point radius, the outline and crosshair must remain distinguishable, the dashes must move steadily unless Reduce Motion is enabled, and the overlay must expose its selection label and Escape help.
10. Confirm no pixel file, retained image, pasteboard write, Accessibility prompt, or Input Monitoring prompt occurs. The controlled blank-image path should now produce distinct no-text feedback while preserving the clipboard; real successful clipboard output belongs to the separate G17 matrix below.

The crosshair check begins with a stationary pointer before pressing the mouse
button and continues through the drag. Exactly one normal-sized AppKit
crosshair must replace the pointer; an ordinary arrow or a second app-drawn
reticle is a failure. Automated tests prove selection-only activation is
confirmed by AppKit before overlay presentation and that the pointer's exact
panel becomes key before its active full-window crosshair cursor rectangle is
refreshed. The global native crosshair is applied one main-actor turn after that
refresh. Delayed activation or key confirmation leaves the cursor untouched,
cancellation invalidates late confirmation or a scheduled push, and restoration
occurs before deferred completion.
WindowServer composition and real frontmost-application restoration still
require this signed manual observation.

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

A fresh successful live crop could not be performed unattended: the Debug Screen Recording toggle was off, and the workstation auto-locked after G13. Two signed XCUITest attempts failed before invoking the command because Xcode could not traverse a locked menu bar; `loginwindow` was frontmost. These attempts are recorded as unavailable infrastructure evidence, not product failures or passes. G06 remains the latest successful real ScreenCaptureKit pixel proof, and the G14 production matrix must be rerun after unlock before G18 live acceptance and G24 release evidence can pass.

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

G17 unit coverage uses an isolated AppKit pasteboard plus a fault-injecting backend. It verifies one plain-string item and one change-count increment on success, rejection of empty text before pasteboard access, explicit prepared-write failure, no prior-pasteboard read in production source, and no rich-text representation. Source inspection verifies that the production backend prepares the local string item before the destructive clear. Workflow tests verify success writes once, no text never writes, clipboard failure never records a successful write, bounded preview derivation, feedback-failure recovery, busy rejection during permission/selection/capture/OCR, and ten immediate capture cycles while each prior HUD remains visible. The coordinator is idle after synchronous presentation; panel-generation checks prove an older dismissal timer cannot hide newer feedback.

The preservation guarantee covers every cancellation and failure before clipboard replacement begins. AppKit has no atomic general-pasteboard replacement: if its required clear succeeds and `writeObjects` then rejects the prepared item, the prior clipboard may already be lost. CopyLasso reports that rare clipboard-stage failure and deliberately does not read or retain prior clipboard data to attempt a best-effort rollback.

The app-hosted feedback suite orders the production panel front while another process is frontmost. It verifies that the panel is visible, borderless, nonactivating, unable to become key or main, mouse-transparent, status-bar level, compatible with Spaces/full-screen apps, and removed after dismissal without changing the frontmost process. Model tests verify distinct success/no-text/failure wording, 80-character grapheme-safe truncation, automatic preview release, singleton host reuse, stale-timer protection, and synchronous interruption of every feedback kind.

### Signed G17 Manual Matrix

This live matrix requires an unlocked graphical session and granted Screen Recording access:

1. Put a unique value on the clipboard, invoke Capture Text, and cancel with Escape. Paste into TextEdit and confirm the unique value remains.
2. Select a known paragraph, wait for the success HUD to disappear, and paste into both TextEdit and a browser text field. Confirm plain text, sensible line breaks, and exactly one clipboard replacement.
3. Select a region with no visible text. Confirm the no-text HUD is distinct and the prior clipboard remains.
4. Keep Finder, TextEdit, and a full-screen application frontmost in separate runs. Confirm the HUD appears without activation, key-window change, sound, notification request, or menu opening.
5. Confirm the menu symbol changes only for the HUD lifetime, the preview is readable with VoiceOver, long text is truncated with one ellipsis, and no preview remains after dismissal.
6. During each success, no-text, and failure HUD, invoke Capture Text again. Confirm the HUD closes
   immediately, one fresh crosshair appears, and no stale panel or overlapping selection remains.
7. Repeat success, no-text, and cancellation three times each and confirm Capture Text returns to enabled after every result.

On the unattended July 11, 2026 run, the workstation was locked and no interactive user session was available. The deterministic app-hosted focus/panel checks ran, but the two-application paste and VoiceOver portions remain mandatory live evidence before release.

## End-To-End Capture Workflow Matrix

The G18 integration suite injects permission, selection, capture, OCR, assembly, clipboard, feedback, and scheduling boundaries around the same `CaptureCommand` owned by the production app. It verifies:

- 25 consecutive successful operations with exact per-service call counts, writes, feedback, reuse, and idle recovery;
- 20 alternating success and Escape-cancellation operations, with downstream calls and clipboard writes only on the ten successful attempts;
- selection, capture, recognition, clipboard, and feedback failures, plus unavailable permission and authoritative capture-time denial;
- every selection cancellation reason and Vision cancellation as non-error, feedback-free outcomes;
- busy rejection while selection, recognition failure feedback, or success feedback remains outstanding;
- image release before both held success and held recognition-failure HUD presentations;
- bounded success copy that cannot expose an unbounded private suffix; and
- the menu and simulated package shortcut event reaching the exact same command instance.

### Signed G18 Manual Matrix

Use one stably signed Debug app with Screen Recording enabled. Keep a unique sentinel on the clipboard before each cancellation or pre-output failure check.

1. Invoke Capture Text from the configured shortcut with Finder, TextEdit, a browser, an image viewer, a playing local video, and the desktop wallpaper frontmost. Select ordinary approximately horizontal English text, verify the success HUD, and paste the result into TextEdit and a browser field.
2. Repeat one success through the menu. Confirm its overlay, OCR, output, HUD, focus, and idle recovery match the shortcut path.
3. Repeat in an ordinary full-screen application and after switching normal Spaces. The overlay must appear in the intended Space without activating CopyLasso or moving the user elsewhere.
4. Press the shortcut repeatedly while one selection is active and while one HUD is visible. Confirm only one overlay, OCR job, clipboard write, and feedback presentation occur.
5. Cancel with Escape and with a too-small drag. Confirm the sentinel clipboard value remains, no failure HUD appears, every panel disappears, and the next capture begins immediately.
6. Select a region without visible text. Confirm distinct no-text feedback, no pasteboard write, and immediate reuse after dismissal.
7. Exercise permission, display-change, capture, recognition, clipboard, and feedback failure paths where safely injectable. Confirm one bounded recovery/failure presentation, no raw platform error or content, complete cleanup, and idle recovery.
8. Complete 25 consecutive real successes, then 20 real attempts alternating success and Escape. Confirm no duplicate panels, stuck cursor, overlapping work, retained preview, unexpected permission, or responsiveness loss.
9. Inspect the app container and temporary directories before and after the run. Confirm no screenshot, OCR text, preview, log, cache, or history artifact was created.

The unattended July 11, 2026 run completed the deterministic matrix but could not perform this signed live matrix because the workstation was locked and real G14 capture permission/display evidence was unavailable. This is recorded as pending rather than passed; it remains release-blocking evidence for G24.

## Multi-Display And Retina Hardening Matrix

G19 adds a synthetic topology with primary, left, right, above, below, diagonal, portrait, and recorded Sidecar-style shapes across 1×, 1.5×, and 2× scales. For every fixture, tests drive global selection through display-local Core Graphics conversion and capture-request planning, preserve the initiating display identity, clamp every cross-display endpoint, validate outward-rounded pixels, and reject changed identity, full point size, scale, or derived pixel dimensions. A fractional-scale edge regression also proves the aligned source rectangle stays within the right and bottom display bounds while retaining the outward-rounded output pixels. AppKit tests prove every mixed-scale display can initiate through a panel covering its complete `NSScreen.frame`.

The synthetic matrix is deterministic regression protection; it is not evidence that unavailable physical hardware or a particular menu-bar arrangement worked.

### Signed G19 Physical Matrix

1. Record every connected display's current name, runtime ID, AppKit frame, Core Graphics bounds, backing scale, resolution, refresh rate, orientation, primary-menu-bar ownership, and the **Displays have separate Spaces** setting.
2. On every display, capture a known corner-and-center calibration grid. Confirm the pixels, output size, and display identity match that display at its current scale.
3. Select near the menu bar, any secondary menu bar, Dock edge, and each outer screen edge. The overlay must cover the complete display frame and the crop must exclude the overlay itself.
4. Drag from each display toward every adjacent display. Only the initiating display may dim, the rectangle must stop at its edge, and no stitched or wrong-display image may result.
5. Exercise every physically available left, right, above, below, diagonal, landscape, and portrait arrangement. Record unavailable arrangements explicitly rather than extrapolating.
6. Exercise every available mixed-scale pair, including 1× plus 2× and any supported 1.5× mode. Verify outward-rounded dimensions and intended pixels on both sides.
7. Change one supported resolution or scaling mode while selection is active. Confirm one display-change cancellation, complete overlay cleanup, idle recovery, and fresh descriptors on the next request.
8. Reconfigure or disconnect the initiating display between selection and capture where a controlled pause makes that safe. Confirm capture rejects the stale identity/point-size/scale snapshot and the clipboard remains unchanged.
9. Restore the original arrangement, resolution, scale, orientation, refresh rate, menu-bar assignment, and Sidecar state before finishing.

The July 11, 2026 unattended G19 run could not execute this physical matrix because the session was locked and the Sidecar iPad was unavailable. A fresh read-only enumeration saw one online primary Dell S2721HGF at 1920 × 1080 and 144 Hz: runtime ID `4`, matching AppKit/Core Graphics frames `(0, 0, 1920, 1080)`, and 1× scale. That confirms the test environment only; it is not selection or pixel-crop evidence. G07's Dell/Sidecar results remain historical evidence. Fresh physical G19 results are pending release qualification.

## Lifecycle, Reentrancy, And Recovery Matrix

G20 unit coverage posts every registered application/workspace notification through isolated centers and injects cancellable selection, capture, OCR, and feedback gates. It verifies duplicate interruption coalescing, resume without automatic capture, observer teardown, recovery-panel dismissal, shortcut shutdown on termination, cancellation before scheduled work, 100 rapid busy requests, downstream call suppression, terminal reset, and a successful capture immediately after cancellation. The centralized stage-only failure copy remains covered separately for every failure stage.

G24U adds direct selection-adapter coverage for public workspace will-sleep,
screen-sleep, and session-resign notifications. Focused tests interrupt before
activation and after cursor refresh, deliver duplicates, replay stale overlay
events, verify exactly-once cleanup and clipboard/downstream suppression, and
start a second selection. Selector-conformance tests require one
`Notification` argument. These deterministic checks still do not establish
that an ordinary screen lock emits a workspace session-switch notification;
lock/unlock remains a distinct signed row below.

### Signed G20 Manual Matrix

Use one stably signed Debug app and keep a clipboard sentinel before every pre-output interruption:

1. While idle, sleep/wake and lock/unlock. Confirm no overlay, permission panel, HUD, clipboard change, or automatic capture appears after resume; the next shortcut request works.
2. Begin selection, then sleep before mouse-up. Wake and confirm no dim, border, cursor override, key overlay window, or stuck busy state remains. Repeat with lock/unlock.
3. Interrupt while ScreenCaptureKit capture is active using a deliberately large region, then while Vision recognizes a large fixture. Confirm no downstream clipboard write or generic failure HUD and immediate reuse after resume.
4. Interrupt while success/no-text feedback is visible. Confirm the HUD disappears. If success already wrote the clipboard, retain that completed output; CopyLasso must not read the pasteboard to roll it back.
5. Press the global shortcut rapidly at least 100 times while one selection is active. Confirm exactly one overlay and one eventual OCR job.
6. Activate/deactivate CopyLasso Settings and About while another app remains frontmost. Ordinary app activation changes must not cancel or auto-start capture.
7. Choose Quit while selection is active. Confirm the overlay and cursor disappear, shortcut delivery stops, CopyLasso terminates, and no process/window remains.
8. Repeat selection cancellation, recoverable capture failure, and successful capture in sequence at least ten times without force-quitting.
9. Inspect Console lifecycle messages. They may state only idle interruption, active interruption cancellation, resume, or termination cleanup; they must contain no captured/frontmost app name, geometry, pixels, recognized text, clipboard text, preview, or raw error.

The unattended July 11, 2026 run could not perform real sleep/wake, lock/unlock, WindowServer inspection, or quit-during-selection because the workstation was already locked. Deterministic notification/task tests are not a substitute; this signed matrix remains pending release evidence.

## Accessibility And Appearance Checklist

G21 unit coverage reads every supported `NSWorkspace` accessibility-display flag, verifies standard and Increased Contrast overlay styles, proves the HUD uses regular material normally and an opaque semantic background under Reduce Transparency even when its host is reused, prohibits app-defined feedback/recovery animation, proves a real hosted HUD expands for wrapped text, and retains textual states for success, no text, failure, login status, and permission recovery. Signed UI tests retain light/dark launches and add named compound-control plus keyboard default/close actions.

Run this checklist with one stably signed Debug app and a normal unlocked graphical session:

1. Enable Full Keyboard Access. Launch fresh onboarding and traverse every control using only Tab, Shift-Tab, Space, Return, arrow keys where native, and Command-W. Record, replace, and clear the shortcut; toggle Launch at Login; complete setup; then reopen Settings with Command-,.
2. In Settings, traverse Finish Setup when present, the shortcut recorder, Use Suggested Shortcut, Launch at Login, every recovery action/status, repository/privacy/license links, the development reset confirmation in Debug, and window closure. Confirm visible focus never disappears and every action remains reachable without a mouse.
3. With VoiceOver, inspect the menu-bar item and menu order/state; onboarding privacy explanation and shortcut/login controls; every Settings name, value, status, issue, and link; About name/version/status; and permission recovery title, neutral status, instructions, retry update, and three buttons.
4. Trigger success, no-text, and each failure class. Confirm VoiceOver announces one bounded feedback element and the changing menu-bar state without moving focus. Confirm no feedback preview remains in app state after dismissal.
5. Start selection. Confirm Accessibility Inspector reports one overlay group per display with the label `CopyLasso text selection overlay` and help `Drag to select text. Press Escape to cancel.` The visual drag itself is intentionally not replaced by a VoiceOver-driven workflow in v0.1.
6. Test Light and Dark appearances. Inspect the template menu symbol, native forms, links, text, permission panel, success/no-text/failure HUD, clear pre-drag overlay, dim treatment, single thin gray dashed outline with a subtle two-point radius, and crosshair on bright and dark content. Confirm the dash phase moves steadily around the rectangle without pulsing, easing, or lagging behind drag geometry.
7. Enable Increased Contrast. Confirm the initiating-display dim strengthens from 18% to 28% and the single gray outline strengthens from 1 to 1.5 points without restoring stacked strokes; unrelated displays stay clear. Repeat with Differentiate Without Color and verify every state remains named and symbol/text differentiated without hue.
8. Enable Reduce Transparency and confirm every newly presented or reused feedback HUD replaces its material with an opaque semantic window background while retaining readable text and borders. Inspect the remaining native materials and window backgrounds; no essential copy may become unreadable. Enable Reduce Motion and confirm the gray selection outline remains dashed but its phase is static, while selection, recovery, and feedback panels still present and disappear without app-defined window animation.
9. Increase the system text size to its largest supported value. Confirm onboarding, Settings, About, permission guidance, login errors, and the longest bounded feedback preview wrap or grow without clipped labels or inaccessible controls.
10. Repeat keyboard and VoiceOver checks after closing/reopening each singleton window and while another application or full-screen Space is frontmost. Explicit Settings/About actions may activate their windows; capture feedback and selection must preserve the other application's focus policy.

The unattended July 11, 2026 implementation run could not launch this physical matrix because the workstation remained locked. The signed app and UI runner built and launched, but the two focused XCUITests failed only while discovering onboarding and Settings hierarchy: `loginwindow` was the frontmost process, the accessibility shield hid both windows, and neither test reached its semantic or keyboard assertion. Strict signature verification and the generated `LSUIElement = true` check passed. The July 14 final-clean G24 continuation subsequently passed Light/Dark, Increased Contrast, Reduce Motion, Differentiate Without Color, Reduce Transparency, maximum text size, Full Keyboard Access, and complete VoiceOver coverage for the status item, menu, Settings, About, onboarding, selection overlay, success HUD, and permission recovery. The authoritative signed details are in [Manual QA and Performance](manual-qa-and-performance.md).

## Privacy, Security, Entitlement, And Dependency Matrix

The canonical pipeline runs `scripts/audit-privacy-security.sh` before every build. After the ordinary unit pass, it invokes the same complete built bundle through `scripts/test-offline.sh`, which applies a child-process sandbox containing `(deny network*)`. Both architecture jobs therefore verify the source audit and all unit behavior without network access.

G22 local evidence includes:

- 187/187 unit tests passing under the network-denied process sandbox, including real Vision fixtures and complete injected workflow coverage;
- a tracked entitlement containing only App Sandbox and two locally signed products containing App Sandbox plus development-provisioning `get-task-allow`, with no network-client/server entitlement;
- Hardened Runtime's CodeDirectory runtime flag on signed Debug and Release products;
- one exact KeyboardShortcuts 3.0.1 package at revision `49c3fc04ea827f816df67843bfcc57286b47ff06`, no transitive package, matching MIT license/notice, no known GitHub advisory at audit time, and no embedded third-party Release framework; and
- inspected Debug/Release containers containing only preference/window metadata, a small system crash-registration date, and zero-byte test coverage artifacts—not an image or recognized-text file.

### Signed G22 Manual Matrix

Use one stably signed Debug app, keep Screen Recording enabled, and avoid inspecting unrelated application containers:

1. Quit CopyLasso. Record a recursive path, size, modification-time, and file-type inventory of only its Debug container plus CopyLasso-named temporary entries. Preserve a unique clipboard sentinel.
2. Launch and complete ten real captures spanning success, no text, Escape, too-small selection, and one safely injected failure. Include long and sensitive-looking test strings, but no real secret.
3. Quit CopyLasso and repeat the same inventories. Any new file capable of containing pixels, recognized text, clipboard text, or a feedback preview is release-blocking. Ordinary preference/window metadata must match the retained-state inventory in the security review.
4. Search only changed/new CopyLasso files for the synthetic strings and inspect their types. Confirm no screenshot, image encoding, OCR history, preview cache, or content-bearing crash breadcrumb exists.
5. Inspect Console entries for the CopyLasso process across idle, selection, cancellation, sleep/lock recovery, success, no text, failure, and termination. Only the four fixed lifecycle messages may originate from CopyLasso; no app name being captured, geometry, pixels, recognized text, clipboard text, preview, or raw error may appear.
6. Run `scripts/test-offline.sh` against a freshly canonical-built bundle. Confirm 187/187 tests pass while the deny-network profile is active. Do not disable the workstation's network or interrupt other applications.
7. Inspect the signed app entitlement and CodeDirectory flags. Confirm App Sandbox and Hardened Runtime, no network client/server, no device/file/group/temporary exception, and only development `get-task-allow`. Repeat on the final Developer ID archive in G26 and require `get-task-allow` to be absent there.
8. Inspect the built Release executable and bundle. Confirm Universal 2, only system-linked frameworks, no embedded third-party dynamic binary, one exact package resolution, and the matching MIT acknowledgement.
9. Inspect Privacy & Security after real use. Screen Recording must be the only core permission; Accessibility, Input Monitoring, Microphone, Full Disk Access, Files and Folders, and automation access must not be required.
10. Paste the success result into TextEdit, then confirm cancellation/no-text/pre-output failures preserved the sentinel in separate runs. Remember that clipboard contents become a macOS/user trust boundary after a successful write.

The unattended July 11, 2026 G22 run completed the source, dependency, signed-entitlement, container baseline, and full offline-unit evidence. It could not create a fresh before/after delta across real captures, inspect live Console output, or recheck the privacy pane because `loginwindow` remained frontmost and the workstation was locked. Those observations remain pending release evidence rather than inferred passes.

## Automated Coverage, Repeatability, And OS Matrix

G23 keeps behavior—not a percentage—as the test contract, then uses coverage to detect unreviewed gaps and regressions. The canonical Xcode 26.6 result contains 214 unit tests organized across geometry, coordinator transitions, permission and settings decisions, text assembly, clipboard and interruptible-feedback decisions, lifecycle recovery, service-boundary orchestration, Vision fixtures, multi-display snapshots, accessibility/appearance policy, and selection-only activation/restoration behavior.

`scripts/audit-coverage.sh` reads the canonical `UnitTests.xcresult`. The reviewed stable baseline is 2,594/3,592 application lines (72.21%) after excluding three retained-state-dependent SwiftUI onboarding builders, and 986/1,030 platform-neutral Models/CaptureWorkflow/Settings lines (95.72%). The 70% aggregate floor is unchanged; every other application file remains included. Critical per-file floors prevent the aggregate from hiding a regression. See [Automated Coverage Review](coverage-review.md) for each floor, the G22 comparison, the reachable branches added in G23, and the explicit signed/manual owner for every uncovered category.

The canonical pipeline runs both gates. Re-run either check independently with:

```sh
./scripts/audit-coverage.sh .build/ci-$(uname -m)/UnitTests.xcresult
./scripts/test-repeatability.sh
```

After the ordinary and offline unit passes, canonical CI invokes the repeatability runner against the same DerivedData on both architectures. It executes the already-built unit bundle three consecutive times with parallel testing disabled, 60-second default/120-second maximum per-test allowances, and a separate result bundle per run. It never builds again or launches the UI-test bundle, has no retry path, and stops on any failure.

GitHub's current matrix has three responsibilities:

1. `build and test (arm64)` runs the complete compile/test/coverage/offline/repeatability/Release gate with Xcode 26.6 on macOS 26 arm64 and packages the exact Universal 2 Release artifact.
2. `build and test (x86_64)` runs the same compile/test/coverage/offline/repeatability/Release gate with Xcode 26.6 on a macOS 26 Intel runner.
3. `minimum OS runtime (macOS 14 arm64)` downloads the arm64 job's artifact onto an actual macOS 14 runner, verifies `LSMinimumSystemVersion` and Mach-O `minos` 14.0, ad-hoc signs the app with its reviewed sandbox entitlement, launches it directly, holds the process for two seconds, and terminates it. It does not request Screen Recording or claim real capture coverage.

The minimum runner is a runtime check because KeyboardShortcuts 3.0.1 requires Swift tools 6.2 and the macOS 14 hosted image offers Xcode 16.2 at most. Re-resolving or compiling that package there is unsupported and would not test the shipped artifact. GitHub has announced macOS 14 image removal on November 2, 2026; migrate this smoke to a maintained macOS 14 VM/runner before then.

Signed XCUITests remain focused on first-run, Settings, menu, recovery, and accessibility behavior. They contain no unconditional retry. Hosted CI builds the bundle but cannot truthfully execute the unsigned runner or automate TCC dialogs. A locked local session is recorded as infrastructure-blocked rather than a pass; the signed matrices earlier in this document remain required.

The versioned release checklist and performance result sheet are maintained in [Manual QA and Performance](manual-qa-and-performance.md). G24 must execute that complete document from one clean, stably signed Debug state; partial or historical evidence must not be promoted into a release pass.

The July 13, 2026 signed run completed many functional, permission, and OCR rows
before exposing a pre-drag sleep/wake failure. G24U subsequently passed exact
signed pre-drag and drag-phase sleep interruption with full cleanup, clipboard
preservation, no automatic resume, and immediate reuse. A separate screen-lock
probe exposed an invisible retained selection after unlock; the maintainer
accepted that lock-only behavior as a v0.1 residual.

The July 13-14 final clean merged-head rerun now passes three controlled 1x Dell
and three controlled 2x Sidecar captures, three physical cross-display clamps,
reverse and every-edge drags, pre-drag and drag-phase Escape, three click/tiny,
three blank no-text, and three active-selection Quit observations, the complete browser/Finder/TextEdit/PDF/raster/video/
photograph/system-UI/wallpaper/difficult-text/multi-column OCR-source sweep,
three passing protected-content blanking observations, Light/Dark and accessibility appearance modes, Full
Keyboard Access, three menu-fallback captures, exact normalized/truncated HUD
preview and timed clearing, complete VoiceOver coverage, three permission
approval/retry observations, idle CPU, and ordinary-region capture latency. Its official
100-cycle run recorded the first exact 50 successes and 50 cancellations while
one Allocations/VM Tracker/Time Profiler trace remained active; the post-settle
physical footprint fell to 60.7 MiB and `/usr/bin/leaks` reported zero leaks.
The growth row remains blocked because the protocol's distinct private-memory
value was not retained at each checkpoint.
Raw profiler and content-free timing evidence remains ignored under
`.build/g24-final-current`.

G24 is complete as an evidence-recording goal. Every manual row has an explicit
Pass, Fail, Blocked, or Not-applicable result, and the maintainer directed the
run to stop repeating low-value physical samples. Cold native-status-item
timing, one first-request Deny repeat, one permission-revocation repeat,
private-memory checkpoints, some active-phase lifecycle/busy-state cases,
reboot persistence, and the missing pre-run temporary-directory inventory
remain honest blocked evidence gaps rather than inferred passes. Clean install
and uninstall remain owned by their later roadmap goals. The applicable
lock-only failure and immediate-reuse stationary-crosshair nuance remain
maintainer-accepted v0.1 residuals.
