# ADR-003: AppKit Overlay and Per-Display Geometry Are Viable

- **Status:** Accepted
- **Date:** July 10, 2026
- **Scope:** G07 feasibility spike; production selection remains deferred to G13 and region capture to G14

## Context

CopyLasso must let a user begin a rectangular selection on any attached display without activating the app, dimming unrelated displays, or including the overlay in the later capture. AppKit and Core Graphics describe the same display with different origins and Y-axis conventions, and backing pixels may use a nonintegral scale. G07 tests the windowing and geometry assumptions before they become production architecture.

The experiment is Debug-only and is launched explicitly with `--g07-selection-spike`. Launching it presents a diagnostic window but does not present overlays. It never captures pixels, calls Vision, writes the clipboard, or persists selection data.

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

The harness cross-checks the reported backing scale against `NSScreen.convertRectToBacking`. Invalid frames, nonfinite coordinates, and nonpositive scales are rejected. Unit tests cover 1×, 1.5×, and 2× scaling; negative origins; displays above, below, and beside the primary; all edge clamps; and the current Sidecar-style offset shape without embedding its runtime display identifier.

## Completion and Cancellation

A selection is valid only when both width and height are at least 4 points; exactly 4 points is accepted. A click or smaller drag is a normal `.tooSmall` cancellation. Escape, display reconfiguration, and application termination are also normal cancellation outcomes rather than application errors.

Every path completes at most once. On mouse-up or cancellation, the controller synchronously:

1. removes display and termination observers;
2. clears overlay drawing state;
3. orders out every panel;
4. restores the cursor stack;
5. verifies that no panel remains visible; and
6. delivers only the geometry outcome on the next main-actor turn.

That order establishes the G14 boundary: a future capture may begin only from the completion callback, after the overlay is absent. The G07 spike itself never performs capture.

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

## Consequences and Limits

- G13 may turn the proven behavior into production selection architecture without changing the coordinate contract.
- G14 must capture only after the selection completion callback and must use the selected display's local Core Graphics rectangle.
- Display configuration changes cancel the current session; production code must rebuild descriptors before another selection.
- Full hardening across more physical arrangements, display rotations, and macOS versions remains G19 and G29 work.
- G08 retired the executable overlay harness while retaining the pure geometry and selection-session model. G13 owns the production AppKit adapter.
- G07 introduces no public API, dependency, permission request, pixel capture, OCR integration, clipboard behavior, onboarding, or production UI.
