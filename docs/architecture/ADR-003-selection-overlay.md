# ADR-003: AppKit Overlay and Per-Display Geometry Are Viable

- **Status:** Accepted
- **Date:** July 10, 2026
- **Scope:** G07 feasibility decision adopted by the production G13 selection service and G14 capture timing

## Context

CopyLasso must let a user begin a rectangular selection on any attached display without dimming unrelated displays or including the overlay in the later capture. Signed production evidence established that public cursor APIs require CopyLasso to become active during selection to replace another app's pointer reliably. AppKit and Core Graphics describe the same display with different origins and Y-axis conventions, and backing pixels may use a nonintegral scale. G07 tests the windowing and geometry assumptions before they become production architecture.

The original experiment was Debug-only and used `--g07-selection-spike`; G08 retired that executable harness while preserving its evidence and geometry. G13 now implements the same decision in the normal Debug and Release path. Construction and launch remain inert: panels are created only after an authorized user command reaches selection. The selection adapter itself never captures pixels, calls Vision, writes the clipboard, or persists selection data; later workflow stages receive only its neutral geometry result.

## Decision

The AppKit approach is viable. CopyLasso will use one transparent, borderless `NSPanel` per `NSScreen` during selection. Each panel:

- uses [`.nonactivatingPanel`](https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel) to avoid ordinary panel activation behavior while an explicit selection-only activation manager owns the temporary focus handoff;
- covers the complete `NSScreen.frame`, including menu-bar and Dock regions;
- uses `.canJoinAllSpaces`, `.fullScreenAuxiliary`, and `.ignoresCycle` [collection behaviors](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct);
- sits at screen-saver level and does not enter normal window cycling;
- is visually clear before mouse-down while the normal AppKit crosshair replaces the pointer;
- while dragging, dims only the initiating display outside the selection with 18% black; and
- draws one thin neutral-gray dashed selection outline with a subtle two-point corner radius whose phase moves linearly around the active rectangle, while Reduce Motion leaves the same dashed outline static.

Before panels are shown, the activation manager records a different frontmost
application, requests selection-only activation, and waits for AppKit's
`didBecomeActiveNotification`. When CopyLasso is already active because Settings
or About is frontmost, it does not create a synthetic activation handoff. Only a
confirmed-active callback may construct and present the panels. The panel under
the pointer then requests key status, but
cursor setup waits for that exact panel's `didBecomeKey` callback rather than
treating `makeKey()` as synchronous. Once key, the panel explicitly makes its
overlay view first responder. If mouse-down occurs on any other display,
that clicked panel becomes key and its overlay view becomes first responder before
drag handling begins. This gives Escape a deterministic path before or during a
drag regardless of which display was initially under the pointer. A drag remains
owned by its initiating display; moving the pointer onto another display clamps
the endpoint to the initiating display edge. Unrelated display panels remain fully
transparent.

Cursor setup follows panel setup rather than preceding it. After every panel is
ordered and the pointer panel has become key with its overlay view first
responder, that view asks its owning window to invalidate and rebuild its
full-window crosshair cursor rectangle. Cursor-rectangle management remains
enabled so AppKit continues to apply that crosshair during movement. The
controller waits one main-actor turn for the key-window refresh to settle, then
pushes and sets the selection-wide system crosshair. Mouse-down repeats the
window-level refresh after making a newly clicked panel key.

AppKit does not reliably replace the WindowServer cursor while another
application remains active. CopyLasso therefore requests foreground status for
the selection interval and uses the normal AppKit crosshair; it does not draw a
second pointer. Cleanup hides all panels, restores the cursor stack, and then
cooperatively yields activation back to the recorded application before the
deferred selection result is delivered. If CopyLasso was already active, cleanup
delivers the result immediately without deactivating or waiting for a future
resign event. This keeps OCR and the nonactivating HUD from depending on a click
in another application.

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

The production display provider cross-checks the reported backing scale against `NSScreen.convertRectToBacking`. It reads `NSScreen.screens` fresh for every session, rejects missing or duplicate display identifiers, rejects AppKit/Core Graphics point-size disagreement, and never caches a display layout. The selection result carries the initiating display point size so capture can compare it with a fresh ScreenCaptureKit snapshot. Unit tests cover 1×, 1.5×, and 2× scaling; negative origins; landscape and portrait displays above, below, left, right, and diagonal to the primary; all edge clamps; and the current Sidecar-style offset shape without embedding its runtime display identifier.

## Completion and Cancellation

A selection is valid only when both width and height are at least 4 points; exactly 4 points is accepted. A click or smaller drag is a normal `.tooSmall` cancellation. Escape, display reconfiguration, and application termination are also normal cancellation outcomes rather than application errors.

Every path completes at most once. On mouse-up or cancellation, the controller synchronously:

1. removes display and termination observers;
2. clears overlay drawing state;
3. orders out every panel;
4. restores the cursor stack;
5. restores the previously active application when it remains available;
6. verifies that no panel remains visible; and
7. delivers only the geometry outcome on the next main-actor turn.

That order establishes the capture boundary: capture may begin only from the completion callback, after the overlay is absent. G14 now sends the validated result to the production ScreenCaptureKit service. The selection carries its backing scale and outward-rounded display-local pixel rectangle so capture does not need to reconstruct geometry from a primary-display assumption.

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

A July 11 signed follow-up found that the production pointer could remain an
arrow because the cursor was pushed before the AppKit panels were ordered. A
focused regression test first reproduced that startup order and now requires
all surfaces to be visible, the input surface to be ready, and every cursor
rectangle to be refreshed before the crosshair is pushed. The same test proves
a partial surface-construction failure does not mutate the cursor stack. A
fresh signed manual run remains required to validate the WindowServer-visible
pointer before and throughout a drag.

A subsequent review found that directly discarding and adding a cursor rectangle
on the view did not invalidate AppKit's active window cursor tracking when the
stationary pointer was already over the newly ordered overlay. The regression
now proves that refresh invalidates and rebuilds cursor rectangles through the
owning window and that a clicked noninitial panel repeats that refresh before
drag rendering.

The follow-up signed runs first showed only the ordinary arrow and then showed
that arrow plus an offset app-drawn reticle. Reasserting or hiding the cursor
could not provide a reliable replacement while the originating application
remained active. The maintainer therefore approved a selection-only focus
handoff. Focused controller coverage proves activation precedes panel
presentation, the rejected drawn-reticle path is absent, and restoration
precedes deferred completion. Signed human observation remains the final visual
and focus-restoration gate.

A July 12 repeated-capture run found a narrower activation race: invoking again
while success feedback remained visible could leave the arrow in place until
mouse-down, even though the selection request had already called `activate`.
Calling `activate` is only a request, so the controller now waits for the actual
application-active notification before it creates an input-ready surface,
refreshes cursor rectangles, or pushes the crosshair. Regression tests hold that
notification to prove no surface or cursor appears early, prove the notification
releases startup exactly once, cover the already-active path, and prove
cancellation invalidates a late callback.

The corresponding signed candidate proved application activation was still not
the final WindowServer-visible boundary: rapid reuse could flicker or leave the
arrow until mouse-down. The controller had requested `makeKey()` on the pointer's
panel and immediately rebuilt cursor rectangles. AppKit establishes invalidated
cursor rectangles when their window becomes key, so the production surface now
reports a one-shot key-readiness callback. Only that callback rebuilds cursor
rectangles and pushes the native crosshair. Cleanup cancels pending readiness,
and direct tests cover delayed key status, cancellation, duplicate callbacks, and
a mouse-down handoff that arrives before the initial panel reports key.

A later signed run proved that disabling cursor-rectangle management to avoid a
stationary overwrite instead made the pointer alternate between the arrow and
crosshair during movement. The correction keeps native cursor rectangles active,
refreshes the exact keyed surface, and defers the global crosshair push by one
main-actor turn so AppKit's key-window refresh is established first. Focused
tests prove the refresh through the owning window, the refresh-before-push order,
and suppression of a scheduled push after cancellation.

The G13 production run on macOS 26.5.1 used the Dell primary display at 1920 × 1080 and 144 Hz: display ID `4`, matching AppKit and Core Graphics bounds `(0, 0, 1920, 1080)`, 1× backing scale, and a matching 100-point backing conversion. Menu and global-shortcut invocation each presented one accessible overlay without replacing frontmost TextEdit. Escape, click cancellation, a valid drag, full-screen TextEdit, and quitting during selection all removed every panel and left no CopyLasso window or process behind. The signed suite completed 20 mixed live sessions without changing the clipboard.

A fresh physical extended-display run was not possible during G13 because the temporary Sidecar iPad had been disconnected and was unavailable. The production service still uses the G07-proven per-display strategy, the current suite retains the exact Sidecar-style 2× geometry fixture, and a signed conditional test exercises both directions of a cross-display drag whenever an extended display is attached. That conditional test was compiled on both architectures and skipped—rather than reported as passing—on the one-display G13 workstation state. G19 adds broader synthetic layout and snapshot validation, while its fresh physical display matrix remains pending release evidence.

## Consequences and Limits

- G13 turns the proven behavior into production selection architecture without changing the coordinate contract.
- G14 captures only after the selection completion callback and uses the selected display's local Core Graphics and backing-pixel rectangles.
- Display configuration changes cancel the current session; production code must rebuild descriptors before another selection.
- Synthetic hardening across left/right/above/below/diagonal, portrait, mixed-scale, and Sidecar-style arrangements is part of G19. Fresh physical arrangements and rotations remain release evidence, and older macOS coverage remains G29 work.
- G08 retired the executable overlay harness while retaining the pure geometry and selection-session model. G13 owns the production AppKit adapter.
- G13 introduces no public API, dependency, additional permission request, pixel capture, OCR integration, clipboard behavior, or feedback UI.
