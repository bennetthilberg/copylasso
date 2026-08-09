# Release Candidate Qualification

## G50 v0.2.2 Maintenance Candidate Qualification

After the G50 source-enablement pull request is separately merged, dispatch the
protected workflow from that exact protected-main commit with the first unused
positive `candidate_number`. The expected first tag is `v0.2.2-rc.1`, but live
collision readback is authoritative. The private draft uses reviewed
[`release-notes/0.2.2.md`](release-notes/0.2.2.md) and exactly these restricted
assets:

- `CopyLasso-0.2.2.dmg`
- `CopyLasso-0.2.2.dmg.sha256`
- `CopyLasso-0.2.2.dSYM.zip`
- `CopyLasso-0.2.2-verification.zip`

Verify exact source, GitHub digests, checksum, Developer ID signature, secure
timestamp, Hardened Runtime, reviewed entitlements, nested code,
notarization/stapling, Gatekeeper, Universal 2 slices, dSYM UUIDs, production
identity, version `0.2.2`, build `5`, and the candidate appcast key, signature,
URL, length, ordering, and tamper rejection. Use a genuine Safari-quarantined
download for the compact current-host capture smoke.

Exercise an isolated nonshipping updater fixture from exact public `0.2.1 (4)`
to the byte-identical candidate app. Test Later, Download, Install and Relaunch,
offline/interrupted preservation, preference and Launch-at-Login retention,
post-update capture, build-high-water advancement to `5`, and rollback refusal.
Do not rebuild, publish, replace, or deploy the candidate. Any tracked input
change abandons it and requires a new positive number.

## G42 v0.2.0 Candidate Qualification

G41 enables, but does not dispatch, the protected v0.2 workflow. After that
pull request is separately merged and G42 is approved, the workflow derives
`v0.2.0-rc.N` from a positive `candidate_number` and creates a private draft
prerelease for the exact protected `main` commit. The reviewed body is
[`release-notes/0.2.0.md`](release-notes/0.2.0.md), and the four restricted
assets are `CopyLasso-0.2.0.dmg`, `CopyLasso-0.2.0.dmg.sha256`,
`CopyLasso-0.2.0.dSYM.zip`, and
`CopyLasso-0.2.0-verification.zip`.

Qualify that immutable candidate against the G41 source record and repeat only
the release delta:

1. Read back the private draft, direct candidate tag, target commit, reviewed
   notes, four asset names and GitHub digests, checksum, Developer ID
   signatures, notarization, Gatekeeper result, Universal 2 slices, production
   identity, version `0.2.0`, and build `3`.
2. Verify the restricted appcast has one authenticated candidate entry, exact
   byte length and immutable GitHub enclosure URL, inline plain-text notes, a
   matching compiled public key, and valid enclosure and feed signatures.
3. Download the exact private DMG and checksum through a genuine browser
   quarantine path. Confirm clean launch and Screen Recording recovery, then
   smoke OCR, code-over-text precedence, all five supported code formats,
   success sound enabled and disabled, updater enabled and disabled, an offline
   update failure that does not affect capture, and quit/relaunch.
4. Confirm no payload is interpreted or opened, no LaTeX command or model is
   present, no update is installed without a separate user decision, and no
   public release or feed exists.

Every result must identify the exact commit, `v0.2.0-rc.N` tag, and DMG digest.
Any tracked correction to application code, release configuration, packaging
inputs, reviewed notes, dependencies, entitlements, or shipped assets abandons
the candidate and reruns the complete protected gate with a new positive
number. A later evidence-only qualification commit may record factual results
for the unchanged candidate only when an exact path-scoped diff proves that no
candidate input changed and the canonical audit enforces that boundary. Keep
the draft private, retain the dSYM and verification bundle as restricted
evidence, and stop for explicit maintainer approval or rejection. G42 never
publishes.

## G32 v0.1.1 Maintenance Qualification

For the Settings-presentation hotfix, the same protected trust boundary applies
with version `0.1.1`, build `2`, tag `v0.1.1-rc.N`, and artifacts named
`CopyLasso-0.1.1.dmg`, `CopyLasso-0.1.1.dmg.sha256`,
`CopyLasso-0.1.1.dSYM.zip`, and `CopyLasso-0.1.1-verification.zip`. The reviewed
draft body is [`release-notes/0.1.1.md`](release-notes/0.1.1.md).

The candidate must contain merged fix commit `83990ef162cd94c22fa8a7ad14bb095050517dcc`
in its ancestry and no later application behavior beyond the release-metadata
change. Independently verify the four draft assets, exact target commit,
checksum, Developer ID signatures, notarization tickets, Gatekeeper acceptance,
Universal 2 slices, production bundle identifier, version/build, and two-item
read-only DMG layout. Smoke opening Settings from the status menu, closing it,
and starting a capture; Settings must appear for the menu command and must not
surface during the later capture.

After explicit approval of the exact candidate, create a signed annotated
`v0.1.1` tag on that same commit and publish only the qualified DMG and checksum.
Never publish a private rehearsal, move `v0.1.0`, replace an existing asset, or
make the dSYM or verification bundle public.

The original `0.1.0` qualification record below remains historical evidence.

This procedure qualifies one immutable CopyLasso 0.1.0 release candidate. It
supplements the partial Sonoma rehearsal retained by G29 and replaces further
VirtualBuddy execution with one exact-candidate smoke test in a disposable
local macOS account on the maintainer's latest-stable host. Do not resume VirtualBuddy
for the v0.1 release.

The protected workflow must create the candidate from the exact protected
`main` commit. Every automated result, private asset, manual observation, and
risk entry must identify that commit, the derived `v0.1.0-rc.N` tag, and the
DMG SHA-256. Any tracked correction abandons the candidate and requires a new
positive candidate number plus the complete gate.

## Evidence And Immutability

Before dispatch, finalize the tracked release notes, product contract,
checklist, and this procedure. After dispatch, retain content-free evidence
outside the repository under a commit-addressed
`~/Library/Developer/CopyLasso/G30/<commit>/` directory and record the concise
result in ignored `roadmap.md`. Do not commit account names, passwords, local
account identifiers, signing subjects, Team IDs, private host paths, raw TCC
or login-item databases, captured pixels, recognized text, or clipboard data.

The candidate helper accepts only a positive canonical `candidate_number` and
derives the tag internally. It refuses an existing release or tag, uploads the
four reviewed private assets without replacement, verifies their GitHub
`sha256:` asset digests, and creates the tag last. A failed transaction removes
only the draft and tag created by that invocation. It never patches, moves,
force-updates, or overwrites an existing release or ref.

The final candidate remains a draft prerelease. G30 does not publish it, create
the final `v0.1.0` tag, date the changelog, or add a public download link.

## Disposable Local Account Preflight

The application in `/Applications` is visible to every local account. Before
creating or entering the disposable account, quit any existing CopyLasso
process and reversibly stage an existing `/Applications/CopyLasso.app` outside
Applications. Do not delete the maintainer's production preferences or
container.

Create the disposable account through macOS Users & Groups without recording
its password. Before downloading the candidate, verify all of the following:

- `/Applications/CopyLasso.app` is absent.
- `defaults read io.github.bennetthilberg.copylasso` reports no domain for the
  disposable account.
- `$HOME/Library/Containers/io.github.bennetthilberg.copylasso` is absent.
- CopyLasso is absent from Login Items & Extensions.
- CopyLasso is absent from Screen & System Audio Recording.

Do not inspect or copy raw TCC or login-item databases. A stale application,
preference, container, login item, or Screen Recording approval invalidates the
clean-account run.

## Private Staging And Browser Download

Authenticated maintainer tooling downloads all four draft assets for private
verification. After the complete package verifier passes, place only
`CopyLasso-0.1.0.dmg` and `CopyLasso-0.1.0.dmg.sha256` in a temporary external
serve directory. Start a server bound only to `127.0.0.1` on an unused high
port. Do not bind to every interface, sign the disposable account in to GitHub,
use a shared folder, copy the app between accounts, or add quarantine manually.

In Safari from the disposable account, download the DMG and checksum from the
loopback server. Stop the server immediately afterward. Require a nonempty
`com.apple.quarantine` value and verify both the trusted candidate digest and
the downloaded checksum file before mounting the DMG. Missing quarantine or a
checksum mismatch blocks the candidate.

Because the reviewed release notes are already part of the tagged commit and
draft body, this one fresh Safari download is the final G30 browser readback;
no second download is inferred from older G28 or G29 assets.

## Exact Candidate Smoke Matrix

Record Pass, Fail, or Blocked for every row. This is a bounded release smoke,
not a repetition of the complete G24 performance and accessibility matrix.

1. Confirm the quarantined DMG mounts read-only and contains only CopyLasso and
   the Applications alias.
2. Drag CopyLasso to Applications and open it normally. Do not use Open Anyway,
   remove quarantine, or bypass Gatekeeper.
3. Confirm onboarding appears once, no Dock icon appears, no privacy prompt is
   shown before capture, and the suggested shortcut is `⇧⌘2`.
4. Complete onboarding with an explicitly recorded Launch at Login choice and
   verify the presented state without reopening the accepted restart matrix.
5. Start capture, deny the native Screen Recording request, and confirm one
   recovery window, no downstream work, and no automatic retry.
6. Enable only CopyLasso through its System Settings route, follow the actual
   Later or Quit & Reopen transition, and start a fresh capture.
7. Complete one configured-shortcut capture and one menu capture. Confirm the
   crosshair, initiating-display dim, bounded outline, OCR, plain-text
   clipboard output, success HUD, originating-application restoration, and
   immediate command reuse.
8. Read back production bundle `io.github.bennetthilberg.copylasso`, version
   `0.1.0`, build `1`, and both `arm64` and `x86_64` from the installed app.
9. Quit normally and confirm the process, status item, active selection, and
   HUD disappear.

Admin authentication, privacy approval, and physical drag observations may
require the maintainer. Computer Use should perform every faithful read-only
inspection and UI action that does not require the maintainer's direct input.

## Accepted Evidence Gaps

The following remain explicit accepted gaps rather than release passes:

- the Sonoma enabled-Launch-at-Login restart;
- ordinary reinstall with preferences retained;
- complete uninstall and reinstall;
- disposable-clone discard and recreation;
- every unexecuted latest-stable guest-VM row;
- G24's incomplete cold native-status-item timing, exact capture-dimension
  record, remaining permission repeats, complete active-phase lifecycle and
  clipboard sweep, reboot persistence, complete assistive-state sampling,
  pre-run temporary inventory, and private-memory checkpoint series.

The accepted stationary immediate-reuse crosshair delay and lock-during-drag
recovery behavior remain Known limitation entries. The disposable-account
smoke supplements these records but does not retroactively convert them to
passes.

## Issue Classification And Approval

- **Release-blocking:** signing, notarization, Gatekeeper, quarantine,
  checksum, installation, permission recovery, menu or shortcut capture, OCR,
  clipboard output, privacy, crash, or data-handling failure that violates the
  reviewed contract. Abandon the candidate.
- **Known limitation:** an explicitly accepted and accurately documented v0.1
  boundary that does not invalidate the core smoke.
- **Deferred:** a non-goal or accepted evidence gap whose automation or
  procedure remains intact for later work.

Compare the classification record with the reviewed release notes and G24/G29
evidence. The maintainer must explicitly approve the exact tag, commit,
checksum, notes, and risk record. Stop with the draft unpublished and the
binary unchanged. Keep the disposable account until separately approved
cleanup; deleting it is not part of G30.
