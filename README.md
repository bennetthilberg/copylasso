# CopyLasso

[![CI](https://github.com/bennetthilberg/copylasso/actions/workflows/ci.yml/badge.svg)](https://github.com/bennetthilberg/copylasso/actions/workflows/ci.yml)

CopyLasso is a free and open-source macOS utility for copying visible text from anywhere on screen. Press `⇧⌘2`, drag around text, and receive recognized plain text on the clipboard. Recognition runs locally with Apple's Vision framework, and CopyLasso does not retain a screenshot or OCR history.

CopyLasso 0.1.1 is the latest public release.

## Requirements

- macOS 14 or newer
- An Apple silicon or Intel Mac; the release is a native Universal 2 application
- Screen Recording permission for region capture

## Install CopyLasso

Download CopyLasso 0.1.1 from the [release page](https://github.com/bennetthilberg/copylasso/releases/tag/v0.1.1):

- [CopyLasso-0.1.1.dmg](https://github.com/bennetthilberg/copylasso/releases/download/v0.1.1/CopyLasso-0.1.1.dmg)
- [CopyLasso-0.1.1.dmg.sha256](https://github.com/bennetthilberg/copylasso/releases/download/v0.1.1/CopyLasso-0.1.1.dmg.sha256)

Place both files in the same folder, then verify the download before opening it:

```sh
shasum -a 256 -c CopyLasso-0.1.1.dmg.sha256
```

The result must report `CopyLasso-0.1.1.dmg: OK`. Then:

1. Open `CopyLasso-0.1.1.dmg` and drag CopyLasso into Applications.
2. Open CopyLasso. It runs in the menu bar and does not add a Dock icon.
3. Complete the short first-run setup and keep the suggested `⇧⌘2` shortcut or record another one.
4. The first capture asks macOS for Screen Recording permission. Approve CopyLasso, then choose **Quit & Reopen** if macOS offers it.

## Use CopyLasso

1. Press `⇧⌘2`, or choose **Capture Text** from the CopyLasso menu-bar menu.
2. Drag around text on one display. Press `Esc` to cancel without changing the clipboard.
3. CopyLasso captures only the selected region, recognizes English text locally, and writes the assembled plain text to the clipboard.
4. A short, nonactivating HUD reports copied text, no text found, a busy request, or a recoverable failure.

Open **Settings…** from the menu to change or clear the shortcut, enable Launch at Login, review privacy information, or reopen first-run setup when it is incomplete.

Current source also includes the configurable success sound planned for the first v0.2 release. It is enabled by default and can be disabled with **Settings > Play Sound After Copying**. It plays only after recognized content reaches the clipboard; cancellation, no result, permission denial, recognition failure, and clipboard failure remain silent. The public CopyLasso 0.1.1 download retains its original silent feedback behavior.

Current source also adds a separate **Capture Code** command for QR, Code 128, Data Matrix, PDF417, and Aztec codes visible on screen. It shares the established local selection and capture workflow, copies recognized payloads as inert plain text, and never opens a URL or otherwise acts on a payload. Its optional shortcut is unset by default. Capture Code is present in current source but is not part of the public CopyLasso 0.1.1 download.

## Permission and Recovery

Screen Recording is the only macOS privacy permission required for core capture. CopyLasso does not require Accessibility, Input Monitoring, microphone, camera, location, contacts, or network access.

If capture access is unavailable, CopyLasso shows a recovery window with a direct route to **System Settings > Privacy & Security > Screen & System Audio Recording**. Enable CopyLasso, quit and reopen it when macOS requests that transition, and then choose **Try Again**. Denial and unavailable-access paths preserve the clipboard.

## Privacy

CopyLasso's capture workflow is private, offline, and local by design:

- Captured pixels and unbounded recognized text stay in memory only for the active operation.
- Screenshots, OCR results, clipboard history, and HUD previews are never logged, persisted, or transmitted.
- The application has no accounts, analytics, telemetry, cloud OCR, or content-upload service.
- Current source includes the user-controlled secure updater planned for the first v0.2 release. It checks one fixed, cryptographically authenticated feed, sends no screen, OCR, clipboard, hardware-profile, or stable-identifier data, and is independent from capture.
- Current source's optional success sound receives no captured pixels, recognized content, or clipboard text and requests no microphone or notification permission.
- Current source recognizes supported code payloads locally with Vision, keeps complete payloads only in the active operation, and treats them only as clipboard text.
- Clipboard access is write-only and plain-text-only. CopyLasso never reads the existing clipboard to preserve or restore its contents.

See the [privacy policy](PRIVACY.md), [security and privacy review](docs/security-and-privacy-review.md), and [v0.1 product contract](docs/v0.1-product-contract.md) for the reviewed guarantees and boundaries.

## Known Limitations

- Version 0.1 targets ordinary, approximately horizontal, single-column U.S. English text. Dense tables, handwriting, strongly rotated text, and complex multi-column layouts can be incomplete or reordered.
- A selection belongs to the display where the drag begins and clamps at that display's edge. Start another capture to select text on a different display.
- Protected or DRM-restricted content can appear blank or unavailable to screen capture. CopyLasso follows macOS capture restrictions and does not bypass them.
- Immediately reusing capture without moving the pointer can briefly leave the ordinary pointer visible. Moving the pointer or pressing the mouse button restores the crosshair; selection remains functional.
- Locking the Mac during an active drag can leave selection pending after unlock. Quit and reopen CopyLasso before another pointer action; if the retained selection is allowed to complete, the clipboard may change.
- In the rare event that macOS accepts clearing the pasteboard but rejects the subsequent text write, the previous clipboard contents have already been cleared. CopyLasso reports failure and does not read or reconstruct the prior contents.
- Updates are manual in the public 0.1 release line. The first updater-enabled release must be installed manually before later authenticated update checks can begin.

## Build from Source

The app runs on macOS 14 or newer. Reproducing the complete canonical source pipeline requires macOS 26.4 or newer because its final-brand audit invokes Apple's Icon Composer tooling, plus the stable Xcode version documented in [Development Environment](docs/development-environment.md), Swift 6, and the `swift-format` bundled with that Xcode release. An Apple Development identity is required only for signed local UI and privacy-permission testing.

Clone the repository, open `CopyLasso.xcodeproj`, and run the shared `CopyLasso` scheme. To run the same unsigned build, unit-test, offline, repeatability, audit, and Universal 2 Release pipeline used by CI:

```sh
./scripts/ci.sh
```

Architecture and test details are documented in [Architecture Overview](docs/architecture/overview.md), [Testing](docs/testing.md), and [Manual QA and Performance](docs/manual-qa-and-performance.md). The exact shipping KeyboardShortcuts and Sparkle dependencies and licenses are recorded in [Third-Party Notices](THIRD_PARTY_NOTICES.md); the updater trust boundary is recorded in [ADR-004](docs/architecture/ADR-004-secure-updates.md).

## Secure Updates In Current Source

The public CopyLasso 0.1.1 download still updates manually. Current source adds the updater for the first v0.2 release:

- automatic checks default on and run at most once per 24 hours;
- **Settings > Automatically Check for Updates** disables or reenables scheduled checks;
- **Check for Updates…** in Settings or the menu checks immediately;
- the app shows authenticated version, plain-text release notes, and exact download size before any download;
- **Download** begins retrieval, and a separate **Install and Relaunch** confirmation is required after verification; and
- **Later**, **Cancel**, closing the panel, an offline connection, or verification failure leaves the installed app unchanged.

Update checks use only `https://updates.copylasso.com/appcast.xml`, and accepted packages must use the version-matched immutable CopyLasso asset on GitHub Releases. The updater disables system profiling, cookies, external release-note downloads, automatic downloads, and automatic installation. Capture, OCR, clipboard output, Settings, onboarding, and Launch at Login continue to work when update networking is unavailable. G36 creates no public feed or updater-enabled release; those remain separate release gates.

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a change. Report security issues privately according to [SECURITY.md](SECURITY.md).

## Complete Uninstall

These steps remove only CopyLasso's production application, login registration, preferences, sandbox container, and Screen Recording entry. They are destructive for CopyLasso settings and onboarding state.

1. Open CopyLasso Settings, turn off **Launch CopyLasso at Login**, and verify that it reports disabled. Then choose **Quit CopyLasso**.
2. If the app was already removed, disable its entry in **System Settings > General > Login Items & Extensions** before continuing.
3. Move CopyLasso from Applications to the Trash.
4. Run the following commands in Terminal. They target only the production bundle identifier and do not reset other applications:

   ```sh
   defaults delete io.github.bennetthilberg.copylasso 2>/dev/null || true
   rm -rf "$HOME/Library/Containers/io.github.bennetthilberg.copylasso"
   tccutil reset ScreenCapture io.github.bennetthilberg.copylasso
   ```

5. In **System Settings > Privacy & Security > Screen & System Audio Recording**, confirm that CopyLasso is no longer listed. A later reinstall should open first-run setup again.

Do not use broad login-item resets or reset Screen Recording for every application.

## License

CopyLasso is available under the [MIT License](LICENSE). Copyright © 2026 Bennett Hilberg.
