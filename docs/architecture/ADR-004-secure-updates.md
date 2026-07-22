# ADR-004: Sparkle Provides the Secure Update Boundary

- **Status:** Accepted for G36 implementation
- **Date:** July 22, 2026
- **Scope:** G35 architecture proof only; no updater ships in this goal

## Context

CopyLasso 0.2 must check for updates about once per day, let the user defer or
disable checks, show authenticated update details before a download begins, and
install only a verified replacement. The app is sandboxed, dockless, and
distributed outside the Mac App Store. G35 must select and prove an architecture
without adding a public feed, a production signing secret, an update UI, or a
shipping updater framework.

The proof pins [Sparkle 2.9.4](https://github.com/sparkle-project/Sparkle/releases/tag/2.9.4)
at source revision `b6496a74a087257ef5e6da1c5b29a447a60f5bd7`. Its official Swift Package
artifact has SHA-256
`cb6fdbdc8884f15d62a616e79face92b08322410fd2d425edc6596ccbf4ba3b0`.
That release was published July 3, 2026, includes a dockless-application update
UI fix, and its macOS framework contains both `arm64` and `x86_64` slices.
Sparkle is linked only into `CopyLassoTests` in G35 so the production app,
entitlements, release bytes, and third-party notices remain unchanged.

## Options

| Criterion | Sparkle 2.9.4 | First-party updater |
| --- | --- | --- |
| Feed and archive authentication | Ed25519 appcast and archive verification with maintained tools | New canonicalization, signing, parsing, and rotation code to design and audit |
| Sandboxed installation | Documented installer services and hardened-runtime integration | New privileged/helper lifecycle and replacement transaction |
| macOS 14 and Universal 2 | Pinned artifact supports macOS 10.15+ and contains `arm64` plus `x86_64` | Every helper, installer, and transaction must be built and qualified twice |
| Failure recovery | Mature download, extraction, install, relaunch, and error paths | New interruption, disk-full, rollback, cleanup, and relaunch state machine |
| User control | Scheduled and user-initiated drivers, deferral, cancellation, progress | Every state and accessible surface must be built from scratch |
| Maintenance and license | Active, permissive [license bundle](https://github.com/sparkle-project/Sparkle/blob/2.9.4/LICENSE); one pinned dependency | No dependency, but CopyLasso permanently owns a large security-sensitive subsystem |
| Small dockless app fit | 2.9.4 specifically fixes dockless app activation during update UI | Unknown until independently implemented and qualified |

## Decision

Use Sparkle 2.9.4 for update retrieval, Ed25519 verification, staging,
installation, and relaunch. Building the equivalent first-party subsystem would
create substantially more security-critical code without improving the product's
privacy contract.

G36 will integrate `SPUUpdater` with a small CopyLasso-owned `SPUUserDriver` and
an updater delegate behind a narrow application boundary. The custom driver is
required because Sparkle's standard alert does not expose the enclosure size
until download progress begins, while the v0.2 contract requires version,
release notes, file size, and install/relaunch consequences before the user
explicitly starts the transaction. Sparkle remains responsible for all security
and installation work; CopyLasso owns only presentation, consent, focus, and
retention policy.

The future fixed feed URL is
`https://updates.copylasso.com/appcast.xml`. Enclosures must use immutable URLs
of the form
`https://github.com/bennetthilberg/copylasso/releases/download/<tag>/CopyLasso-<version>.dmg`.
G35 neither publishes nor requests either endpoint.

G36 will use these non-secret settings:

- `SUFeedURL = https://updates.copylasso.com/appcast.xml` and the reviewed
  `SUPublicEDKey` value created in G36;
- `SUEnableAutomaticChecks = YES` and a 24-hour interval;
- `SUScheduledCheckInterval = 86400`;
- `SUAutomaticallyUpdate = NO` and `SUAllowsAutomaticUpdates = NO`;
- `SUEnableSystemProfiling = NO`;
- `SUVerifyUpdateBeforeExtraction = YES`;
- `SURequireSignedFeed = YES`;
- `SUSignedFeedFailureExpirationInterval = 0`; and
- `SUEnableInstallerLauncherService = YES`, without the downloader service.

The app will add `com.apple.security.network.client` and one
`com.apple.security.temporary-exception.mach-lookup.global-name` array containing
exactly `$(PRODUCT_BUNDLE_IDENTIFIER)-spks` and
`$(PRODUCT_BUNDLE_IDENTIFIER)-spki`, as required by Sparkle's sandboxed
installer. CopyLasso will not enable `SUEnableDownloaderService`; the pinned
prebuilt downloader is unsandboxed by default and unnecessary when the app has
outbound network access. Because the network client entitlement is not
host-scoped, a static audit will lock the sole feed URL and reject custom request
headers, cookies, delegate-supplied query parameters, system profiling, or other
runtime networking.

## Verified Policy

The G35 proof uses Sparkle's real `SUStandardVersionComparator`, real
`sign_update` tooling, and deterministic transaction policy tests.

- `CFBundleVersion` is the ordering authority and must be a canonical positive
  ASCII decimal integer of at most 18 digits; display version must match the
  authenticated archive metadata.
- An update must be strictly newer than the installed build and not lower than
  the highest authenticated build previously observed. Lower values fail closed
  as downgrade or replay attempts.
- The feed and enclosure must both authenticate, declared and downloaded sizes
  must match, and an enclosure must be 1 byte through 256 MiB. This conservative
  ceiling is far above current CopyLasso packages while bounding disk and parser
  exposure.
- Only the fixed HTTPS GitHub Releases owner, repository, tag path, DMG naming,
  and a URL without user info, port, query, or fragment are accepted.
- Offline, timeout, malformed feed, invalid signature, cancellation, disk-full,
  and interruption paths remove staging and preserve the installed build.
- Installation commits only after a verified download and explicit final user
  confirmation. Deferral leaves the current application untouched.

The fixture creates a fresh test-only Ed25519 key in a temporary directory,
signs and verifies an archive and appcast with Sparkle's shipped tools while
network access is denied, rejects mutations inside the signed feed bytes,
archive tampering, and a second key, then destroys all fixture material.
Sparkle's signed-feed envelope authenticates an explicit content length and
parses only those verified bytes; data appended after that envelope cannot alter
the authenticated appcast. No production key or public feed exists in G35.

## Consequences

Sparkle 2.9.4 becomes a reviewed test-only package dependency in G35 and a
planned shipping dependency in G36. Before G36 may link it into CopyLasso, the
production key, sandbox services, UI behavior, acknowledgements, privacy copy,
release workflow, and rollback record must satisfy
[`secure-update-operations.md`](../secure-update-operations.md) and
[`secure-update-threat-model.md`](../secure-update-threat-model.md).

Users on 0.1.x have no updater and must install the first updater-enabled release
manually from the existing authenticated GitHub release channel. Automatic
updates can begin only after that bootstrap.
