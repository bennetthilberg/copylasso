# Secure Update Operations

This runbook records the secure-update decisions that G36 and later release
goals must implement. G35 creates only local proof fixtures.

## Endpoint and Request Contract

The production appcast will live at
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
G36 therefore must not implement or advertise a redirect allowlist that it
cannot connect to the real downloader. It treats the final response location
and all downloaded bytes as untrusted transport until the signed length and
Ed25519 enclosure verification succeed. A future need for redirect-level
enforcement requires an architecture amendment or an upstream supported seam
before implementation.

Automatic checks default on, run no more often than every 24 hours, and can be
disabled. A user command may check immediately. Requests contain no system
profile, hardware data, stable identifier, cookies, custom headers, screen or
clipboard content, or delegate-provided query parameters. Sparkle's ordinary
user agent contains only the application/display version and Sparkle version.
The server therefore observes only normal transport metadata such as IP address
and request time.

## Signing-Key Lifecycle

G36 will create the production Ed25519 key through Sparkle's supported tooling.
The private key must be passphrase-protected and stored only in the maintainer's
nonsynchronized login Keychain, a protected GitHub `release` environment secret,
and one encrypted offline recovery copy. It must never appear in a command
argument, log, fixture, repository file, build artifact, app bundle, appcast, or
issue. The public key may be compiled into CopyLasso.

Developer ID credentials, the SSH release-tag signing key, and the update
Ed25519 key remain separate. Protected release jobs import only the credentials
needed for their stage after all ordinary tests pass, sign the final enclosure
and feed, verify both with the public key, publish immutable assets, and destroy
temporary key material on success or failure.

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

A candidate must be strictly newer than the installed build, not below the
high-water mark, metadata-consistent, correctly signed, and within the approved
immutable GitHub URL and 256 MiB size policy. The high-water mark advances only
after the candidate feed and enclosure metadata authenticate.

## Staging, Cancellation, and Recovery

Downloaded bytes exist only in Sparkle's bounded temporary update transaction.
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

## 0.1.x Bootstrap and G35 Boundary

CopyLasso 0.1.x contains no updater. Its users must download and install the
first updater-enabled version from the public GitHub release page and verify it
with the existing checksum, Developer ID, notarization, and Gatekeeper flow.
Only that installed version can begin automatic checks.

G35 does not create a production key, add an app entitlement, link Sparkle into
the product, publish a feed, change release bytes, or perform an update. Its
ephemeral fixture key is generated under a private temporary directory, used
with networking denied, and removed at exit.
