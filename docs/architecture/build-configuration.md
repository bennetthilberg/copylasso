# Build Configuration

CopyLasso uses one native Xcode project, one shared scheme, and no third-party build system. The committed project is intended to remain understandable in Xcode and reproducible from the command line.

## Targets and Scheme

The shared `CopyLasso` scheme contains:

- `CopyLasso`, the SwiftUI macOS application;
- `CopyLassoTests`, the XCTest unit-test bundle; and
- `CopyLassoUITests`, the XCTest UI-test bundle.

The application is a dockless SwiftUI menu-bar utility. Debug and Release compile the same onboarding, Settings, Launch at Login, global-shortcut, accessibility/appearance, model, service-contract, capture-workflow, production permission, recovery-panel, AppKit selection, ScreenCaptureKit region-capture, Vision OCR, pure text assembly, write-only plain-text clipboard, and nonactivating feedback code.

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
| Agent application (`LSUIElement`) | Enabled |

Release builds explicitly set both macOS architectures and disable `ONLY_ACTIVE_ARCH`. The canonical pipeline inspects the built executable with `lipo`; checking the build setting alone is not sufficient.

`CopyLasso/CopyLasso.entitlements` is the reviewable app entitlement for both configurations. It contains only `com.apple.security.app-sandbox = true`; there is no network, device, file, application-group, or temporary-exception entitlement. `ENABLE_HARDENED_RUNTIME = YES` remains explicit in both configurations. Local Apple Development provisioning adds `get-task-allow` at signing time; the final Developer ID archive must not contain it, and G26 owns that release readback.

There is no source-file exclusion list for experimental code. The G05-G07 executable experiments were retired after their decisions were recorded. The canonical pipeline rejects their former launch arguments plus picker, legacy Core Graphics capture, window-sharing exclusion, and image-persistence APIs. It permits Core Graphics authorization only in `ScreenCapturePermissionService.swift`, selection display/panel/cursor APIs only in `AppKitRegionSelectionService.swift`, ScreenCaptureKit only in `SystemScreenCaptureService.swift`, Vision only in `VisionOCRService.swift`, pasteboard access only in `ClipboardService.swift`, and OSLog only in the fixed-message lifecycle logger; requires `TextAssembler` and its tests to remain free of UI and Vision imports; verifies the silent nonactivating HUD properties, system accessibility profile, high-contrast overlay style, motion-free panels, adaptive feedback sizing, and named compound controls; runs the G22 entitlement, network, persistence, logging, secret, local-path, and dependency audit plus the G23 application/core/per-file coverage audit; enforces model/workflow import boundaries and a payload-free coordinator; requires the G18 lifecycle/stress suite, G19 topology/snapshot suite, G20 interruption/recovery suite, and G21 accessibility/appearance suite; prevents selection from substituting `visibleFrame` for the complete display frame; rejects Debug-only controls in Release; and verifies that every production adapter through lifecycle, accessibility, clipboard, and feedback compiles into both Debug and Release.

Both configurations generate their Info.plist through Xcode and set `LSUIElement` to `YES`. The canonical pipeline checks the build setting and the generated Debug and Release bundles so a normal Dock application cannot be introduced accidentally.

## Swift Package Dependency

KeyboardShortcuts 3.0.1 is an exact Swift Package Manager dependency used for shortcut recording, conflict validation, persistence, and global event delivery. The Xcode project uses an exact-version requirement and commits `Package.resolved` with revision `49c3fc04ea827f816df67843bfcc57286b47ff06`. Its upstream source and MIT license are recorded in [Third-Party Notices](../../THIRD_PARTY_NOTICES.md).

The dependency is confined to the app, Settings, and SwiftUI presentation layers. Models and capture-workflow state remain independent of KeyboardShortcuts, AppKit, SwiftUI, ScreenCaptureKit, and Vision.

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

The script requires Xcode 26.6, starts with clean DerivedData under `.build`, lints Swift, resolves dependencies, builds Debug, builds both test bundles, runs nonparallel timeout-bounded unit tests with explicit coverage, audits reviewed coverage floors, repeats the complete bundle with networking denied, checks required settings, builds Universal 2 Release, and verifies the executable's two architecture slices. GitHub runs that pipeline on macOS 26 arm64 and Intel, then launches the exact Release artifact on a macOS 14 arm64 runner.

Execute UI tests through Xcode with runnable local signing. The unsigned CI command intentionally does not launch them.
