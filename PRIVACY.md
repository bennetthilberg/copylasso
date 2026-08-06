# CopyLasso Privacy

**Status:** Approved privacy contract for public CopyLasso 0.2.0.

CopyLasso is a local-first macOS utility. It captures only the screen region you
select, recognizes visible text or supported codes on this Mac, and writes the
result to the clipboard.

## Capture and recognition

- Screen capture uses Apple ScreenCaptureKit. OCR uses Apple Vision. Code payloads are recognized locally
  with Vision and are limited to QR, Code 128,
  Data Matrix, PDF417, and Aztec.
- Captured images, recognition observations, complete results, and the bounded
  HUD preview remain in memory only as long as their active operation needs
  them. CopyLasso does not save or upload them.
- Code payloads are copied as inert plain text. CopyLasso never opens, executes,
  validates as a URL, or otherwise acts on their contents.
- Core capture and recognition work offline. Protected content may be blank or
  unavailable, and CopyLasso does not attempt to bypass macOS protections.

CopyLasso has no accounts, synchronization, analytics, telemetry, capture
history, clipboard history, or content logs. It never logs or persists screen
pixels, recognized text, code payloads, clipboard text, or HUD previews.

## Permission and clipboard

CopyLasso asks for macOS Screen Recording access only after a user starts a
capture. Temporary transparent selection panels retain only display geometry
for the active selection and are removed before capture proceeds. The selected
image is not encoded or written to a file, cursor and audio capture are
disabled, and the image is released after local recognition or cancellation.
The core workflow needs no Accessibility, Input Monitoring, microphone, or
notification permission.

Successful capture replaces the general pasteboard with one plain-text value.
CopyLasso never reads or snapshots the previous clipboard. Cancellation,
no-content, ambiguity, permission failure, capture failure, and recognition
failure do not call the clipboard service. AppKit requires clearing the
pasteboard before a fallible write, so the rare case where clearing succeeds
but writing fails can leave the clipboard empty. This is the privacy-first
tradeoff that avoids reading and temporarily retaining arbitrary prior data.

Success sound playback receives no captured pixels, recognized content, or clipboard text.
It occurs only after a successful clipboard write and can be disabled. HUD
feedback is nonactivating, bounded to 80 preview characters, and cleared after
2.5 seconds; cancellation presents no HUD.

## Stored settings

CopyLasso stores only ordinary preferences for onboarding, the Capture
shortcut, permission-request history, Launch at Login presentation, sound, and
update controls. Update state contains the schedule and preference, a deferred
build, and the highest authenticated build used to reject replay or downgrade.
It does not store appcast bodies, release notes, captured content, or clipboard
content. Launch at Login state is read from macOS. Fixed lifecycle diagnostics
contain no content, application name, display geometry, or user value.

## Network activity

The secure updater is CopyLasso's only network feature. Capture, recognition,
clipboard output, Settings, onboarding, sound, and Launch at Login do not use
the network. Automatic checks default on, run no more often than every 24
hours, and can be disabled; **Check for Updates** starts a manual check.

Sparkle retrieves the fixed signed feed at
`https://updates.copylasso.com/appcast.xml`. Accepted packages must be the
version-matched CopyLasso DMG on GitHub Releases. CopyLasso disables system
profiling, cookies, custom headers, query parameters, external release-note
downloads, automatic downloads, and automatic installation. Authenticated
inline release notes are kept only for the active update transaction. The feed
and package are cryptographically authenticated, and download and installation
each require an explicit user decision.

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

The release-blocking guarantees remain defined by the public
[product contract](docs/v0.1-product-contract.md). Implementation boundaries,
entitlements, dependencies, and misuse cases are documented in the
[security and privacy review](docs/security-and-privacy-review.md).
