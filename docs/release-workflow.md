# Protected Release Workflow

G28 adds a manually dispatched GitHub Actions workflow that builds one signed, notarized, and
verified CopyLasso release rehearsal from the exact protected `main` commit. It creates a draft
prerelease and never publishes it. G29 retains a reusable clean-install procedure and partial
Sonoma rehearsal with explicit accepted gaps; G30 immutable release-candidate qualification uses a
fresh browser/Gatekeeper/core smoke on the maintainer host, and G31 remains the publication gate.

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
- the six environment secrets listed below.

The environment must not expose these values as repository-level secrets:

| Environment secret | Purpose |
| --- | --- |
| `COPYLASSO_DEVELOPER_ID_P12_BASE64` | Base64 of the password-protected Developer ID identity export |
| `COPYLASSO_DEVELOPER_ID_P12_PASSWORD` | Password for that identity export |
| `COPYLASSO_NOTARY_KEY_BASE64` | Base64 of the dedicated Team API private key |
| `COPYLASSO_NOTARY_KEY_ID` | Dedicated Team API key identifier |
| `COPYLASSO_NOTARY_ISSUER_ID` | App Store Connect issuer identifier |
| `COPYLASSO_EXPECTED_TEAM_ID` | Approved Developer ID team used for independent verification |

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

## Run The Rehearsal

After the G28 source pull request is reviewed, green, and separately merged:

1. Open **Actions > Protected Release Candidate > Run workflow** and select `main`.
2. Confirm the run's commit is the intended protected `main` commit.
3. Wait for the complete reusable CI gate.
4. Approve the `release` environment when GitHub requests deployment review.
5. Allow the protected job to archive, export, notarize, staple, package, verify, clean credentials,
   and create its draft.

Only one protected release run may execute at a time. A failure is never promoted by rerunning only
a later step: correct the cause, create a new green commit if tracked code changed, and dispatch the
complete workflow again.

The workflow uses the G26 application verifier and G27 package process. Its protected commit is both
the application payload commit and packaging commit. The resulting draft tag uses the nonrelease
form `v0.1.0-g28.<run>` so it cannot be mistaken for G30's `v0.1.0-rc.N` candidate.

## Draft Assets And Local Readback

The draft prerelease contains exactly:

- `CopyLasso-0.1.0.dmg`;
- `CopyLasso-0.1.0.dmg.sha256`;
- `CopyLasso-0.1.0.dSYM.zip`; and
- `CopyLasso-0.1.0-verification.zip`.

The verification bundle contains the exact stapled source application and the portable records
needed to reconstruct the release-run directory after downloading the other three assets. Download
all four assets into an ignored, commit-addressed directory, expand the verification bundle, place
the DMG, checksum, and dSYM beside its `run` evidence, and invoke `verify-release-package.sh` with
the bundled `payload/<commit>/export/CopyLasso.app`. The supplied payload and packaging commits are
both the protected workflow commit.

Read back the draft through GitHub after upload. It must remain `draft: true` and `prerelease: true`,
target the exact commit, and contain exactly the four assets above. Recompute the public checksum
and rerun the complete local package verifier. Preserve the downloaded dSYM and verification bundle
as restricted maintainer evidence.

The dSYM and verification bundle are intentionally draft-only. Remove them from the eventual G31
public release; only the already-qualified DMG and checksum become public release assets. Never publish the G28 rehearsal.

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
- **Suspected exposure:** cancel active release runs, revoke the affected Apple credential, delete
  the protected environment value, inspect workflow history, and create a replacement before
  another dispatch.
- **Apple rejection:** retain the private diagnostic evidence, fix the signing or source problem in a
  reviewed commit, and restart from the complete quality gate. Never staple or draft a rejected
  artifact.
- **Stale draft:** delete the incomplete rehearsal through GitHub Releases. Never overwrite assets
  under an existing draft tag.

G28 stops after one exact workflow run, downloaded local re-verification, log and cleanup inspection,
and a verified draft release. It does not configure a clean VM or publish a download.
