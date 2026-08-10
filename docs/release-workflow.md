# Protected Release Workflow

The maintainer-dispatched workflow builds one signed, notarized, and verified
CopyLasso release from the exact protected `main` commit. It creates a private
draft prerelease and never publishes it. G50 updates this source-only trust
boundary for security-hotfix version `0.2.2`; it does not dispatch the workflow. A final
release is published only after the draft, asset digests, checksum, signed
application, Gatekeeper result, authenticated update metadata, and smoke test
have been independently read back.

## Trust Boundary

The workflow accepts only the `copylasso_protected_release` `repository_dispatch`
event. GitHub runs that event from the repository's default branch, so the
caller cannot select an unreviewed branch copy of the privileged workflow. The
workflow also rejects every ref except `refs/heads/main`, requires the checked-out
`HEAD` to equal the dispatched full commit, and requires that commit to equal
`origin/main`.

The ordinary pull-request workflow has no release trigger and receives no release credential. The
protected workflow runs the complete reusable arm64, x86_64, and minimum-macOS gate before it asks
for access to the `release` environment. The release job uses one reviewed, full-commit-pinned
checkout action and does not persist Git credentials.

Configure the public repository's `release` environment with:

- protected branches only;
- the maintainer as required reviewer;
- self-review allowed while the project has only one release maintainer; and
- the seven environment secrets listed below.

The environment must not expose these values as repository-level secrets:

| Environment secret | Purpose |
| --- | --- |
| `COPYLASSO_DEVELOPER_ID_P12_BASE64` | Base64 of the password-protected Developer ID identity export |
| `COPYLASSO_DEVELOPER_ID_P12_PASSWORD` | Password for that identity export |
| `COPYLASSO_NOTARY_KEY_BASE64` | Base64 of the dedicated Team API private key |
| `COPYLASSO_NOTARY_KEY_ID` | Dedicated Team API key identifier |
| `COPYLASSO_NOTARY_ISSUER_ID` | App Store Connect issuer identifier |
| `COPYLASSO_EXPECTED_TEAM_ID` | Approved Developer ID team used for independent verification |
| `COPYLASSO_SPARKLE_PRIVATE_KEY` | Base64-encoded 32-byte Sparkle Ed25519 seed used only for protected appcast and enclosure signing |

Secret names are public configuration; their values are not release evidence. Never enter a value
in a workflow input, command argument, tracked file, issue, pull request, or release note.

## Initial Credential Setup

Export the existing Developer ID Application identity and private key from the login Keychain once
as a password-protected PKCS#12 file. Use a newly generated password. Base64-encode the file directly
into the protected environment secret through standard input, then remove the temporary export. Do
not retain a `.p12` beside the repository or under `dist/`.

Create a dedicated **Team API key** with the **Developer** role for GitHub Actions. This is separate
from the local `copylasso-notary` profile established in G26. Store its private-key contents, key
identifier, and issuer identifier only in the protected environment, then remove the downloaded key
file. A personal Apple ID password or app-specific password is not used by this workflow.

Generate the Sparkle Ed25519 identity once with the pinned Sparkle 2.9.5 tooling. Keep its private
seed in the maintainer's nonsynchronized login Keychain and an encrypted offline recovery copy.
Supply the raw 32-byte Base64 value to `COPYLASSO_SPARKLE_PRIVATE_KEY` only as a protected
environment secret. The protected workflow injects it into one dedicated post-build metadata step,
which removes it from the process environment immediately and passes it to Sparkle only over
standard input. The archive, export, notarization, packaging, and credential-cleanup steps never
receive it. The application and repository contain only the public key. Never write the private
value into a workflow input, environment readback, shell argument, log, appcast, issue, or tracked
file.

The workflow decodes both protected blobs only under `RUNNER_TEMP`, imports the identity into a
randomly protected temporary Keychain, and creates a `copylasso-notary` profile in that Keychain.
Raw credential files are removed immediately after import. An unconditional cleanup step restores
the runner's original default and search-list Keychains, deletes the temporary Keychain, and must
pass before draft creation.

The hosted runner archives with manual signing, the imported Developer ID Application identity,
the protected team, and the temporary Keychain selected explicitly. It then copies
`Configuration/DeveloperIDCIExportOptions.plist` into the private handoff, adds the protected team
to that runtime-only copy, and removes the copy immediately after export. The tracked contract has
no account identifier. Archive and export therefore use the same protected identity without an
interactive Xcode account or permission to create signing assets. The local G26 automatic export
contract remains separate.

## Run a Private G50 Rehearsal

Only after the G50 source pull request is reviewed, green, and separately
merged, and G50 Phase 2 is explicitly approved:

1. Dispatch `copylasso_protected_release` through GitHub's repository dispatch API without a
   `candidate_number` payload field.
2. Confirm the run's commit is the intended protected `main` commit.
3. Wait for the complete reusable CI gate.
4. Approve the `release` environment when GitHub requests deployment review.
5. Allow the protected job to archive, export, notarize, staple, package, verify, clean credentials,
   and create its draft.

Only one protected release run may execute at a time. A failure is never promoted by rerunning only
a later step: correct the cause, create a new green commit if tracked code changed, and dispatch the
complete workflow again.

The workflow uses the established Developer ID application verifier and release
package process. Its protected commit is both the application payload commit
and packaging commit. A blank candidate number uses the nonrelease form
`v0.2.2-g50.<run>` so it cannot be mistaken for G50's `v0.2.2-rc.N` candidate.

## G30 Protected Candidate Handoff

G30 introduced the two-phase protected candidate handoff used for the public
`0.1.0` release: first merge the reviewed workflow enablement, then dispatch a
candidate from that exact protected `main` commit.

The G28 rehearsal draft and its assets cannot serve as G30 evidence. That
historical release record remains immutable. G32 later reused the same trust
boundary for `0.1.1`; G42 uses the current version-derived names without
altering either historical record.

## G50 v0.2.2 Security-Hotfix Candidate Handoff

G50 has ordered source and private-candidate phases.

1. Merge the reviewed G50 source-enablement pull request to protected `main`.
   No protected release can run from the unmerged branch because the default
   branch owns the `repository_dispatch` workflow definition.
2. In a separately approved Phase 2 run, provide only the first unused positive
   `candidate_number`. The workflow derives `v0.2.2-rc.N`, refuses collisions,
   and builds exact protected main through the complete quality gate and
   protected `release` environment.

The job derives all four `0.2.2` asset names from canonical metadata, signs,
notarizes, staples, packages, cleans credentials, and creates one private draft
prerelease. The restricted verification bundle contains candidate-specific
authenticated update metadata. It never publishes, overwrites an asset, moves
a tag, accepts an arbitrary ref, or deploys a feed.

The reviewed candidate body is
[`release-notes/0.2.2.md`](release-notes/0.2.2.md). Follow the G50 procedure in
[`release-candidate-qualification.md`](release-candidate-qualification.md) and
[`release-checklist.md`](release-checklist.md). Any tracked candidate-input
change abandons the candidate and requires a new positive number.

## Historical G42 v0.2 Candidate Handoff

G42 has two ordered phases.

1. Merge the reviewed G41 source-enablement pull request to protected `main`.
   Because `repository_dispatch` runs the workflow from the default branch, no
   rehearsal or candidate can be created from the unmerged G41 branch or an
   attacker-selected branch copy of the workflow.
2. In a separately approved post-merge protected run, supply only a validated
   positive `candidate_number`. The workflow derives `v0.2.0-rc.N`, refuses an
   existing tag or release, and builds the exact protected `main` commit through
   the complete quality gate and `release` environment.

The job signs, notarizes, staples, packages, removes temporary credentials, and
transactionally creates a draft prerelease with the four-asset contract. Its
restricted verification bundle contains the exact authenticated `appcast.xml`
generated for that candidate. Readback must prove the target commit, derived
tag, draft and prerelease state, reviewed `0.2.0` notes, asset names, GitHub
asset digests, checksum, and authenticated update metadata. Any later tracked
change to application code, release configuration, packaging inputs, reviewed
notes, dependencies, entitlements, or shipped assets abandons that candidate
and requires a new positive candidate number. A later evidence-only
qualification commit may record factual results for the unchanged candidate
only when an exact path-scoped diff proves that no candidate input changed and
the canonical audit enforces that boundary.

Leaving `candidate_number` blank selects a private G42 rehearsal. A positive
canonical integer selects the G42 candidate path. Values with a sign, leading
zero, decimal, whitespace, or tag text are rejected before they influence a tag
or path. No arbitrary tag, ref, or mode input exists. The candidate tag is
created atomically before draft creation and is rollback-eligible only after
that exact ref creation succeeds. An ambiguous release-creation response retains
the tag for manual inspection because another actor may already have attached a
release to it. The helper never replaces, patches, moves, or force-updates a ref
or release.

Rollback deletes an incomplete draft before deleting its candidate tag. If
draft deletion fails, the tag is retained so the surviving release never loses
its ref. Any draft or tag cleanup failure is an explicit blocking state that
requires manual readback and recovery before that candidate number is reused.

The reviewed candidate body is
[`release-notes/0.2.0.md`](release-notes/0.2.0.md). Follow
[`v0.2-release-qualification.md`](v0.2-release-qualification.md) and the G42
rows in [`release-checklist.md`](release-checklist.md). G41 only enables this
path; it uploads nothing, creates no candidate, and publishes no feed.

## G32 Maintenance Candidate Handoff

The completed G32 maintenance handoff is historical evidence for public
`0.1.1`. It had two ordered phases.

1. Land a reviewed source-enablement pull request that adds a distinct RC mode to the protected
   workflow, draft helper, static audit, and regression tests. The historical G32 operator selected
   `main`, and the source verifier rejected every other ref. G45 later replaced that branch-selectable
   trigger with a default-branch-only repository dispatch boundary.
2. In the post-merge protected run, supply only a validated positive `candidate_number`; derive
   `v0.1.1-rc.N` inside the workflow, refuse an existing tag or release, and build the exact merged
   `main` commit through the complete quality gate and `release` environment. The job must sign,
   notarize, staple, package, clean credentials, and transactionally create a draft prerelease with
   the same four-asset contract. Readback must prove the exact target commit, tag, draft/prerelease
   state, asset names, GitHub asset digests, and DMG checksum. Any later tracked change abandons that
   candidate and uses a new number.

At that historical point, `candidate_number` was the workflow's sole input. A
blank value selected a private G32 rehearsal and a positive canonical integer
selected the G32 candidate path.

The helper derives the RC tag independently, refuses both an existing release and an existing
Git ref, and uploads without replacement. It reads back the draft body from the reviewed
[`release-notes/0.1.1.md`](release-notes/0.1.1.md), the exact four asset names, and every available
`sha256:` asset digest. The checksum record must agree with both the local DMG and its uploaded
digest. Only after those checks pass is the lightweight tag created directly on the exact commit;
the tag is created last so an upload or validation failure cannot strand an RC ref. Final tag and
release readback completes the transaction. On a later failure, cleanup deletes only the draft and
tag created by that invocation. The helper never patches, force-updates, moves, or overwrites a ref
or release.

Historical private rehearsal drafts and their assets cannot serve as G32
evidence. Only the RC draft created by the post-merge protected run supplies
G32's DMG and checksum.

Because that release remains a private draft, download its DMG and checksum with authenticated
maintainer tooling into an external staging directory. Verify both against the protected readback,
then serve only those two files temporarily on `127.0.0.1`. Download them through Safari in the
disposable local test account so macOS creates genuine browser quarantine without signing that
account in to GitHub. Stop the server and remove the staging copy after qualification; never add a
quarantine attribute manually.

The reviewed release notes and qualification procedure land before candidate creation. Therefore
the Safari qualification download occurs after the final draft body exists and also serves as the
fresh browser readback for the candidate; an older historical download or a second inferred download
does not count. Follow [`release-candidate-qualification.md`](release-candidate-qualification.md) for the
clean-account preflight, exact smoke matrix, accepted gaps, risk classification, and evidence
boundary.

## Current Draft Assets and Local Readback

The draft prerelease contains exactly:

- `CopyLasso-0.2.2.dmg`;
- `CopyLasso-0.2.2.dmg.sha256`;
- `CopyLasso-0.2.2.dSYM.zip`; and
- `CopyLasso-0.2.2-verification.zip`.

The verification bundle contains the exact stapled source application, the authenticated
`appcast.xml` generated for that exact candidate, and the portable records
needed to reconstruct the release-run directory after downloading the other three assets. Download
all four assets into an ignored, commit-addressed directory, expand the verification bundle, place
the DMG, checksum, and dSYM beside its `run` evidence, and invoke `verify-release-package.sh` with
the bundled `payload/<commit>/export/CopyLasso.app`. The supplied payload and packaging commits are
both the protected workflow commit.

The appcast inside the restricted verification bundle points to the exact private rehearsal or
release-candidate draft tag and is evidence, not a publication asset. The
protected job requires exactly one candidate entry, inline plain-text release notes, the canonical
version/build, exact immutable GitHub enclosure URL and byte length, and valid feed plus enclosure
Ed25519 signatures. It verifies both signatures with the public key compiled into CopyLasso before
draft creation: the signing seed's derived public key must byte-match `SUPublicEDKey` in the exact
exported application before either signature is accepted. A wrong but otherwise valid seed fails
closed without creating metadata. The standalone appcast is never uploaded among the four draft assets
and no file is published to `updates.copylasso.com` in G36.

Read back the draft through GitHub after upload. It must remain `draft: true` and `prerelease: true`,
target the exact commit, and contain exactly the four assets above. Recompute the public checksum
and rerun the complete local package verifier. Preserve the downloaded dSYM and verification bundle
as restricted maintainer evidence.

The dSYM and verification bundle are intentionally draft-only. Remove them from
the eventual public release; only the already-qualified DMG and checksum become
public release assets. Never publish a private rehearsal.

## Log And Failure Review

The workflow keeps certificate import, Xcode signing, and notarization diagnostics out of the public
step log. Inspect the completed log and reject the run if it contains private-key or certificate
blocks, account email, signing authorities, team readback, or app-specific-password-shaped text.
GitHub masking is defense in depth rather than proof that transformed secrets are safe to print.

Draft creation is transactional. If an asset upload or final API readback fails, the workflow deletes
the incomplete draft. Failed tests, source validation, credential import, archive/export, signing,
notarization, stapling, package verification, or credential cleanup prevent draft creation.

## Rotation And Recovery

- **Certificate renewal:** replace both certificate environment secrets from a fresh protected
  export, then remove the export. Do not change notarization credentials unnecessarily.
- **Notary key rotation:** revoke only the dedicated CI Team API key, create its replacement with the
  Developer role, replace its three environment secrets, and remove the downloaded key.
- **Sparkle key rotation:** first ship a reviewed release containing the replacement public key
  through the still-trusted current update channel. Confirm adoption before replacing
  `COPYLASSO_SPARKLE_PRIVATE_KEY`. A suspected compromise stops update publication and requires a
  separate incident plan; never silently replace feed or release bytes.
- **Suspected exposure:** cancel active release runs, revoke the affected Apple credential, delete
  the protected environment value, inspect workflow history, and create a replacement before
  another dispatch.
- **Apple rejection:** retain the private diagnostic evidence, fix the signing or source problem in a
  reviewed commit, and restart from the complete quality gate. Never staple or draft a rejected
  artifact.
- **Stale draft:** delete the incomplete rehearsal through GitHub Releases. Never overwrite assets
  under an existing draft tag.

G50 Phase 2 stops after one exact run, downloaded local re-verification, log
and cleanup inspection, authenticated updater-path smoke, and a verified draft
release. It does not publish; publication requires separately approved
protected controls and an immutable transaction.

## G43 Publication Preparation

G43 uses a separate protected manual workflow after its publication-control PR
is merged. It does not rebuild, resign, renotarize, staple, or repackage the
application. Instead, it downloads the exact approved G42 draft by its fixed
release ID, verifies all four restricted asset records and bytes, reconstructs
the verification bundle, and reruns the complete package verifier against the
frozen candidate source commit.

The G43 workflow has no dispatch inputs. It exposes the existing Sparkle seed
only to one appcast-generation step and the approved release team only to one
package-verification step. It receives no Developer ID certificate or
notarization credential. The generated appcast changes only the enclosure URL
from the private RC tag to the immutable final `v0.2.0` tag, then re-signs and
verifies both the feed and exact approved DMG.

After every check passes, the workflow creates one private, non-prerelease
final draft with exactly the approved DMG and checksum. It creates no Git tag,
contains no publication API call, and deploys no feed. A restricted workflow
artifact carries the signed feed-only bundle and content-free readbacks into
the separately approved public transaction described in
[`v0.2-publication-runbook.md`](v0.2-publication-runbook.md).

The existing protected candidate workflow remains draft-only. The final
annotated signed tag, public-release transition, Cloudflare Pages feed
deployment, external-DNS CNAME, public browser download, and updater smoke are
manual G43 gates after the preparation PR is merged. G44 owns all
post-publication documentation and issue-state changes.

The immutable publication outcome and later G44 readback are recorded in
[`v0.2-release-state.md`](v0.2-release-state.md). This closure record does not
move either release tag, replace any asset, or alter the production feed.

## G49 Publication Preparation

G49 consumes only the approved G48 candidate. Its input-free
`copylasso_prepare_publication` repository dispatch runs from protected
`main`, reruns canonical CI, downloads private release `367523470`, verifies
direct tag `v0.2.1-rc.1` at exact source commit
`813de17c739097217aad55a5a35c04ea3c73d99f`, and reverifies all four pinned
asset sizes and digests without rebuilding or notarizing again.

Only the protected preparation job receives `contents: write`. The release
team identifier enters only package verification, and the Sparkle seed enters
only final-appcast generation after the candidate bytes and shipped public key
match. The job prepares a feed-only bundle and a private, non-prerelease final
draft containing exactly the DMG and checksum. It uploads a restricted handoff
for maintainer readback but cannot publish the draft, create or move a tag,
replace an asset, or deploy the feed.

Publication is a later operator transaction after the protected handoff is
verified. The annotated signed final tag and RC tag must peel to the same G48
commit. The exact final draft is published before the authenticated appcast is
deployed to the existing feed-only endpoint. Any ambiguous or failed readback
stops publication without replacement or retry-by-mutation.
