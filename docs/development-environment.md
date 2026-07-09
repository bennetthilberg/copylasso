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

CopyLasso itself targets macOS 14 or newer and will produce a Universal 2 Release application containing `arm64` and `x86_64`. Those project build settings are established and tested in later roadmap goals; G01 verifies only the development environment.

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

## Canonical Verification

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

## Tooling Policy

- G01 introduces no Homebrew-only build dependency.
- Use the `swift-format` bundled with the selected stable Xcode through `xcrun swift-format`.
- Add external build tools only when a later approved goal has a concrete need and records the version, source, purpose, and license.
- Keep generated build output, archives, exported applications, signing material, and credentials out of Git.

## G01 Boundary

This environment setup intentionally creates no Xcode project, application source, entitlement, dependency, or build artifact. The project scaffold begins in G03 after the repository foundation in G02 is complete.
