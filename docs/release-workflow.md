# Protected Release Workflow

The manually dispatched workflow builds one signed, notarized, and verified
CopyLasso release from the exact protected `main` commit. It creates a private
draft prerelease and never publishes it. G32 uses that existing trust boundary
for the `0.1.1` Settings-presentation hotfix. A final release is published only
after the draft, asset digests, checksum, signed application, Gatekeeper result,
and smoke test have been independently read back.

## Trust Boundary

The workflow file must exist on the default branch before GitHub accepts its `workflow_dispatch`
event. Run it only by choosing `main` in the Actions interface or by dispatching the workflow with
`--ref main`.
The workflow itself rejects every ref except `refs/heads/main`, requires the checked-out `HEAD` to
equal the dispatched full commit, and requires that commit to equal `origin/main`.

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

Generate the Sparkle Ed25519 identity once with the pinned Sparkle 2.9.4 tooling. Keep its private
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

## Run A Private Rehearsal

After the G32 source pull request is reviewed, green, and separately merged:

1. Open **Actions > Protected Release Candidate > Run workflow** and select `main`.
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
`v0.1.1-g32.<run>` so it cannot be mistaken for G32's `v0.1.1-rc.N` candidate.

## G30 Protected Candidate Handoff

G30 introduced the two-phase protected candidate handoff used for the public
`0.1.0` release: first merge the reviewed workflow enablement, then dispatch a
candidate from that exact protected `main` commit.

The G28 rehearsal draft and its assets cannot serve as G30 evidence. That historical release
record remains immutable; G32 reuses the same trust boundary with new version-derived names.

## G32 Maintenance Candidate Handoff

G32 has two ordered phases.

1. Land a reviewed source-enablement pull request that adds a distinct RC mode to the protected
   workflow, draft helper, static audit, and regression tests. Because `workflow_dispatch` uses the
   workflow on the default branch, this phase requires a separately approved merge to protected
   `main` before candidate creation can begin.
2. In the post-merge protected run, supply only a validated positive `candidate_number`; derive
   `v0.1.1-rc.N` inside the workflow, refuse an existing tag or release, and build the exact merged
   `main` commit through the complete quality gate and `release` environment. The job must sign,
   notarize, staple, package, clean credentials, and transactionally create a draft prerelease with
   the same four-asset contract. Readback must prove the exact target commit, tag, draft/prerelease
   state, asset names, GitHub asset digests, and DMG checksum. Any later tracked change abandons that
   candidate and uses a new number.

`candidate_number` is the workflow's sole input. Leaving it blank selects a
private G32 rehearsal; a positive canonical integer selects the G32 candidate
path. Values with a sign, leading zero, decimal,
whitespace, or tag text are rejected before they influence a tag or path. No arbitrary tag, ref, or
mode input exists.

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

## Draft Assets And Local Readback

The draft prerelease contains exactly:

- `CopyLasso-0.1.1.dmg`;
- `CopyLasso-0.1.1.dmg.sha256`;
- `CopyLasso-0.1.1.dSYM.zip`; and
- `CopyLasso-0.1.1-verification.zip`.

The verification bundle contains the exact stapled source application, the authenticated
`appcast.xml` generated for that exact candidate, and the portable records
needed to reconstruct the release-run directory after downloading the other three assets. Download
all four assets into an ignored, commit-addressed directory, expand the verification bundle, place
the DMG, checksum, and dSYM beside its `run` evidence, and invoke `verify-release-package.sh` with
the bundled `payload/<commit>/export/CopyLasso.app`. The supplied payload and packaging commits are
both the protected workflow commit.

The appcast inside the restricted verification bundle is evidence, not a publication asset. The
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

G32 stops its protected-workflow phase after one exact run, downloaded local
re-verification, log and cleanup inspection, and a verified draft release. It
does not publish until the separately verified promotion step.
