# CopyLasso Privacy

**Status:** Public 0.2.0 (3); candidate 0.2.1 (4) keeps these boundaries.

CopyLasso captures only the screen region you select, recognizes text or
supported codes locally, and writes the result to the clipboard.

## Capture and recognition

- Public 0.2.0 uses ScreenCaptureKit. Current source uses Apple's region
  selector, transient pointer samples, and ScreenCaptureKit. Apple Vision
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

CopyLasso asks for Screen Recording access only after capture starts. Current
source runs `/usr/sbin/screencapture` with fixed project arguments and no shell
or user-controlled command. macOS may show a direct-access confirmation. Its
image destination is `/dev/null`; CopyLasso receives no encoded screenshot from
the subprocess. ScreenCaptureKit returns only the selected pixels in memory,
and the image is released before feedback begins or when the operation cancels.
If the selector returns without geometry, CopyLasso asks ScreenCaptureKit only
to verify current access before deciding whether the attempt was Escape or a
permission denial. It retains no shareable-content metadata from that check.
The core workflow needs no Accessibility, Input Monitoring, microphone, or
notification access.

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
history, Launch at Login, sound, and updates. Update state contains its schedule,
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
manually install public CopyLasso 0.2.0 once before authenticated update checks
can begin.

See the public [product contract](docs/v0.1-product-contract.md) and
[security review](docs/security-and-privacy-review.md) for the enforced
boundaries, entitlements, dependencies, and misuse cases.
