# Contributing to CopyLasso

CopyLasso welcomes focused fixes and improvements. Keep each change small enough
to review and verify as one unit.

## Set up the project

CopyLasso requires macOS, Xcode 26.6, and the Swift tools bundled with Xcode.

1. Clone the repository.
2. Open `CopyLasso.xcodeproj`.
3. Run the shared `CopyLasso` scheme.

Before you submit a change, run:

```sh
./scripts/ci.sh
```

The script formats and builds the app, runs the unit tests and coverage checks,
tests with networking denied, checks repeatability, and builds a Universal 2
Release app.

## Make a change

- Add tests for new behavior and regressions.
- Cover success, failure, cancellation, and boundary cases that your change
  affects.
- Format Swift with `xcrun swift-format`.
- Treat new warnings as errors.
- Update public documentation when behavior, requirements, privacy, or security
  changes.
- Do not commit credentials, signing material, personal captures, recognized
  private text, or other sensitive data.

CopyLasso must not upload or log screenshots, recognized content, clipboard
content, or capture-history entries. It must not persist screenshots. Keep
platform APIs behind narrow interfaces so their behavior remains testable.

## Submit a pull request

Explain what changed, why it changed, how you tested it, and whether it affects
privacy, security, accessibility, or user-visible behavior. Submit green,
cohesive commits and call out any remaining limitation.

Contributions must be original or compatible with the MIT License. By
contributing, you agree that your contribution is licensed under the
repository's [MIT License](LICENSE).
