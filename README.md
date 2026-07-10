# CopyLasso

[![CI](https://github.com/bennetthilberg/copylasso/actions/workflows/ci.yml/badge.svg)](https://github.com/bennetthilberg/copylasso/actions/workflows/ci.yml)

CopyLasso is a free, open-source macOS utility for copying visible text from anywhere on screen. Press a global shortcut, drag around text, and receive the recognized plain text on the clipboard.

> **Project status:** CopyLasso is in early pre-release development. The repository contains a buildable placeholder application plus successful internal OCR and screen-capture feasibility experiments, but production capture, the OCR workflow, and the intended menu-bar experience are not implemented, and no public release is available.

## Planned v0.1 Experience

- Capture text from screen pixels in any application, including images and video.
- Perform OCR entirely on the Mac with Apple's Vision framework.
- Copy recognized plain text without retaining a screenshot or OCR history.
- Start capture from a configurable global shortcut or menu-bar command.
- Run as a native Universal 2 app on macOS 14 or newer.

The initial release targets ordinary, approximately horizontal, single-column English text. Protected or DRM-restricted content may not be capturable because CopyLasso follows macOS screen-capture restrictions.

## Privacy

CopyLasso is designed to keep captured images and recognized text local, in memory, and only for as long as the active operation needs them. v0.1 has no accounts, cloud OCR, analytics, telemetry, or capture history. Core OCR does not require a network connection.

See the full [privacy policy](PRIVACY.md) and [v0.1 product contract](docs/v0.1-product-contract.md) for the approved guarantees and limitations.

## Development Requirements

- A Mac running macOS 14 or newer
- The latest stable full Xcode release selected by the project
- Swift 6 and the `swift-format` version bundled with that Xcode release
- An Apple Development signing identity for signed local builds

The current verified baseline is Xcode 26.6 with Swift 6.3.3. See [Development Environment](docs/development-environment.md) for setup and canonical commands, and [Build Configuration](docs/architecture/build-configuration.md) for target and signing decisions.

Run the same unsigned build and unit-test pipeline used by CI:

```sh
./scripts/ci.sh
```

The shared Xcode scheme also builds and runs the placeholder locally. UI tests require runnable local signing; CI builds their bundle without launching the unsigned runner.

## Contributing

CopyLasso is under active development. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before proposing a change. Security issues should be reported privately according to [SECURITY.md](SECURITY.md).

## License

CopyLasso is available under the [MIT License](LICENSE). Copyright 2026 Bennett Hilberg.
