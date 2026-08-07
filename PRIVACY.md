# CopyLasso Privacy

**Status:** Approved privacy contract for public CopyLasso 0.2.0.

CopyLasso captures only the screen region you select, recognizes text or
supported codes locally, and writes the result to the clipboard.

## Capture and recognition

- Public 0.2.0 uses Apple ScreenCaptureKit. Current source invokes Apple's fixed
  interactive region selector for the native crosshair and drag, derives only
  the selected rectangle from mouse event coordinates, then captures that rectangle in
  memory with ScreenCaptureKit. OCR uses Apple Vision locally.
  Code payloads are recognized locally with Vision in five formats: QR, Code 128,
  Data Matrix, PDF417, and Aztec.
- Captured images, recognition observations, complete results, and the bounded
  HUD preview remain in memory only as long as their active operation needs
  them. CopyLasso does not save or upload them.
- Code payloads are inert plain text. CopyLasso never opens, executes, or
  interprets them.
- Core capture and recognition work offline. CopyLasso does not bypass macOS
  protected-content restrictions.

CopyLasso has no accounts, sync, analytics, telemetry, history, or content logs.
It never logs or persists pixels, recognized text, code payloads, clipboard
text, or HUD previews.

## Permission and clipboard

CopyLasso asks for macOS Screen Recording access only after a user starts a
capture. Current source starts only `/usr/sbin/screencapture` with fixed
project-owned arguments: there is no shell or user-controlled command. macOS
may show its direct-screen-access confirmation for this native selector. Its
image destination is `/dev/null`; CopyLasso receives no encoded screenshot from
the subprocess. ScreenCaptureKit returns only the selected pixels in memory,
and the image is released after recognition or cancellation.
The core workflow needs no Accessibility, Input Monitoring, microphone, or
notification permission.

If Control is held before or during selection, CopyLasso cancels the attempt
because macOS would otherwise redirect the screenshot to the clipboard. While
the selector is active, an observe-only monitor retains only left-button-down
and left-button-up coordinates, and CopyLasso checks that content-free modifier
state. It neither intercepts nor synthesizes input.

Successful capture replaces the general pasteboard with one plain-text value.
CopyLasso never reads or snapshots the previous clipboard. Cancellation,
no-content, ambiguity, permission failure, capture failure, and recognition
failure do not call the clipboard service. AppKit requires clearing the
pasteboard before a fallible write, so the rare case where clearing succeeds
but writing fails can leave the clipboard empty. This is the privacy-first
tradeoff that avoids reading and temporarily retaining arbitrary prior data.

Success sound playback receives no captured pixels, recognized content, or clipboard text.
It occurs only after a successful clipboard write and can be disabled.
HUD feedback is nonactivating, bounded to 80 preview characters, and cleared
after 2.5 seconds; cancellation presents no HUD.

## Stored settings

CopyLasso stores only ordinary preferences for onboarding, the Capture
shortcut, permission-request history, Launch at Login presentation, sound, and
update controls. Update state contains the schedule and preference, a deferred
build, and the highest authenticated build used to reject replay or downgrade.
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

The feed host and GitHub can observe ordinary connection metadata such as IP
address and request time. Sparkle's user agent identifies the CopyLasso and
Sparkle versions. Update requests send no screen pixels, selected rectangle,
recognized text, code payload, clipboard data, HUD preview, frontmost-app name,
hardware profile, stable user or device identifier, analytics, or telemetry.
Links in Settings open in the default browser rather than being fetched by
CopyLasso.

CopyLasso 0.1.x has no updater or code recognition. Existing users must
manually install public CopyLasso 0.2.0 once before authenticated update checks
can begin.

See the public [product contract](docs/v0.1-product-contract.md) and
[security review](docs/security-and-privacy-review.md) for the enforced
boundaries, entitlements, dependencies, and misuse cases.
