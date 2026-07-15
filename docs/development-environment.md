# CopyLasso Development Environment

This document records the verified native macOS toolchain for CopyLasso and the non-secret steps required to reproduce it. Update the version snapshot whenever the project deliberately moves to a newer stable Xcode release.

## Verified Snapshot

Verified July 9, 2026 on the maintainer workstation:

| Component | Verified value |
| --- | --- |
| Host architecture | Apple Silicon (`arm64`) |
| macOS | 26.5.1 (`25F80`) |
| Xcode | 26.6 (`17F113`) |
| Active developer directory | `/Applications/Xcode.app/Contents/Developer` |
| Swift | 6.3.3 |
| Bundled `swift-format` | 6.3.0 |
| Git | 2.50.1 (Apple Git-155) |

Apple's current [Xcode support matrix](https://developer.apple.com/support/xcode/) lists Xcode 26.6 as the latest stable release; Xcode 27 is still a beta and is not the project baseline.

CopyLasso targets macOS 14 or newer and produces a Universal 2 Release application containing `arm64` and `x86_64`. The project, shared scheme, and enforced settings are documented in [Build Configuration](architecture/build-configuration.md).

## Xcode Setup

1. Install the latest stable full Xcode release available to the maintainer.
2. Open Xcode once, accept its license, and allow required first-launch components to finish.
3. Select the full Xcode developer directory rather than standalone Command Line Tools:

   ```sh
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   ```

4. In **Xcode > Settings > Apple Accounts**, sign in with the maintainer's Apple Account and select the active developer team.
5. In the team view, open **Manage Certificates** and ensure an **Apple Development** certificate is present.
6. In Keychain Access, verify that the certificate is paired with its private key and reports that it is valid.

Never copy an Apple Account address, team identifier, certificate serial number, private key, password, or authentication token into the repository or public build logs.

## Apple Development Trust Chain

Apple Development certificates are issued through an Apple Worldwide Developer Relations intermediate certificate. Apple identifies Worldwide Developer Relations G3 as the intermediate for Apple Development and other software-signing certificates. See Apple's [WWDR intermediate certificate guide](https://developer.apple.com/help/account/certificates/wwdr-intermediate-certificates) and [Apple PKI repository](https://www.apple.com/certificateauthority/).

Eligible Xcode versions normally install the required intermediate automatically. If a newly created Apple Development certificate is paired with its private key but Keychain Access reports that it is not trusted, first check whether the machine has only the expired 2013–2023 WWDR intermediate. Install the current G3 public intermediate directly from Apple:

```sh
certificate_file="$(mktemp)"
curl -fsSL https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer \
  -o "$certificate_file"

openssl x509 -in "$certificate_file" -inform DER -noout -subject -issuer -dates
security add-certificates \
  -k "$HOME/Library/Keychains/login.keychain-db" \
  "$certificate_file"

rm -f "$certificate_file"
```

Before installing it, confirm that the downloaded certificate is the Apple Worldwide Developer Relations G3 intermediate, is issued by Apple Root CA, and is currently valid. This is a public intermediate certificate, not a signing private key.

Do not export or commit the Apple Development identity. If the certificate or private key is replaced later, verify the new identity before relying on privacy-permission continuity between development builds.

## Local Project Signing

The tracked `Configuration/Shared.xcconfig` optionally includes an ignored `Local.xcconfig`. Start from the empty example:

```sh
cp Local.xcconfig.example Local.xcconfig
```

For normal automatic development signing, set `DEVELOPMENT_TEAM` in the ignored file. Do not print that value into shared logs. Contributors who only need to run the current scaffold may use local ad hoc signing as documented in [Build Configuration](architecture/build-configuration.md); permission-dependent development requires a stable Apple Development identity.

An authorization dialog from `codesign` requests the password of the named keychain, which may differ from the current macOS login password if that password changed without updating the keychain. Do not repeatedly enter credentials, reset a keychain, or delete signing material merely to run the scaffold. Stop the build and use the documented ad hoc configuration until the keychain can be repaired intentionally.

## Git Identity

Git must have an intentional maintainer identity before creating commits. It may be configured globally or for this repository. Check presence without printing private values into shared logs:

```sh
if git config --get user.name >/dev/null && \
   git config --get user.email >/dev/null; then
  echo "Git identity is configured"
else
  echo "Git identity is incomplete"
  exit 1
fi
```

Do not replace the maintainer's Git identity with a generic automation identity unless the maintainer explicitly requests that change.

## Canonical Toolchain Verification

Run these checks from the repository root:

```sh
xcodebuild -version
xcrun swift --version
xcrun swift-format --version
xcode-select -p
xcodebuild -license check
xcodebuild -checkFirstLaunchStatus
git --version
```

Expected results:

- `xcodebuild -version` reports the full selected Xcode release.
- `xcrun swift --version` and `xcrun swift-format --version` succeed through the selected Xcode toolchain.
- `xcode-select -p` prints `/Applications/Xcode.app/Contents/Developer`.
- The license and first-launch checks exit successfully.
- Git reports an available Apple-provided version and the identity-presence check above succeeds.

Check signing availability without copying identity details into logs:

```sh
if security find-identity -v -p codesigning 2>/dev/null | \
   /usr/bin/grep -q "Apple Development"; then
  echo "Apple Development identity is valid and available"
else
  echo "Apple Development identity is unavailable"
  exit 1
fi
```

The verified G01 environment has one valid Apple Development identity. The certificate and paired private key remain in the login keychain and are not repository artifacts.

## Project Build and Test

CopyLasso's runtime minimum is macOS 14. Reproducing the complete canonical source pipeline requires a macOS 26.4-or-newer development host because the final-brand audit invokes Icon Composer's `ictool`; the verified baseline above uses macOS 26.5.1 and Xcode 26.6.

The canonical local and GitHub Actions entrypoint is:

```sh
./scripts/ci.sh
```

Run the source privacy, security, entitlement, dependency, and secret audit independently with:

```sh
./scripts/audit-privacy-security.sh
```

The canonical run enforces the reviewed behavioral-coverage gate and repeats the already-built complete unit bundle three additional times. Re-run either check independently with:

```sh
./scripts/audit-coverage.sh .build/ci-$(uname -m)/UnitTests.xcresult
./scripts/test-repeatability.sh
```

The canonical entrypoint verifies its own CI contract, runs the privacy/security and coverage audits, selects clean DerivedData under `.build`, verifies Xcode 26.6, lints Swift sources, resolves packages, builds Debug, builds the unit and UI test bundles, runs timeout-bounded nonparallel unit tests, repeats that already-built unit bundle with networking denied and then in three deterministic passes, asserts required settings, builds Universal 2 Release, and verifies both binary slices. It disables code signing and never launches the unsigned UI-test runner. See [Automated Coverage Review](coverage-review.md) for the baseline, per-file floors, and every justified uncovered region.

For interactive verification, open `CopyLasso.xcodeproj`, select the shared `CopyLasso` scheme and **My Mac**, then use:

- **Product > Build** (`Command-B`) for Debug;
- **Product > Run** (`Command-R`) for the dockless menu-bar shell; and
- **Product > Test** (`Command-U`) for the unit and UI suites.

Interactive Run and UI testing require runnable local signing. Keep any team or identity override in ignored `Local.xcconfig`.

## Architecture Baseline

The G05-G07 executable feasibility harnesses were retired after their evidence was recorded. Their former launch arguments are no longer supported. Both Debug and Release contain the production AppKit selection overlay, ScreenCaptureKit region capture, local Vision OCR, pure text assembly, write-only plain-text clipboard output, and nonactivating HUD feedback.

The application target contains the dockless menu-bar shell, production-neutral models and service contracts, live permission and selection adapters, actor-isolated production region capture, production Vision OCR, deterministic text assembly, and the output adapters. Capture Text validates a selected display, captures only after overlays are absent, recognizes the in-memory image away from the main actor, produces a transient plain string, writes nonempty text to the general pasteboard, and presents bounded feedback without activation. See [Architecture Overview](architecture/overview.md) for dependency and actor boundaries, [Capture Workflow](architecture/capture-workflow.md) for the complete operation and lifetime contract, [Plain-Text Assembly](architecture/text-assembly.md) for ordering rules, [Clipboard and Feedback](architecture/clipboard-and-feedback.md) for output privacy/lifetime rules, [Security and Privacy Review](security-and-privacy-review.md) for entitlements, trust boundaries, and dependency evidence, [Testing](testing.md) for signed matrices, [ADR-001](architecture/ADR-001-vision-ocr.md) for OCR evidence, [ADR-002](architecture/ADR-002-screen-capture.md) for permission and capture evidence, and [ADR-003](architecture/ADR-003-selection-overlay.md) for selection and coordinate evidence.

## GitHub Actions

`.github/workflows/ci.yml` runs for pull requests targeting `main` and pushes to `main`. It explicitly selects Xcode 26.6 and executes `scripts/ci.sh`, including its three-pass repeatability gate, on GitHub-hosted macOS 26 Apple Silicon and Intel runner images. The arm64 job transfers its exact Universal 2 Release artifact to a separate GitHub-hosted macOS 14 arm64 job, which verifies macOS 14.0 deployment metadata, ad-hoc signs the app on that host, and proves a clean process launch without invoking protected resources. The workflow has read-only repository contents permission, persists no checkout credential, uses no secrets or cache, and bounds concurrent runs, artifact retention, and job duration.

The matrix reports `build and test (arm64)`, `build and test (x86_64)`, and `minimum OS runtime (macOS 14 arm64)`. Branch protection must require the minimum-OS context after this workflow reaches `main`; adding it earlier would make predecessor PRs that cannot emit the new context unmergeable. Maintainers can apply the temporary `ci-failure-probe` label to a pull request to compile a controlled unit-test failure into both build jobs. Removing the label restores all checks at the same commit. Delete the temporary repository label after verifying both transitions.

The pinned KeyboardShortcuts 3.0.1 manifest requires Swift tools 6.2, while GitHub's macOS 14 image offers Xcode 16.2 at most. Source compilation on that image would test an unsupported toolchain rather than the product's runtime contract, so the minimum-OS job deliberately executes the Xcode 26.6 artifact. GitHub began deprecating hosted macOS 14 images on July 6, 2026 and has announced removal on November 2, 2026. Before that date, migrate this smoke to a maintained macOS 14 runner or VM; do not silently remove the gate.

## Tooling Policy

- G01 introduces no Homebrew-only build dependency.
- Use the `swift-format` bundled with the selected stable Xcode through `xcrun swift-format`.
- Add external build tools only when a later approved goal has a concrete need and records the version, source, purpose, and license.
- Keep generated build output, archives, exported applications, signing material, and credentials out of Git.

## Current Boundary

The repository contains a buildable dockless menu-bar app with onboarding, persistent Settings, Launch at Login, a configurable global shortcut, accessible native presentation, production permission recovery, multi-display selection, in-memory ScreenCaptureKit capture, local Vision OCR, pure text assembly, write-only clipboard output, nonactivating feedback, root-owned sleep/lock/termination recovery, service test doubles, and retained feasibility evidence. The shortcut and menu enter the same complete production chain. Uniform cancellation, stage-specific error feedback, busy rejection before feedback, capture-independent HUD timers with immediate replacement, terminal recovery, 25-success and 20-alternating-cycle stress tests, operation-scoped cleanup, a seven-layout 1×/1.5×/2× display-snapshot matrix, lifecycle cancellation gates, selection-only focus restoration, and deterministic accessibility/appearance contracts are part of the 214-test canonical suite. Reviewed coverage floors, three-pass repeatability, and latest/minimum-OS CI are release gates. Physical end-to-end, VoiceOver/appearance, and environmental hardening remain documented in the later manual matrices.

Normal Debug and Release runs use production selection and capture. Signed UI tests keep menu/settings coverage deterministic with Debug-only selection and capture doubles. Add `--g13-live-selection` to exercise the real overlay with controlled permission and in-memory capture; add `--g14-live-capture` only for an explicitly manual real ScreenCaptureKit run. Both controls and doubles are compiled out of Release.

For a development-only clean first-run state, open Settings and choose **Reset Local Development State…**. After confirmation, CopyLasso unregisters its login item and clears its owned preferences and shortcut data before reopening onboarding. This does not reset Screen Recording permission.

Reset the Debug bundle's macOS permission separately only when running the controlled matrix:

```sh
/usr/bin/tccutil reset ScreenCapture io.github.bennetthilberg.copylasso.debug
```

The complete order, expected observations, focus checks, and lifecycle matrix are documented in [Testing](testing.md). See [Lifecycle and Recovery](architecture/lifecycle-and-recovery.md) for observer, cancellation, and diagnostic boundaries. Use a stably signed Debug build so a rebuild does not create misleading permission churn.

Launch at Login uses `SMAppService.mainApp` and therefore requires a runnable signed app for real verification. The automated unit suite covers status mapping, failure handling, and reconciliation with doubles; final local verification must still enable the real item, log out and back in or reboot, confirm the dockless process starts, then disable it and repeat.
