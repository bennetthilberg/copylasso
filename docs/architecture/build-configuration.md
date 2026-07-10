# Build Configuration

CopyLasso uses one native Xcode project, one shared scheme, and no third-party build system. The committed project is intended to remain understandable in Xcode and reproducible from the command line.

## Targets and Scheme

The shared `CopyLasso` scheme contains:

- `CopyLasso`, the SwiftUI macOS application;
- `CopyLassoTests`, the XCTest unit-test bundle; and
- `CopyLassoUITests`, the XCTest UI-test bundle.

The normal application currently presents only a placeholder window. Debug builds also contain internal OCR, screen-capture, and selection-overlay feasibility experiments; they are not production flows. Menu-bar behavior, global shortcuts, user-facing capture, onboarding, settings, and login-at-launch behavior remain unimplemented.

## Supported Configuration

| Setting | Value |
| --- | --- |
| Deployment target | macOS 14.0 |
| Swift language mode | Swift 6 |
| Concurrency checking | Complete |
| Warnings | Treated as errors |
| Debug bundle identifier | `io.github.bennetthilberg.copylasso.debug` |
| Release bundle identifier | `io.github.bennetthilberg.copylasso` |
| Marketing version | `0.1.0` |
| Build number | `1` |
| Release architectures | `arm64`, `x86_64` |
| App Sandbox | Enabled |
| Hardened Runtime | Enabled |

Release builds explicitly set both macOS architectures and disable `ONLY_ACTIVE_ARCH`. The canonical pipeline inspects the built executable with `lipo`; checking the build setting alone is not sufficient.

The G06 screen-capture sources and G07 selection-overlay sources are explicitly excluded from the Release target. The canonical pipeline also inspects both compiled Release modules and fails if either Debug-only model is present.

## Signing

`Configuration/Shared.xcconfig` is the tracked, non-secret configuration include. It defaults to automatic signing and optionally loads the ignored root-level `Local.xcconfig`.

Create local signing configuration from the empty example:

```sh
cp Local.xcconfig.example Local.xcconfig
```

Set only non-exportable identifiers or build-setting selections in that ignored file. Never commit an Apple account, team identifier, certificate fingerprint, private key, password, or token. A normal Apple Developer setup needs only:

```xcconfig
DEVELOPMENT_TEAM =
```

Enter the team identifier after the equals sign only in the ignored local copy.

For scaffold development on a Mac without an available unlocked development identity, local ad hoc signing can make test runners executable without accessing Keychain:

```xcconfig
DEVELOPMENT_TEAM =
CODE_SIGN_STYLE = Manual
CODE_SIGN_IDENTITY = -
```

Ad hoc signing is not suitable for distribution and does not provide stable identity for privacy-permission continuity. Use a real local development identity before implementing or manually verifying permission-dependent behavior.

GitHub Actions passes `CODE_SIGNING_ALLOWED=NO`. CI executes unit tests only; it builds the UI-test bundle to catch compile and linkage failures but does not launch the unsigned UI-test runner.

## Canonical Commands

Run the complete local equivalent of CI from the repository root:

```sh
./scripts/ci.sh
```

The script requires Xcode 26.6, starts with clean DerivedData under `.build`, lints Swift, resolves dependencies, builds Debug, builds both test bundles, runs unit tests, checks required settings, builds Universal 2 Release, and verifies the executable's two architecture slices.

Execute UI tests through Xcode with runnable local signing. The unsigned CI command intentionally does not launch them.
