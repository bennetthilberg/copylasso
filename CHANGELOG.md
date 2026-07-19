# Changelog

All notable changes to CopyLasso will be documented in this file.

## Unreleased

## 0.1.0 - Unreleased

### Added

- A native Universal 2 menu-bar application for macOS 14 and newer.
- A configurable global capture shortcut, with `⇧⌘2` as the suggested default, plus a shared menu command.
- First-run setup, persistent Settings, explicit Launch at Login control, and permission recovery.
- A multi-display region-selection overlay with the system crosshair, initiating-display clamping, cancellation cleanup, accessibility-aware contrast, and reduced-motion presentation.
- In-memory ScreenCaptureKit region capture with Retina geometry validation and local Vision OCR configured for accurate corrected U.S. English recognition.
- Deterministic plain-text assembly for ordinary lines and paragraphs, followed by write-only plain-text clipboard output.
- A silent, nonactivating HUD for success, no-text, busy, permission, and recoverable-failure states.
- Lifecycle cancellation, rapid-hotkey rejection, repeatability coverage, content-free diagnostics, and resource-release checks.
- Minimal App Sandbox and Hardened Runtime configuration with no network client, capture persistence, analytics, telemetry, accounts, or automatic updater.
- An original layered CopyLasso app icon, template menu-bar mark, complete About panel, public documentation, and release checklist.
- KeyboardShortcuts 3.0.1, pinned exactly and acknowledged under its MIT license.

### Known Limitations

- OCR targets ordinary horizontal single-column U.S. English text; complex layouts, handwriting, and strongly rotated text are outside the initial release target.
- Selection is confined to the display where the drag begins, and protected content can be blank or unavailable under macOS capture restrictions.
- Immediate stationary-pointer reuse can briefly delay the visible crosshair until movement or mouse-down.
- Locking during an active drag can leave selection pending after unlock. Quit and reopen CopyLasso before another pointer action; if the retained selection completes, the clipboard may change.
- A rare pasteboard clear-success followed by text-write rejection can leave the clipboard empty; CopyLasso does not read or restore prior contents.
- Updates are manual.
