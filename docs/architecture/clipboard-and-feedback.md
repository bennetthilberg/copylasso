# Clipboard, Sound, and Feedback

G17 implements the final clipboard and visual-feedback adapters without adding notification permission, history, or a focus-stealing window. G37 adds an isolated, content-free success-sound adapter after the clipboard commit.

## Clipboard Transaction

`SystemClipboardService` is the only application file allowed to use `NSPasteboard`. It rejects empty input, prepares one local `.string` item, and then performs one replacement. A successful replacement increments the pasteboard change count once.

The adapter deliberately never reads or snapshots the prior general pasteboard. Starting in macOS 15.4, programmatic general-pasteboard reads can trigger a separate access alert; avoiding that read preserves CopyLasso's Screen-Recording-only permission contract and avoids creating clipboard history in memory. Cancellation, no text, permission denial, selection failure, capture failure, OCR failure, and formatting failure do not call the adapter, so the existing clipboard is untouched.

AppKit exposes no atomic replace operation: it requires clearing before the fallible replacement write. The item is fully prepared before that clear, but if AppKit rejects the subsequent `writeObjects` call, the old contents cannot be restored without having performed the prohibited prior read. CopyLasso reports that exceptional clipboard-stage failure honestly. The v0.1 contract explicitly chooses this privacy-first boundary over prompting for read access, transiently retaining arbitrary prior clipboard data, and attempting a restoration that can itself race or fail.

## Bounded Feedback

`FeedbackPreview` collapses all whitespace to single spaces and limits success text to 80 extended grapheme clusters, including one trailing ellipsis when truncation is required. It does not interpret markup or retain the unbounded result.

`FeedbackPanelController` owns one reusable borderless `NSPanel` with the `.nonactivatingPanel` style. The panel:

- is never key or main;
- ignores mouse events;
- joins all Spaces and full-screen applications without entering window cycling;
- appears at status-bar level on the display containing the pointer;
- requests no notification permission and does not own sound playback; and
- clears its model and orders out after 2.5 seconds.

The same observable model temporarily changes the menu-bar symbol and accessibility label. The HUD exposes its bounded message as one accessibility label. A newer presentation supersedes an older dismissal token so an earlier timer cannot hide current feedback.

## Configurable Success Sound

`SystemSuccessSoundPlayer` is the only application file allowed to load or play audio. It receives no image, recognized text, clipboard text, preview, geometry, or application identity. After and only after `SystemClipboardService` successfully commits nonempty plain text, `CaptureCommand` asks the player to play once. Cancellation, no text, permission denial, selection failure, capture failure, OCR failure, formatting failure, and clipboard failure remain silent.

The player loads the original bundled `CopyLassoSuccess.wav` through `NSSound`, restarts the same short sound from the beginning for rapid successful captures, and returns immediately. A missing or unreadable asset, muted system output, unavailable output device, or playback refusal produces no additional UI, error, focus change, permission request, or capture delay. Lifecycle cancellation and termination stop any transient playback.

The versioned `feedback.successSoundEnabled` preference defaults on when absent. Migration preserves an explicit Boolean off value and repairs absent or malformed legacy state to the approved default. Settings exposes the value through a native accessible toggle.

Feedback presentation is not an active capture phase. The panel starts its own cancellable dismissal
timer and returns synchronously, allowing the coordinator to reach idle before the HUD timeout. The
next accepted menu or global-shortcut request synchronously hides any visible feedback and cancels its
timer before scheduling a fresh permission check. An older timer is generation-checked inside the
panel and cannot hide newer feedback. Requests during permission, selection, capture, and OCR remain
busy-rejected so two workflows never overlap.

## Current Workflow Boundary

The complete command writes nonempty assembled text, requests one content-free success sound when enabled, presents a bounded success preview, presents no-text without touching the clipboard, and presents a stage-specific failure after ordinary service errors. It returns to idle immediately after synchronous feedback presentation, rejects overlapping requests during earlier work, and lets the panel own its independent bounded lifetime. Selection cancellation and OCR cancellation remain normal non-error outcomes and never touch the pasteboard or sound player.

The image, recognized observations, and unbounded assembled string are local to one private async operation. That scope returns only bounded feedback after any write, so private pixels and full text are no longer retained while the HUD is visible. Integration tests keep both success and failure feedback visible after the command returns idle while proving the image has already been released.
