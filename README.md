# CopyLasso

[![CI](https://github.com/bennetthilberg/copylasso/actions/workflows/ci.yml/badge.svg)](https://github.com/bennetthilberg/copylasso/actions/workflows/ci.yml)

CopyLasso is a free, open-source macOS utility for copying visible text from anywhere on screen. Press a global shortcut, drag around text, and receive the recognized plain text on the clipboard.

> **Project status:** CopyLasso is in early pre-release development. The dockless app now includes first-run setup, persistent native Settings, explicit Launch at Login control, a configurable global shortcut, accessibility-aware native presentation, and one production workflow from Screen Recording permission through multi-display selection, display-snapshot-validated in-memory capture, local OCR, deterministic plain-text assembly, clipboard output, and nonactivating feedback. Signed QA has passed many functional and OCR paths plus the idle-CPU threshold, and a focused signed follow-up fixed the physical sleep/wake selection cleanup failure. A complete clean G24 rerun is still pending, including Sidecar-only display checks, interactive cold-launch timing, several phase-specific privacy/performance rows, and the remaining live accessibility/appearance qualification. No public release is available.

## Planned v0.1 Experience

- Capture text from screen pixels in any application, including images and video.
- Perform OCR entirely on the Mac with Apple's Vision framework.
- Copy recognized plain text without retaining a screenshot or OCR history.
- Start capture from a configurable global shortcut or menu-bar command.
- Run as a native Universal 2 app on macOS 14 or newer.

The initial release targets ordinary, approximately horizontal, single-column English text. Protected or DRM-restricted content may not be capturable because CopyLasso follows macOS screen-capture restrictions.

## Privacy

CopyLasso is designed to keep captured images and recognized text local, in memory, and only for as long as the active operation needs them. v0.1 has no accounts, cloud OCR, analytics, telemetry, capture history, network-client entitlement, or automatic updater. Core OCR does not require a network connection.

See the full [privacy policy](PRIVACY.md), [security and privacy review](docs/security-and-privacy-review.md), and [v0.1 product contract](docs/v0.1-product-contract.md) for the approved guarantees, implementation boundaries, and limitations.

## Development Requirements

- A Mac running macOS 14 or newer
- The latest stable full Xcode release selected by the project
- Swift 6 and the `swift-format` version bundled with that Xcode release
- An Apple Development signing identity for signed local builds

The current verified baseline is Xcode 26.6 with Swift 6.3.3. See [Architecture Overview](docs/architecture/overview.md), [Capture Workflow](docs/architecture/capture-workflow.md), and [Accessibility and Appearance](docs/architecture/accessibility-and-appearance.md) for component and presentation boundaries, [Development Environment](docs/development-environment.md) for setup and canonical commands, [Testing](docs/testing.md) for automated and signed matrices, [Automated Coverage Review](docs/coverage-review.md) for reviewed gaps and regression floors, [Manual QA and Performance](docs/manual-qa-and-performance.md) for release qualification, and [Build Configuration](docs/architecture/build-configuration.md) for target and signing decisions.

Run the same unsigned build and unit-test pipeline used by CI:

```sh
./scripts/ci.sh
```

The shared Xcode scheme also builds and runs the current menu-bar application locally. UI tests require runnable local signing; CI builds their bundle without launching the unsigned runner. The exact KeyboardShortcuts dependency and license are recorded in [Third-Party Notices](THIRD_PARTY_NOTICES.md).

## Contributing

CopyLasso is under active development. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before proposing a change. Security issues should be reported privately according to [SECURITY.md](SECURITY.md).

## License

CopyLasso is available under the [MIT License](LICENSE). Copyright 2026 Bennett Hilberg.
