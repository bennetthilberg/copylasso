# CopyLasso Privacy

**Status:** Public 0.2.2 (5).

The unreleased source tree stores only an ordered list of OCR language
identifiers. Vision remains local; no language model or content is downloaded
or uploaded.

CopyLasso captures only the screen region you select, recognizes text or
supported codes locally, and writes the result to the clipboard.

## Capture and recognition

- CopyLasso uses Apple's region selector, transient pointer samples, and
  ScreenCaptureKit. Apple Vision
  recognizes OCR plus QR, Code 128, Data Matrix, PDF417, and Aztec locally.
- Captured images, recognition observations, complete results, and the bounded
  HUD preview remain in memory only as long as their active operation needs
  them. CopyLasso does not save or upload them.
- Code payloads are recognized locally and copied as inert plain text.
  CopyLasso never opens, executes, or interprets them.
- Core capture and recognition work offline. CopyLasso does not bypass macOS
  protected-content restrictions.

CopyLasso has no accounts, sync, analytics, telemetry, history, or content logs.
It never logs or persists captured or recognized content.

## Permission and clipboard

CopyLasso asks for Screen Recording access only after capture starts. It runs
`/usr/sbin/screencapture` with fixed arguments, no shell, and `/dev/null` as its
unused image destination. CopyLasso receives no subprocess image.
ScreenCaptureKit returns only selected pixels in memory and releases them before
feedback or on cancellation. If selection returns no geometry, a content-free
ScreenCaptureKit check distinguishes Escape from denied access without retaining
shareable-content metadata. Core capture needs no Accessibility, Input
Monitoring, microphone, or notification access.

Before selection, CopyLasso waits for saved-shortcut Shift, Option, and Control
release. Control can redirect macOS's screenshot to the clipboard, so
CopyLasso cancels when observed. Without input interception, an exact
Control-at-mouse-up race can replace the clipboard before cancellation;
CopyLasso neither reads it nor sends it to recognition. During selection it
samples only pointer, left-button, and Shift/Option/Space state. Adjusted
rectangles and cross-display releases are rejected. A dragged first-use
confirmation followed by Escape or an entire drag between one-millisecond
samples can rarely produce or miss geometry.

Successful capture replaces the general pasteboard with one plain-text value.
CopyLasso never reads or snapshots the previous clipboard. Cancellation,
no-content, ambiguity, permission failure, capture failure, and recognition
failure do not call the clipboard service. AppKit requires clearing the
pasteboard before a fallible write, so the rare case where clearing succeeds
but writing fails can leave the clipboard empty. This is the privacy-first
tradeoff that avoids reading and temporarily retaining arbitrary prior data.

Success sound playback receives no captured pixels, recognized content, or clipboard text.
It occurs only after a successful clipboard write and can be disabled.
HUD feedback is nonactivating, bounded, and cleared after 2.5 seconds;
cancellation presents no HUD.

## Stored settings

CopyLasso stores preferences for onboarding, the shortcut, permission-request
history, Launch at Login, sound, selected OCR languages, and updates. The OCR
preference contains language identifiers and their priority only. Update state contains its schedule,
preference, deferred build, and highest authenticated build.
It stores no appcast bodies, release notes, captured content, or clipboard
content. Launch at Login state comes from macOS. Fixed lifecycle diagnostics
contain no content, application name, geometry, or user value.

## Network activity

The secure updater is the only network feature. Capture, recognition, clipboard
output, Settings, onboarding, sound, and Launch at Login stay offline.
Automatic checks default on, run at most every 24 hours, and can be disabled;
**Check for Updates** starts a manual check.

Sparkle retrieves one fixed signed feed at
`https://updates.copylasso.com/appcast.xml` and accepts only the matching
CopyLasso DMG on GitHub Releases. System profiling, cookies, external notes,
automatic download, and automatic installation are disabled. Authenticated
notes are transient; download and installation each require a user decision.

The feed host and GitHub can observe IP address, request time, and a user agent
containing CopyLasso and Sparkle versions. Update requests send no screen pixels,
recognized content, clipboard data, frontmost-application identity, hardware
profile, stable identifier, analytics, or telemetry.
Links in Settings open in the default browser rather than being fetched by
CopyLasso.

CopyLasso 0.1.x has no updater or code recognition. Existing users must
manually install the latest public release once before authenticated update
checks can begin.

See the public [product contract](docs/v0.1-product-contract.md) and
[security review](docs/security-and-privacy-review.md) for the enforced
boundaries, entitlements, dependencies, and misuse cases.
