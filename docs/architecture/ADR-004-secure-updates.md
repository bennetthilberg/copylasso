# ADR-004: Sparkle Provides the Secure Update Boundary

- **Status:** Implemented by G36
- **Date:** July 22, 2026
- **Scope:** G35 architecture proof and G36 shipping integration; no public feed or release in G36

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
G35 linked Sparkle only into `CopyLassoTests` for the architecture proof. G36
links the same reviewed package into the application, ships its complete license
notice, and adds only the sandbox capabilities required by the selected
installer boundary.

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

G36 integrates `SPUUpdater` with a small CopyLasso-owned `SPUUserDriver` and
an updater delegate behind a narrow application boundary. The custom driver is
required because Sparkle's standard alert does not expose the enclosure size
until download progress begins, while the v0.2 contract requires version,
release notes, file size, and install/relaunch consequences before the user
explicitly starts the transaction. Sparkle remains responsible for all security
and installation work; CopyLasso owns only presentation, consent, focus, and
retention policy.

The fixed feed URL compiled into the updater-enabled source is
`https://updates.copylasso.com/appcast.xml`. Enclosures must use immutable URLs
of the form
`https://github.com/bennetthilberg/copylasso/releases/download/<tag>/CopyLasso-<version>.dmg`.
G36 does not publish or request either endpoint during development qualification;
DNS and public appcast publication remain a separate release gate.

Release notes must be nonempty inline plain text in the signed appcast. G36
rejects `releaseNotesURL`, `fullReleaseNotesURL`, HTML descriptions, and missing
notes before presenting update consent, and its updater delegate returns false
from `updater:shouldDownloadReleaseNotesForUpdate:`. This keeps the text shown
to the user inside the authenticated feed envelope and prevents a second
content or network origin from entering the update flow.

[GitHub's release-asset API](https://docs.github.com/en/rest/releases/assets#get-a-release-asset)
documents that an asset request may return the bytes directly or redirect the
client. Sparkle 2.9.4 constructs the initial enclosure request from
`SUAppcastItem.fileURL`, exposes that request through
`updater:willDownloadUpdate:withRequest:`, and then downloads it with an
internal `NSURLSession`. Its public API exposes no per-redirect decision hook;
the session therefore follows ordinary HTTPS redirects. G36 must validate the
exact initial enclosure URL from the `SUAppcastItem` passed to
`SPUUserDriver.showUpdateFound` before returning the Install choice that begins
the download, but it must not claim that CopyLasso can enforce a
destination-host or redirect-count allowlist through Sparkle's supported API.
Every response body remains untrusted until the signed enclosure length and
Ed25519 signature pass, followed by Developer ID, notarization, version, and
architecture checks. If redirect-level policy becomes a requirement, the
architecture must be amended before shipping rather than relying on an
unconnected policy helper or Sparkle private API.

G36 uses these non-secret settings:

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

The signed-feed expiration spelling above is locked to the pinned 2.9.4 source:
`SUConstants.m` maps `SUSignedFeedFailureExpirationIntervalKey` to that exact
Info.plist key, and `SUAppcastDriver.m` treats zero as never recovering from a
failed feed signature.

With automatic downloads disabled, the custom user driver receives
`showDownloadInitiatedWithCancellation:` before bytes arrive. It retains that
cancellation closure only for the active transaction, verifies every
`showDownloadDidReceiveExpectedContentLength:` value against the signed length
and 256 MiB ceiling, and sums each
`showDownloadDidReceiveDataOfLength:` delta with overflow checking. The first
callback that would exceed either boundary invokes cancellation exactly once,
removes staging, and rejects the candidate. The final downloaded length must
still equal the signed length before extraction or installation is authorized.

The app adds `com.apple.security.network.client` and one
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
`sign_update` tooling, and deterministic transaction policy tests. G36 carries
those constraints into the production policy, direct session tests, static and
built-bundle audits, and a protected draft-metadata fixture.

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
- Only nonempty inline plain-text release notes inside the signed feed are
  accepted; remote, HTML, and missing notes fail before consent.
- Only the fixed HTTPS GitHub Releases owner, repository, tag path, DMG naming,
  and a URL without user info, port, query, or fragment are accepted.
- Redirect destinations are transport, not trust inputs. Sparkle's supported
  integration surface does not expose a redirect-policy callback, so enclosure
  signature and metadata verification must fail closed regardless of the final
  response URL.
- Offline, timeout, malformed feed, invalid signature, cancellation, disk-full,
  and interruption paths remove staging and preserve the installed build.
- Installation commits only after a verified download and explicit final user
  confirmation. Deferral leaves the current application untouched.
- On the first updater-enabled launch only, an absent authenticated high-water
  record is initialized from the canonical running `CFBundleVersion` before a
  network check. A present malformed record fails closed rather than being
  replaced.

The fixture creates a fresh test-only Ed25519 key in a temporary directory,
signs and verifies an archive and appcast with Sparkle's shipped tools while
network access is denied, rejects mutations inside the signed feed bytes,
archive tampering, and a second key. It also authenticates deliberately
malformed XML and proves Sparkle's real appcast parser rejects it before any
selection decision. A signed well-formed appcast must pass the same parser as a
positive control before that negative result is accepted, then the fixture
destroys all material.
Sparkle's signed-feed envelope authenticates an explicit content length and
parses only those verified bytes; data appended after that envelope cannot alter
the authenticated appcast. No production key or public feed exists in G35. G36
creates the production key outside the repository, compiles only its public
half, and makes the private half available only to the protected release
environment and encrypted recovery. A protected candidate job creates an
authenticated appcast inside the restricted verification bundle; G36 does not
upload a standalone appcast or publish a feed.

## Consequences

Sparkle 2.9.4 becomes a reviewed test-only package dependency in G35 and a
shipping dependency in G36. The production key boundary, sandbox services, UI
behavior, acknowledgements, privacy copy, release workflow, and rollback record
satisfy [`secure-update-operations.md`](../secure-update-operations.md) and
[`secure-update-threat-model.md`](../secure-update-threat-model.md). The
application target has one Sparkle adapter; pure policy and session behavior are
directly testable without network or UI automation.

Users on 0.1.x have no updater and must install the first updater-enabled release
manually from the existing authenticated GitHub release channel. Automatic
update checks can begin only after that bootstrap. G36 stops before public feed
or release creation, so its shipping integration is exercised only through
local and protected private qualification.
