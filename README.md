# CopyLasso

[![CI](https://github.com/bennetthilberg/copylasso/actions/workflows/ci.yml/badge.svg)](https://github.com/bennetthilberg/copylasso/actions/workflows/ci.yml)

CopyLasso is a free and open-source macOS utility for copying visible text from anywhere on screen. Press `⇧⌘2`, drag around text, and receive recognized plain text on the clipboard. Recognition runs locally with Apple's Vision framework, and CopyLasso does not retain a screenshot or OCR history.

> **Pre-release status:** Version 0.1.0 is being prepared and is not available for public download yet. This page previews the installation and usage flow that the signed, notarized release will provide.

## Requirements

- macOS 14 or newer
- An Apple silicon or Intel Mac; the release is a native Universal 2 application
- Screen Recording permission for region capture

## Installation Preview

The public release will be distributed as a signed and notarized disk image from this repository's GitHub Releases page. When it is published:

1. Download `CopyLasso-0.1.0.dmg` and compare its SHA-256 checksum with the value on the release page.
2. Open the disk image and drag CopyLasso into Applications.
3. Open CopyLasso. It runs in the menu bar and does not add a Dock icon.
4. Complete the short first-run setup and keep the suggested `⇧⌘2` shortcut or record another one.
5. The first capture asks macOS for Screen Recording permission. Approve CopyLasso, then choose **Quit & Reopen** if macOS offers it.

No unsigned download or placeholder release link is provided before the qualified artifact is published.

## Use CopyLasso

1. Press `⇧⌘2`, or choose **Capture Text** from the CopyLasso menu-bar menu.
2. Drag around text on one display. Press `Esc` to cancel without changing the clipboard.
3. CopyLasso captures only the selected region, recognizes English text locally, and writes the assembled plain text to the clipboard.
4. A short, nonactivating HUD reports copied text, no text found, a busy request, or a recoverable failure.

Open **Settings…** from the menu to change or clear the shortcut, enable Launch at Login, review privacy information, or reopen first-run setup when it is incomplete.

## Permission and Recovery

Screen Recording is the only macOS privacy permission required for core capture. CopyLasso does not require Accessibility, Input Monitoring, microphone, camera, location, contacts, or network access.

If capture access is unavailable, CopyLasso shows a recovery window with a direct route to **System Settings > Privacy & Security > Screen & System Audio Recording**. Enable CopyLasso, quit and reopen it when macOS requests that transition, and then choose **Try Again**. Denial and unavailable-access paths preserve the clipboard.

## Privacy

CopyLasso is private, offline, and local by design:

- Captured pixels and unbounded recognized text stay in memory only for the active operation.
- Screenshots, OCR results, clipboard history, and HUD previews are never logged, persisted, or transmitted.
- The application has no accounts, analytics, telemetry, cloud OCR, automatic updater, or network-client implementation.
- Clipboard access is write-only and plain-text-only. CopyLasso never reads the existing clipboard to preserve or restore its contents.

See the [privacy policy](PRIVACY.md), [security and privacy review](docs/security-and-privacy-review.md), and [v0.1 product contract](docs/v0.1-product-contract.md) for the reviewed guarantees and boundaries.

## Known Limitations

- Version 0.1 targets ordinary, approximately horizontal, single-column U.S. English text. Dense tables, handwriting, strongly rotated text, and complex multi-column layouts can be incomplete or reordered.
- A selection belongs to the display where the drag begins and clamps at that display's edge. Start another capture to select text on a different display.
- Protected or DRM-restricted content can appear blank or unavailable to screen capture. CopyLasso follows macOS capture restrictions and does not bypass them.
- Immediately reusing capture without moving the pointer can briefly leave the ordinary pointer visible. Moving the pointer or pressing the mouse button restores the crosshair; selection remains functional.
- Locking the Mac during an active drag is a narrow recovery edge case. After unlocking, quit and reopen CopyLasso before the next capture if selection does not return to idle.
- In the rare event that macOS accepts clearing the pasteboard but rejects the subsequent text write, the previous clipboard contents have already been cleared. CopyLasso reports failure and does not read or reconstruct the prior contents.
- Updates are manual in version 0.1.

## Build from Source

Development requires macOS 14 or newer, the stable Xcode version documented in [Development Environment](docs/development-environment.md), Swift 6, and the `swift-format` bundled with that Xcode release. An Apple Development identity is required only for signed local UI and privacy-permission testing.

Clone the repository, open `CopyLasso.xcodeproj`, and run the shared `CopyLasso` scheme. To run the same unsigned build, unit-test, offline, repeatability, audit, and Universal 2 Release pipeline used by CI:

```sh
./scripts/ci.sh
```

Architecture and test details are documented in [Architecture Overview](docs/architecture/overview.md), [Testing](docs/testing.md), and [Manual QA and Performance](docs/manual-qa-and-performance.md). The exact KeyboardShortcuts dependency and license are recorded in [Third-Party Notices](THIRD_PARTY_NOTICES.md).

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
