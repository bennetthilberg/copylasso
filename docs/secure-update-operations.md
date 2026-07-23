# Secure Update Operations

This runbook records the secure-update boundary implemented by G36 and the
publication responsibilities left to later release goals. G35 created the local
architecture proof; G36 links the reviewed updater and creates no public feed or
release.

## Endpoint and Request Contract

The compiled production appcast URL is
`https://updates.copylasso.com/appcast.xml`; release DMGs remain immutable
GitHub Release assets. DNS and public feed publication are later, separately
approved work.

The enclosure starts at the exact immutable `github.com` release URL recorded
in the authenticated feed, and CopyLasso validates that initial URL before the
user can authorize download: with automatic downloads disabled, the custom
`SPUUserDriver` receives the `SUAppcastItem` before its Install reply begins
retrieval. GitHub may return the asset directly or redirect Sparkle's internal
`NSURLSession`. Sparkle 2.9.4 exposes the initial mutable request to its updater
delegate but no supported callback for accepting or rejecting each redirect.
CopyLasso therefore does not implement or advertise a redirect allowlist that it
cannot connect to the real downloader. It treats the final response location
and all downloaded bytes as untrusted transport until the signed length and
Ed25519 enclosure verification succeed. A future need for redirect-level
enforcement requires an architecture amendment or an upstream supported seam
before implementation.

Automatic checks default on, run no more often than every 24 hours, and can be
disabled. A user command may check immediately. Requests contain no system
profile, hardware data, stable identifier, cookies, custom headers, screen or
clipboard content, delegate-provided query parameters, or external release-note
fetches. Release notes are required as nonempty inline plain text inside the
signed appcast; external/full release-note URLs, HTML notes, and missing notes
reject the candidate before consent. Sparkle's ordinary user agent contains
only the application/display version and Sparkle version. The server therefore
observes only normal transport metadata such as IP address and request time.

## Signing-Key Lifecycle

G36 creates the production Ed25519 key through Sparkle's supported tooling.
The private key must be passphrase-protected and stored only in the maintainer's
nonsynchronized login Keychain, a protected GitHub `release` environment secret,
and one encrypted offline recovery copy. It must never appear in a command
argument, log, fixture, repository file, build artifact, app bundle, appcast, or
issue. The public key may be compiled into CopyLasso.

Developer ID credentials, the SSH release-tag signing key, and the update
Ed25519 key remain separate. Protected release jobs import only the credentials
needed for their stage after all ordinary tests pass. G36's draft workflow signs
the exact candidate enclosure and appcast, bound to that private draft tag, in a dedicated step after the build
and Developer ID credential cleanup. Before creating metadata, it derives the
seed's public key and requires it to byte-match `SUPublicEDKey` in the exact
exported application; a different valid seed is rejected. Sparkle then verifies
both signatures under that matched identity. The workflow places the appcast
only inside the restricted verification bundle and destroys temporary key
material on success or failure. It does not upload or publish a standalone
appcast. A later publication goal must separately approve immutable public feed
and release assets.

For planned rotation, ship the replacement public key through a release trusted
by the current key, confirm adoption, then activate the replacement for a later
feed. Never rotate publication credentials and application trust in one
unreadable transaction. If the active key is lost or suspected stolen, stop
publication, remove its protected secret, preserve evidence, assess already
published releases, and publish remediation only through a separately reviewed
incident plan. Users whose installed build cannot authenticate the replacement
must update manually from the verified GitHub channel.

A bad or revoked release is removed from the next signed appcast without moving
its tag or replacing its assets. The authenticated high-water mark is retained,
so recovery is a higher-build incident release rather than a silent downgrade.

## Version and Rollback State

`CFBundleVersion` is a canonical positive ASCII decimal integer of at most 18
digits and is the monotonic update ordering value. The app persists only
the check schedule, user automatic-check preference, deferred version, and
highest authenticated build. It does not persist feed bodies or release notes.
The installed build is always the minimum accepted baseline; the authenticated
high-water mark rejects replay after a deferral.

An absent high-water record is initialized and persisted before the first
network check in the first updater-enabled launch, using the canonical running
`CFBundleVersion`. A present record is never silently repaired: malformed data
fails closed, while a valid record remains the replay authority. This lets a
manual 0.1.x bootstrap receive the following update without weakening
corruption detection.

A candidate must be strictly newer than the installed build, not below the
high-water mark, metadata-consistent, correctly signed, and within the approved
immutable GitHub URL and 256 MiB size policy. The high-water mark advances only
after the candidate feed and enclosure metadata authenticate.

## Staging, Cancellation, and Recovery

Downloaded bytes exist only in Sparkle's bounded temporary update transaction.
The custom user driver retains Sparkle's
`showDownloadInitiatedWithCancellation:` closure for that transaction. It
cancels exactly once when an expected-content-length callback disagrees with
the signed size or exceeds 256 MiB, or when the overflow-checked sum of
`showDownloadDidReceiveDataOfLength:` deltas first exceeds either boundary.
Extraction is never authorized until the final length equals the signed value.
Cancellation, signature or metadata rejection, download failure, timeout,
offline state, disk exhaustion, interrupted extraction, and failed installation
must leave the installed application untouched and remove staging. Startup
recovery removes an abandoned transaction before a new check.

The initial update panel shows version, release notes, exact declared size, and
that CopyLasso will download, quit, install, and relaunch. The user explicitly
chooses Download or Later. After verified extraction, a second explicit choice
authorizes Install and Relaunch. Closing, Escape, Later, or Cancel preserves the
current application; a deferred update may be shown again without downloading
automatically.

## 0.1.x Bootstrap and G36 Boundary

CopyLasso 0.1.x contains no updater. Its users must download and install the
first updater-enabled version from the public GitHub release page and verify it
with the existing checksum, Developer ID, notarization, and Gatekeeper flow.
Only that installed version can begin automatic checks.

G35 did not create a production key, add an app entitlement, link Sparkle into
the product, publish a feed, change release bytes, or perform an update. Its
ephemeral fixture key remains confined to a private temporary directory and is
removed at exit.

G36 adds the outbound client and two Sparkle installer-service names, links the
pinned framework, compiles the public Ed25519 key, and exposes accessible
automatic-check and manual-check controls. Automatic checks default on;
automatic download and installation remain off. Candidate metadata must pass
the pure policy before any Download choice is offered, and exact bytes must pass
the streaming budget before extraction and a second install/relaunch decision.

The production private key remains outside the repository in the maintainer's
nonsynchronized login Keychain, the protected GitHub `release` environment, and
an encrypted offline recovery copy. The source audit rejects tracked keys,
appcasts, and signatures. G36's protected workflow generates authenticated
metadata only inside the private verification bundle and leaves the existing
public 0.1.x release channel unchanged.

For the private install/relaunch qualification only,
`build-private-update-fixture.sh` builds isolated Apple Development-signed
`0.1.1 (2)` and `0.2.0 (3)` bundles using
`io.github.bennetthilberg.copylasso.g36fixture`. A loopback origin is accepted
only under the nonshipping `COPYLASSO_PRIVATE_UPDATE_FIXTURE` compile condition;
ordinary Debug, Release, and Developer ID builds omit it and are audited for
the marker's absence. The fixture initially serves a signature-invalid copy of
the otherwise valid appcast, then swaps in the exact signed copy for the update.
Its state and TCC identity cannot be mistaken for the production app.
