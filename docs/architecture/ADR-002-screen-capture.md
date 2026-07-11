# ADR-002: ScreenCaptureKit Is Viable for v0.1

- **Status:** Accepted
- **Date:** July 10, 2026
- **Scope:** G06 feasibility evidence, G12 production permission handling, and the G14 production capture boundary

## Context

CopyLasso must capture arbitrary user-selected screen pixels without Accessibility or Input Monitoring permission, without retaining images, and without forcing a system picker into every capture. G06 tests whether the macOS 14 ScreenCaptureKit surface can support that contract and records the permission behavior actually exposed by current macOS.

The public Core Graphics permission functions return only a Boolean. They do not distinguish never requested, denied, pending restart, or revoked access. The experiment therefore separates directly observed state from limited inferences based on CopyLasso's own request history.

## Decision

ScreenCaptureKit is viable for CopyLasso v0.1. The internal experiment:

- obtains `SCShareableContent.current` only after a user-initiated request;
- chooses the `SCDisplay` matching `CGMainDisplayID()`;
- constructs a display `SCContentFilter` without excluding applications or windows;
- captures a centered, clamped 640 × 360-point region with the macOS 14 [`SCScreenshotManager.captureImage`](https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager/captureimage%28contentfilter%3Aconfiguration%3A%29) API;
- converts logical point dimensions to output pixels using `SCShareableContent.info(for:)` and `pointPixelScale`;
- disables cursor and audio capture; and
- retains only the returned `CGImage` in the Debug view model.

The experiment uses [`CGPreflightScreenCaptureAccess()`](https://developer.apple.com/documentation/coregraphics/cgpreflightscreencaptureaccess%28%29) and [`CGRequestScreenCaptureAccess()`](https://developer.apple.com/documentation/coregraphics/cgrequestscreencaptureaccess%28%29), plus two preferences recording whether this CopyLasso preferences history has requested or previously observed access. Its labels intentionally say "after a prior request" and "may have been revoked" rather than claiming an unavailable macOS state.

An actual ScreenCaptureKit permission-denied error is authoritative. It overrides a stale positive preflight result and produces the likely-revoked observation.

G12 implements the production permission portion with the same deliberately limited semantics. A `SystemScreenCapturePermissionService` performs Core Graphics preflight only after a user invokes Capture Text, records request history before calling the system request, and records previously observed access only after a direct positive result. A singleton nonactivating recovery panel explains the manual path without claiming macOS can distinguish denial from pending approval. It never retries automatically after System Settings changes.

The approved production split is explicit: G12 detects revocation once Core Graphics preflight reflects it. The same-process stale-positive case observed below remains G14's responsibility, because only the real ScreenCaptureKit attempt can authoritatively report that access is unavailable while preflight still says granted.

CopyLasso will not use `SCContentSharingPicker` because a case-by-case picker cannot preserve the shortcut-to-arbitrary-region workflow. It will not request the managed persistent-content-capture entitlement, which Apple documents for screen-sharing products, and it will not fall back to deprecated Core Graphics screenshot APIs. Apple Developer Technical Support identifies the picker and managed entitlement as the two ways to avoid the direct-capture warning. Neither is appropriate for CopyLasso. See Apple's [ScreenCaptureKit warning discussion](https://developer.apple.com/forums/thread/765103).

## Permission Evidence

The following matrix was observed with the same stably signed Debug application on macOS 26.5.1 (`25F80`), Xcode 26.6 (`17F113`), and an Apple M5 Pro:

| State or action | Observed behavior |
| --- | --- |
| Fresh `tccutil` reset and fresh local history | Preflight reported not granted; launching the harness caused no prompt and did not enumerate capture content. |
| First user-initiated request | macOS said CopyLasso wanted to record the screen and audio and offered **Open System Settings** or **Deny**. |
| Deny | The harness reported not granted after a prior request, returned a controlled error, retained no image, and did not crash. A second request produced no repeated system prompt. |
| Manual approval | Enabling CopyLasso in **Screen & System Audio Recording** produced a **Quit & Reopen** or **Later** choice. Access remained unavailable after choosing Later. Quit and relaunch were required before preflight became granted. |
| First direct capture | macOS warned that CopyLasso was bypassing the private window picker and offered **Allow** or **Open System Settings**. This macOS release did not show "Allow for one month." Choosing Allow produced a nonblank 640 × 360-pixel image on the tested main display. |
| Bypass-warning timing | After revocation, reapproval, and a fresh signed build at a different DerivedData path, the bypass warning appeared again. ScreenCaptureKit returned the requested preview before the warning was dismissed, so this macOS warning is not necessarily a gate on image delivery. |
| Repeated capture | Three ordinary captures succeeded without another warning. After dismissing the later recovery warning, another ordinary capture also succeeded without a warning. No separate persistent menu-bar recording indicator was observed; the consent alert itself displayed a red recording badge. |
| Revocation while running | Disabling CopyLasso produced a system message claiming the app could continue until quit. In practice, the next ScreenCaptureKit capture failed immediately while Core Graphics preflight remained stale and reported granted. The harness treats the real capture denial as authoritative. |
| Relaunch after revocation | Preflight became not granted and, because access had previously been observed, the harness reported that access may have been revoked. |

The current warning is acceptable because it is tied to a user-initiated setup or recovery capture and did not recur on ordinary captures. It may recur after permission revocation and reapproval, even when the signing requirement is unchanged, so production UX must not describe it as strictly once-only. A warning that must be dismissed for each ordinary capture remains a product blocker.

The Debug bundle's scoped reset command is:

```sh
/usr/bin/tccutil reset ScreenCapture io.github.bennetthilberg.copylasso.debug
```

Apple documents manual permission management in [Control access to screen and system audio recording on Mac](https://support.apple.com/guide/mac-help/control-access-screen-system-audio-recording-mchld6aa7d23/mac).

## G12 Production Permission Evidence

The production Core Graphics lifecycle was verified July 10, 2026 with the same macOS 26.5.1 (`25F80`), Xcode 26.6 (`17F113`), and stable Apple Development signing requirement used for the feasibility work:

| State or action | Production result |
| --- | --- |
| Ordinary dockless launch | No Screen Recording check, system prompt, or CopyLasso recovery panel appeared. |
| First shortcut request and Deny | macOS presented its Screen Recording dialog. After **Deny**, CopyLasso presented one nonactivating recovery panel and did not enter selection. |
| Repeated denied attempts | Three shortcut attempts reused the same panel without another system request or inconsistent busy state. |
| Open System Settings | The explicit action intentionally changed focus and opened Screen & System Audio Recording directly. |
| Enable and choose Later | CopyLasso did not retry automatically. An explicit retry remained unavailable and explained that choosing **Later** requires quitting and reopening. |
| Relaunch after approval | The designated signing requirement was unchanged. Three shortcut attempts reached the temporary G13 selection boundary, returned to idle, and produced no overlay, pixels, OCR, clipboard mutation, or visible feedback. |
| Revoke and relaunch | Preflight reflected the revocation and the panel said access was previously available and may have been turned off. **Try Again** updated the same panel with explicit relaunch guidance. |
| Full-screen focus | The panel appeared in a full-screen TextEdit Space while CopyLasso remained non-frontmost according to Launch Services. |

No ScreenCaptureKit enumeration or capture call occurred, so the private-window-picker-bypass warning did not appear. Source and binary guards also confirmed that G12 added no Accessibility, Input Monitoring, Microphone, Vision, pasteboard, or pixel path.

## Privacy and Sandbox Results

- App Sandbox and Hardened Runtime remained enabled in the signed experiment.
- The capture configuration explicitly disabled audio and cursor capture and did not access the microphone.
- No Accessibility, Input Monitoring, Microphone, or Full Disk Access API, entitlement, or prompt was introduced.
- Source inspection found no image encoding, file-write, temporary-file, network, or pixel-logging path.
- Before/after inspection of the Debug app container found zero screenshot-format files after successful and failed captures.
- Manual Clear Preview verification returned the harness to "No image is retained." Clearing the preview or terminating the app releases the only retained `CGImage`.
- The Debug application had the same designated signing requirement across two clean builds. The team identifier remains only in ignored `Local.xcconfig` and was not logged or committed.

## G14 Production Capture Adoption

G14 implements `SystemScreenCaptureService` as an actor-isolated `ScreenCaptureService`. A valid selection now carries its `NSScreen` backing scale plus an outward-rounded, display-local backing-pixel rectangle. The request planner verifies that the pixel rectangle is consistent with the local Core Graphics rectangle, aligns the source rectangle to backing-pixel edges, and disables cursor and audio capture.

Only after the G13 completion callback has ordered out and released every overlay does the live client:

1. enumerate `SCShareableContent.current`;
2. match the stable selected `CGDirectDisplayID`;
3. build a display filter without excluding applications or windows;
4. revalidate current point dimensions and `pointPixelScale` against the selection;
5. configure the aligned source rectangle and exact output pixel dimensions; and
6. call `SCScreenshotManager.captureImage`.

The service rejects missing or reconfigured displays, nil output, and unexpected image dimensions. `SCStreamError.userDeclined` maps to authoritative permission denial; the permission history records previously observed access, an in-process denial flag prevents ordinary requests from trusting stale preflight, and the existing singleton recovery panel is presented. Only an explicit **Try Again** clears that process-local flag for one new attempt; if access remains ineffective, the next real ScreenCaptureKit denial reinstates it. No raw framework error, pixel content, or application identity enters coordinator state or logs. The returned `CGImage` is forwarded directly to the G15 Vision service and released after recognition or cancellation.

Automated tests use an injectable capture client to compare exact in-memory pixel bytes, inspect every request field, inject nil and wrong-sized images, and cover typed framework errors without touching TCC. The final successful live pixel proof remains the G06 run above. A fresh G14 production success run was unavailable because Screen Recording was disabled and the unattended workstation had auto-locked; locked signed UI attempts could not traverse the menu bar. This is not counted as passing evidence and must be rerun after unlock before end-to-end qualification.

## Coordinate Assumptions

`SCStreamConfiguration.sourceRect` is expressed in the selected display's logical coordinate system. The spike operates only within one display, uses local display dimensions, and scales the output with `pointPixelScale`. It does not establish global-to-display conversion, multi-display selection, or overlay placement; those remain G07 responsibilities.

## Limitations and Consequences

- The live permission matrix covers the maintainer's current Apple Silicon macOS 26 workstation. macOS 14 compatibility is established by the deployment target and macOS 14 API surface; clean older-system VM behavior remains a later release check.
- Protected or DRM-controlled content may legitimately capture as blank and is outside the arbitrary-allowed-pixels guarantee.
- The private-window-picker warning wording and duration are controlled by macOS and may change. Production UI must present recovery guidance without promising a distinction or restart behavior the API cannot prove.
- G07 established overlay and coordinate-conversion feasibility. G08 retired the executable harness while preserving its contracts. G12 owns the Core Graphics lifecycle and recovery UI; G13 owns overlay cleanup and display-local geometry; G14 owns authoritative ScreenCaptureKit denial and in-memory pixel capture.
