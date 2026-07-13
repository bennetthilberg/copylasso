# Lifecycle And Recovery

G20 makes the root application process responsible for cancelling the complete capture workflow during ordinary macOS lifecycle interruptions.

## Observed Events

One root-owned `ApplicationLifecycleController` subscribes through an isolated AppKit event source to:

- workspace will-sleep and screen-sleep notifications;
- workspace session-resign for fast-user-session changes;
- wake, screen-wake, and session-resume notifications; and
- application termination.

Sleep, screen sleep, and session resign are one logical interruption. The controller coalesces duplicates until the first corresponding resume event. Resume only clears that coalescing state; it never retries or begins a capture. Ordinary application activation and deactivation are intentionally not observed because CopyLasso is designed to select while another application remains frontmost. macOS does not guarantee that an ordinary screen lock is a workspace session switch, so lock/unlock remains an independent signed acceptance case.

## Cancellation Ownership

The production `CaptureCommand` owns its scheduled `Task`. A lifecycle cancellation records only `.systemInterrupted` or `.applicationTerminated`, asks an active selection service to remove its panels synchronously, and cancels the task. Stage boundaries check cancellation before using capture or OCR output. The ScreenCaptureKit and Vision awaits receive task cancellation, and feedback sleep is cancelled so its HUD clears immediately.

The active selection adapter also observes workspace will-sleep, screen-sleep,
and session-resign notifications directly. This defense-in-depth path maps the
first notification to the same synchronous, idempotent surface, cursor, event-
handler, and focus-restoration teardown. Duplicate notifications and late
activation, cursor-installation, display, termination, and mouse callbacks are
ignored. All selector-based notification callbacks accept the documented one
`Notification` argument.

Cancellation remains distinct from failure:

- no generic failure HUD is presented;
- no cancellation calls the clipboard before output;
- if output was already written and feedback is being dismissed, the write is not rolled back through a prohibited pasteboard read;
- terminal cancellation resets to idle after the operation unwinds; and
- a second user request can begin immediately afterward.

The existing `CaptureFailureStage` enum remains the centralized error taxonomy. It records only permission, selection, capture, recognition, formatting, clipboard, feedback, or internal stage. `FeedbackPresentationContent` maps those stages to bounded user-safe messages; raw platform errors and private content never enter state or UI.

## Termination And Transient UI

On termination the controller cancels active work, dismisses permission recovery, stops global-shortcut delivery, records one safe diagnostic, and removes its notification observers. The selection adapter independently observes termination as a defense in depth and uses the same idempotent panel/cursor cleanup path.

On an observed sleep or session switch, the controller dismisses permission recovery and cancels any active operation. Resume does not restore a panel, cursor override, task, or capture automatically.

## Diagnostics

`SystemCaptureLifecycleLogger` is the only production OSLog adapter. It emits fixed strings for interruption cancellation, interruption while idle, resume, and termination cleanup. It never interpolates geometry, pixels, observations, assembled text, pasteboard values, previews, raw errors, captured/frontmost application names, or user data. CI confines `OSLog` and `Logger` to that file and rejects string interpolation there.

Automated tests inject lifecycle events, cancellation gates, recovery presentation, shortcut shutdown, and logging. Real sleep/wake, lock/unlock, and quit-during-selection behavior remains a signed manual matrix because unit notifications cannot prove WindowServer state.
