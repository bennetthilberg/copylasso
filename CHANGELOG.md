# Changelog

All notable changes to CopyLasso will be documented in this file.

## Unreleased

## 0.2.2 - 2026-08-10

### Security

- Updated the shipping Sparkle framework from 2.9.4 to 2.9.5 to incorporate
  the upstream fix for `GHSA-gmj2-gq3j-vqmj`. CopyLasso continues to publish
  authenticated full-package updates only and does not generate delta updates.

## 0.2.1 - 2026-08-09

### Fixed

- Update offers now render authenticated release notes in a bounded, scrollable native panel instead of exposing Markdown syntax or expanding beyond the screen.
- Selection now uses macOS's native interactive crosshair without activating CopyLasso or changing application focus, then captures the completed display-clamped rectangle in memory through ScreenCaptureKit.
- Saved-shortcut Shift, Option, and Control modifiers are released before the native selector starts, and adjacent display edges now have deterministic ownership. The native selector retains narrow documented races for exact Control-at-mouse-up, dragged first-use confirmation followed by Escape, and an entire drag completed between pointer samples.
- Update commands use the concise “Check for Updates” label, About has clearer icon-to-title spacing, and the privacy policy is substantially shorter.
- Permission recovery, lifecycle cancellation, native-selection completion, and release verification now fail closed across additional edge cases.

### Security

- Release workflows now constrain pull-request code, privileged signing inputs, archive paths, candidate tags, nested-code verification, and update metadata more tightly without changing the shipping entitlement or network boundary.

## 0.2.0 - 2026-07-29

### Added

- A user-controlled secure update path, with optional daily checks, a manual check, authenticated feed and package validation, replay and downgrade protection, and separate download and install consent. Automatic download and installation remain disabled.
- A brief, friendly, project-authored success sound, enabled by default and independently disableable in Settings. It plays only after a successful clipboard write.
- Unified on-screen recognition for QR, Code 128, Data Matrix, PDF417, and Aztec codes through the existing Capture action and shortcut. Supported codes take precedence over OCR text, while code-free selections fall back to text recognition. Multi-code ordering is deterministic, payloads remain inert plain text, and ambiguous multiline results preserve the clipboard.

## 0.1.1 - 2026-07-21

### Fixed

- Settings now appears immediately when opened from the menu instead of surfacing during the next capture.

## 0.1.0 - 2026-07-19

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
