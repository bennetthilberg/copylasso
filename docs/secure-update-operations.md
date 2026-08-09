# Secure Update Operations

This runbook records the secure-update boundary implemented by G36 and the
public feed published by G43. G35 created the local architecture proof; G36
linked the reviewed updater; G42 qualified the immutable candidate; and G43
published the exact authenticated feed and release without rebuilding.

## Endpoint and Request Contract

The compiled production appcast URL is
`https://updates.copylasso.com/appcast.xml`; release DMGs remain immutable
GitHub Release assets. The feed-only endpoint contains no website, content API,
analytics, or redirect service.

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

The initial update panel shows version, authenticated source, exact declared
size, and rendered release notes. The panel has a fixed footprint; long notes
scroll independently while the metadata, consent explanation, and Download and
Later buttons remain visible. Markdown headings, emphasis, paragraphs, and
lists are presentation only, and embedded links are inert. The user explicitly
chooses Download or Later. After verified extraction, a second explicit choice
authorizes Install and Relaunch. Closing, Escape, Later, or Cancel preserves the
current application; a deferred update may be shown again without downloading
automatically.

## 0.1.x Bootstrap and Public 0.2.0

CopyLasso 0.1.x contains no updater. Its users must download and install public
CopyLasso 0.2.0, the first updater-enabled release, from the GitHub release page and verify it
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

## Historical G41 Qualification and G42 Handoff

During G41, updater-enabled source froze at `0.2.0 (3)` while public CopyLasso
remained `0.1.1`. The first updater-enabled release still required manual
installation, and no public v0.2 appcast or updater-enabled artifact existed at
that historical checkpoint. The
exact-head qualification package may generate one authenticated appcast
locally, verify its key match and feed/enclosure signatures, and prove tamper
and wrong-key rejection. That record remains outside the repository and is
never uploaded or served.

After G41 is separately merged, G42 may dispatch the protected workflow from
that exact protected `main` commit. G42 derives `v0.2.0-rc.N`, places its
candidate-specific appcast only in the restricted verification bundle, and
tests the private staged updater path. It remains draft-only and exposes no
publication path. Public feed publication and immutable release promotion were
separately approved and completed in G43.

## G43 Production Feed

The production endpoint is
`https://updates.copylasso.com/appcast.xml`. G43 serves it from a feed-only
Cloudflare Pages Direct Upload project. The authoritative domain remains at
Spaceship; only the `updates` CNAME points to the assigned Pages hostname.
Neither the apex domain nor its nameservers change.

The deployment contains only the signed `appcast.xml` and a Pages `_headers`
policy. There is no index, general website, script, analytics endpoint,
redirect, or content API. The appcast uses a five-minute revalidation window,
`no-transform`, an XML content type, and `nosniff`. Transport is not the trust
boundary: Sparkle must still validate the signed feed, exact version/build,
immutable GitHub enclosure URL, declared length, and enclosure signature before
offering an update.

G43 deploys the feed only after the signed final tag and two-asset GitHub
release pass public readback. Future feed updates use a new immutable Pages
deployment and the same reviewed signing boundary. A hosting failure never
authorizes unsigned metadata, a replacement release asset, or movement of an
existing release tag.

## G48 Maintenance Candidate Handoff

G48 qualified candidate source `0.2.1 (4)` while public `0.2.0 (3)` remained
installed and served by the production feed. G49 later published that exact
candidate without rebuilding.
The protected workflow derives the private `v0.2.1-rc.N` tag and all four
versioned assets from canonical metadata, accepts only one positive
`candidate_number`, and creates a draft prerelease from exact protected main.
It cannot publish or replace an asset, accept an arbitrary tag or ref, or
deploy a feed.

The restricted candidate verification bundle may contain one authenticated
candidate appcast. It is not a public feed. Phase 2 must test an isolated
nonshipping updater fixture from exact public `0.2.0 (3)` to the byte-identical
candidate app and prove authenticated discovery, consent, replacement,
preference retention, high-water advancement, and rollback rejection. Any
tracked candidate-input correction requires a new candidate number.

CopyLasso 0.2.0 is the first public updater-enabled release. Its published feed
and immutable GitHub enclosure passed signature, length, URL, version-ordering,
browser-download, install, and public updater-path readback. The exact public
identifiers and digests are retained in the
[v0.2 release-state record](v0.2-release-state.md).

## G49 v0.2.1 Publication Boundary

G49 updates the production feed only after the signed final tag and exact
two-asset GitHub release are public and independently verified. The protected
preparation workflow consumes private `v0.2.1-rc.1` without rebuilding,
generates a final-URL appcast with the existing protected Sparkle identity, and
creates a private final draft. It has no publication or feed-deployment path.

The operator transaction publishes the immutable draft and then deploys only
the verified `appcast.xml` plus the existing `_headers` policy to the existing
Cloudflare Pages project. It does not change the custom domain, apex DNS,
nameservers, hosting scope, update key, or application trust settings. A failed
GitHub or feed readback freezes the state for remediation; it never authorizes
moving a tag, replacing an asset, or serving unsigned metadata.

CopyLasso 0.2.1 is the current public updater-enabled release. The signed final
tag and direct RC tag both peel to the exact G48 candidate commit. The public
release contains only the reviewed DMG and checksum, and production deployment
`e768eb55-98d7-4d44-9603-65e3972fd66d` serves the authenticated appcast whose
SHA-256 is `c721b9396682c05082e019bdfa1297bc320f9883aabac2fd20c647f228aa8454`.
An exact public 0.2.0 installation updated through that feed to byte-identical
0.2.1 only after separate download and install-and-relaunch consent.
