# ADR-003: AppKit Overlay and Per-Display Geometry Are Viable

- **Status:** Accepted
- **Date:** July 10, 2026
- **Scope:** G07 feasibility decision adopted by the production G13 selection service; region capture remains deferred to G14

## Context

CopyLasso must let a user begin a rectangular selection on any attached display without activating the app, dimming unrelated displays, or including the overlay in the later capture. AppKit and Core Graphics describe the same display with different origins and Y-axis conventions, and backing pixels may use a nonintegral scale. G07 tests the windowing and geometry assumptions before they become production architecture.

The original experiment was Debug-only and used `--g07-selection-spike`; G08 retired that executable harness while preserving its evidence and geometry. G13 now implements the same decision in the normal Debug and Release path. Construction and launch remain inert: panels are created only after an authorized user command reaches selection. The current workflow never captures pixels, calls Vision, writes the clipboard, or persists selection data.

## Decision

The AppKit approach is viable. CopyLasso will use one transparent, borderless `NSPanel` per `NSScreen` during selection. Each panel:

- uses [`.nonactivatingPanel`](https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel) so the user's frontmost application stays active;
- covers the complete `NSScreen.frame`, including menu-bar and Dock regions;
- uses `.canJoinAllSpaces`, `.fullScreenAuxiliary`, and `.ignoresCycle` [collection behaviors](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct);
- sits at screen-saver level and does not enter normal window cycling;
- is visually clear before mouse-down;
- displays a crosshair and, while dragging, dims only the initiating display outside the selection with 18% black; and
- draws a black-and-white selection border that remains visible over light and dark content.

The panel under the pointer becomes key and explicitly makes its overlay view first responder without activating CopyLasso. This gives Escape a deterministic path before or during a drag. A drag remains owned by its initiating display; moving the pointer onto another display clamps the endpoint to the initiating display edge. Unrelated display panels remain fully transparent.

The spike intentionally does not set `NSWindow.SharingType.none`. Apple now documents [`none`](https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum/none) as a legacy value that should not be used to hide a window from screen capture.

## Coordinate Conventions

`DisplayGeometry` stores the stable `CGDirectDisplayID`, the AppKit global frame, the matching `CGDisplayBounds`, and [`NSScreen.backingScaleFactor`](https://developer.apple.com/documentation/appkit/nsscreen/backingscalefactor). A result contains these representations:

| Representation | Origin and orientation |
| --- | --- |
| AppKit global | Bottom-left, in the virtual desktop |
| Display local | Bottom-left, relative to the initiating `NSScreen` |
| Core Graphics global | Top-left, offset by that display's `CGDisplayBounds` origin |
| Core Graphics display local | Top-left, relative to the initiating display |
| Backing pixels | Core Graphics display-local coordinates, outward rounded |

Conversion is per display rather than based on the primary display:

1. Clamp both endpoints to the initiating AppKit frame and normalize forward or reverse drags.
2. Subtract the AppKit frame origin to obtain the display-local bottom-left rectangle.
3. Flip local Y with `displayHeight - localRect.maxY`.
4. Add that display's Core Graphics bounds origin for the global top-left rectangle.
5. Multiply the local top-left rectangle by the backing scale, using `floor` for minimum edges and `ceil` for maximum edges so partially covered pixels are included.

The production display provider cross-checks the reported backing scale against `NSScreen.convertRectToBacking`. It reads `NSScreen.screens` fresh for every session, rejects missing or duplicate display identifiers and invalid geometry, and never caches a display layout. Unit tests cover 1×, 1.5×, and 2× scaling; negative origins; displays above, below, and beside the primary; all edge clamps; and the current Sidecar-style offset shape without embedding its runtime display identifier.

## Completion and Cancellation

A selection is valid only when both width and height are at least 4 points; exactly 4 points is accepted. A click or smaller drag is a normal `.tooSmall` cancellation. Escape, display reconfiguration, and application termination are also normal cancellation outcomes rather than application errors.

Every path completes at most once. On mouse-up or cancellation, the controller synchronously:

1. removes display and termination observers;
2. clears overlay drawing state;
3. orders out every panel;
4. restores the cursor stack;
5. verifies that no panel remains visible; and
6. delivers only the geometry outcome on the next main-actor turn.

That order establishes the G14 boundary: capture may begin only from the completion callback, after the overlay is absent. G13 sends a valid `SelectionResult` to a temporary `ScreenCaptureService` implementation that always throws `unavailableUntilG14` before calling any capture API, then resets the coordinator to idle.

The production service allows only one controller and unresolved continuation at a time. Concurrent menu or shortcut requests remain rejected while selection is active. Partial setup failures, display changes, application termination, and explicit lifecycle cancellation share the same cleanup path; surfaces hold only weak event callbacks, and the controller is released before the deferred result resumes the workflow.

## Live Evidence

The signed Debug experiment was exercised on macOS 26.5.1 (`25F80`) with Xcode 26.6 (`17F113`) and these freshly enumerated displays:

| Display | Runtime ID | AppKit frame | Core Graphics bounds | Scale and backing check |
| --- | ---: | --- | --- | --- |
| Dell S2721HGF | `4` | `(0, 0, 1920, 1080)` | `(0, 0, 1920, 1080)` | 1×, matched |
| Sidecar Display (AirPlay) | `11` | `(-1298, 126, 1298, 954)` | `(-1298, 0, 1298, 954)` | 2×, matched |

Runtime identifiers are evidence only and are not hardcoded in the app or tests. The in-app readback reported that the workstation currently uses separate Spaces per display.

On the Dell, a known 320 × 180-point forward drag reported AppKit global `(500, 650, 320, 180)`, Core Graphics global `(500, 250, 320, 180)`, and backing pixels `(500, 250, 320, 180)`. The frontmost application remained unchanged. Forward and reverse drags, click and tiny-drag cancellation, Escape before and during a drag, and every outer edge clamp completed without leaving a panel visible.

On Sidecar, a hand-driven selection reported display ID `11`, AppKit global `(-1129.42, 740.02, 211.03, 192.09)`, Core Graphics global `(-1129.42, 147.89, 211.03, 192.09)`, and outward-rounded backing pixels `(337, 295, 423, 385)`. This matches the 2× scale. The frontmost application remained unchanged. Hand-driven drags in both cross-display directions stopped the border at the initiating display edge and dimmed only that display, as designed. Pressing Escape during a hand-driven drag immediately removed the dim and border, reported `.escape`, preserved focus, and ignored the later mouse-up.

At Dell 1600 × 900 and 144 Hz, live descriptors rebuilt to `(0, 0, 1600, 900)` and the Sidecar AppKit origin adjusted to `(-1298, -54)`. A new 320 × 180-point selection still produced an exact 320 × 180-pixel result. The Dell was then restored to 1920 × 1080 at 144 Hz, and both displays returned to the frames recorded above.

With TextEdit in a separate full-screen Space, the five-second trigger left the panel transparent until mouse-down, changed the cursor to a crosshair, and then displayed the expected initiating-display dim and border over TextEdit. It did not switch Spaces or bring CopyLasso forward. Final inspection found no CopyLasso process or window after termination, and no panel, dim, border, or crosshair remained after any completed or cancelled session.

## Production Adoption

G13 replaces the temporary unavailable selection service with `AppKitRegionSelectionService`. Normal Debug and Release runs use it. A Debug-only deterministic selection double keeps unrelated signed UI tests from covering the desktop, while `--g13-live-selection` combines a controlled granted permission observation with the real accessible overlay. Both the argument and double are absent from Release.

Automated coverage begins from an expected compile failure before the production service types exist and covers fresh enumeration, surface construction and partial failure, initiating-display-only rendering, clamping and conversion, every cancellation source, deferred cleanup, hidden-window verification, overlap rejection, controller reuse, no launch-time overlay, no-pixel command orchestration, and at least 20 sequential sessions. The signed live matrix and its exact workstation display evidence are recorded in `docs/testing.md` and the local roadmap when executed.

The G13 production run on macOS 26.5.1 used the Dell primary display at 1920 × 1080 and 144 Hz: display ID `4`, matching AppKit and Core Graphics bounds `(0, 0, 1920, 1080)`, 1× backing scale, and a matching 100-point backing conversion. Menu and global-shortcut invocation each presented one accessible overlay without replacing frontmost TextEdit. Escape, click cancellation, a valid drag, full-screen TextEdit, and quitting during selection all removed every panel and left no CopyLasso window or process behind. The signed suite completed 20 mixed live sessions without changing the clipboard.

A fresh physical extended-display run was not possible during G13 because the temporary Sidecar iPad had been disconnected and was unavailable. The production service still uses the G07-proven per-display strategy, the current suite retains the exact Sidecar-style 2× geometry fixture, and a signed conditional test exercises both directions of a cross-display drag whenever an extended display is attached. That conditional test was compiled on both architectures and skipped—rather than reported as passing—on the one-display G13 workstation state. G19 remains responsible for the broader physical display matrix.

## Consequences and Limits

- G13 turns the proven behavior into production selection architecture without changing the coordinate contract.
- G14 must capture only after the selection completion callback and must use the selected display's local Core Graphics rectangle.
- Display configuration changes cancel the current session; production code must rebuild descriptors before another selection.
- Full hardening across more physical arrangements, display rotations, and macOS versions remains G19 and G29 work.
- G08 retired the executable overlay harness while retaining the pure geometry and selection-session model. G13 owns the production AppKit adapter.
- G13 introduces no public API, dependency, additional permission request, pixel capture, OCR integration, clipboard behavior, or feedback UI.
