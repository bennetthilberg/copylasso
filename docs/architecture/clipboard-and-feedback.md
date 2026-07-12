# Clipboard and Feedback

G17 implements the final output adapters without adding notification permission, sound, history, or a focus-stealing window.

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
- requests no notification permission and plays no sound; and
- clears its model and orders out after 2.5 seconds.

The same observable model temporarily changes the menu-bar symbol and accessibility label. The HUD exposes its bounded message as one accessibility label. A newer presentation supersedes an older dismissal token so an earlier timer cannot hide current feedback.

## Current Workflow Boundary

The G17 command slice writes nonempty assembled text, presents a bounded success preview, presents no-text without touching the clipboard, and presents a clipboard-failure result after a rejected write. It stays in the coordinator's completing phase until feedback disappears, rejects overlapping requests, and then returns to idle. G18 retains ownership of uniform feedback at every earlier failure boundary, explicit whole-operation resource cleanup, and end-to-end stress verification.
