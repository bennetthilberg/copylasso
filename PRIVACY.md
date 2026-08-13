# CopyLasso Privacy

**Status:** Public 0.2.2 (5).

Release-qualified v0.3.0 (6) source has not yet been published as a release
binary.

Release-qualified v0.3 source adds ordered OCR language choices and
off-by-default encrypted capture history. Neither feature is in public 0.2.2.

CopyLasso captures only the screen region you select, recognizes text or a
supported code locally, and writes the result to the clipboard.

## Capture and clipboard

- CopyLasso uses Apple's region selector, transient pointer samples,
  ScreenCaptureKit, and Apple Vision. OCR and QR, Code 128, Data Matrix, PDF417,
  and Aztec recognition run locally.
- Images and recognition observations stay in memory only for the active
  operation. CopyLasso never saves or uploads screenshots.
- Code payloads are recognized locally and copied as inert plain text. They are
  never opened, executed, or interpreted.
- Protected-content restrictions remain enforced by macOS.

Screen Recording is requested only when capture begins. The fixed
`/usr/sbin/screencapture` selector command uses no shell and sends its unused
image output to `/dev/null`; CopyLasso receives geometry, not an image, from
that subprocess. ScreenCaptureKit supplies selected pixels in memory. Core
capture needs no Accessibility, Input Monitoring, microphone, or notification
permission.

CopyLasso waits for shortcut modifiers to be released and samples only pointer,
left-button, and Shift/Option/Space state during selection. It rejects adjusted
rectangles and cross-display releases. A rare Control-at-mouse-up race can replace the clipboard
before cancellation because Control changes macOS's
screenshot behavior; CopyLasso does not read or recognize that value.

A successful capture replaces the general pasteboard with one plain-text value.
CopyLasso never reads the prior clipboard. All pre-output failures preserve it.
Because AppKit requires clearing before a fallible write, a rare write failure
after clearing can leave it empty; this avoids retaining arbitrary prior data.

Success sound playback receives no captured pixels, recognized content, or clipboard text.
It runs only after a successful write and can be disabled. HUD previews are
bounded, nonactivating, and cleared after 2.5 seconds.

CopyLasso has no accounts, sync, analytics, telemetry, or content logs.

## Stored data

Preferences contain onboarding, shortcut, permission-request history, Launch at
Login, sound, OCR-language, history-consent, and updater choices. Language
preferences are identifiers and priority only. Updater state contains its
schedule, deferred build, and highest authenticated build, not feed bodies or
release notes. Fixed lifecycle diagnostics contain no content, app name,
geometry, or user value.

### Optional history in release-qualified v0.3 source

**Save Capture History** is off by default and creates no archive or key until
enabled. It stores only exact successful text or inert code output, type,
timestamp, and random identifier. The limit is 100 entries for seven days and
256 KiB per entry. Failures, screenshots, source apps, geometry, observations,
prior clipboard contents, and HUD data are excluded.

The versioned archive uses authenticated AES-256-GCM encryption in sandboxed
Application Support, `0600` permissions, and backup exclusion. Its random key
is a separate nonsynchronizing, this-device-only, bundle-scoped Keychain item.
Missing keys, tampering, truncation, or unknown versions expose no entries and
do not silently replace unreadable data.

Users can copy or delete one entry and confirm Clear All. Disabling nonempty or
unreadable history also requires confirmation and removes the active archive
and key. App deletion cannot promise forensic erasure from APFS snapshots or
external backups.

Public 0.2.2 persists no captured content.

## Network activity

The secure updater is CopyLasso's only network feature. Automatic checks default
on, run at most daily, and can be disabled; **Check for Updates** checks now.
Sparkle retrieves the fixed signed feed at
`https://updates.copylasso.com/appcast.xml` and accepts the matching GitHub
Releases DMG. Profiling, cookies, external notes, automatic download, and
automatic installation are disabled. Notes are transient; download and install
each require a decision.

The feed host and GitHub can observe an IP address, request time, and user agent.
Update requests send no screen pixels, recognized content, clipboard data,
frontmost-app identity, hardware profile, stable identifier, analytics, or
telemetry. Settings links open in the default browser.

CopyLasso 0.1.x has no updater or code recognition. Existing users must manually install the latest public release once before authenticated checks can begin.

See the [product contract](docs/v0.1-product-contract.md) and
[security review](docs/security-and-privacy-review.md).
