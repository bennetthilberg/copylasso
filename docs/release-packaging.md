# Release Packaging

This document defines the local G27 process that turns the exact G26 Developer ID handoff into the disk image intended for later release qualification. It creates no public release and uploads nothing except the signed disk image submitted privately to Apple's notarization service.

## Immutable inputs

G27 must reuse the exact G26 application, archive dSYM, accepted notarization records, and payload commit. It must not archive, export, rebuild, modify, or re-sign `CopyLasso.app`.

The payload commit identifies the application contents. The packaging commit separately identifies the version-controlled scripts that create and verify the disk image. Both full commit identifiers are recorded in ignored local evidence.

Before packaging:

1. Confirm G26 is merged and the packaging branch descends from its qualified payload commit.
2. Confirm the tracked worktree is clean.
3. Confirm the G26 handoff directory is named with the full payload commit and still contains `export/CopyLasso.app`, `CopyLasso.xcarchive/dSYMs/CopyLasso.app.dSYM`, and matching accepted notarization records.
4. Unlock the login Keychain if needed. The valid Developer ID Application private key remains there.
5. Load the approved team identifier into `COPYLASSO_EXPECTED_TEAM_ID` without writing it to a command, file, or log. Authentication continues to use the `copylasso-notary` Keychain profile established in G26.

The packaging script refuses a dirty tracked tree, a handoff/commit mismatch, more than one matching signing identity, an output outside ignored `dist/`, or application-input changes after the payload commit.

## Create two local packages

Set local shell variables without committing their values:

```bash
PAYLOAD_COMMIT="<full G26 payload commit>"
PACKAGING_COMMIT="$(git rev-parse HEAD)"
G26_HANDOFF="$HOME/Library/Developer/CopyLasso/G26/$PAYLOAD_COMMIT"
read -r -s COPYLASSO_EXPECTED_TEAM_ID
export COPYLASSO_EXPECTED_TEAM_ID
```

Run the complete process twice from that same clean source state. Each run creates, signs, notarizes, staples, and verifies its own disk image, so each has a distinct Apple submission:

```bash
./scripts/package-release.sh \
  --handoff "$G26_HANDOFF" \
  --payload-commit "$PAYLOAD_COMMIT" \
  --output-dir "$PWD/dist/g27/$PACKAGING_COMMIT/run-1"

./scripts/package-release.sh \
  --handoff "$G26_HANDOFF" \
  --payload-commit "$PAYLOAD_COMMIT" \
  --output-dir "$PWD/dist/g27/$PACKAGING_COMMIT/run-2"
```

The script deliberately uses the saved `copylasso-notary` profile. It never accepts an Apple ID or app-specific password. A Keychain or Touch ID confirmation may still appear when signing the disk image.

Each run produces:

- `CopyLasso-0.1.0.dmg`, a signed, notarized, stapled, read-only UDZO image;
- `CopyLasso-0.1.0.dmg.sha256`, the public-form SHA-256 checksum record;
- `CopyLasso-0.1.0.dSYM.zip`, the matching private symbol archive;
- the accepted submission record and complete Apple diagnostic log;
- payload, UUID, signature, stapling, and final-verification evidence; and
- `release-evidence.txt`, containing only portable metadata rather than local paths or account values.

The mounted image must contain exactly `CopyLasso.app` and an `Applications` link that resolves to `/Applications`. It contains no installer, helper, README, background, or hidden layout metadata.

## Verify and compare

The package script calls the verifier before it reports success. It can also be run directly:

```bash
./scripts/verify-release-package.sh \
  --payload-app "$G26_HANDOFF/export/CopyLasso.app" \
  --payload-commit "$PAYLOAD_COMMIT" \
  --packaging-commit "$PACKAGING_COMMIT" \
  "$PWD/dist/g27/$PACKAGING_COMMIT/run-1"
```

Verification covers the checksum, Developer ID disk-image signature and timestamp, accepted notarization records, stapled ticket, Gatekeeper disk-image assessment, UDZO format, read-only mount, exact volume layout, embedded application identity and signatures, payload manifest, version `0.1.0`, build `1`, production bundle identifier, both architectures, and dSYM UUIDs.

Compare the two complete runs:

```bash
./scripts/compare-release-packages.sh \
  "$PWD/dist/g27/$PACKAGING_COMMIT/run-1" \
  "$PWD/dist/g27/$PACKAGING_COMMIT/run-2"
```

The comparison requires identical mounted application manifests and normalized provenance. The DMG byte streams, checksums, sizes, filesystem metadata, signatures, tickets, and submission identifiers may differ because each run is independently signed and notarized.

Finally, mount the selected verified image in Finder, confirm that it is read-only, drag CopyLasso through its Applications link only if no existing installation would be overwritten, launch that installed copy, verify `Version 0.1.0 (1)`, then quit it. Preserve the selected DMG, checksum, dSYM archive, and evidence under ignored `dist/`.

## Recovery and handoff

- If a run fails, preserve its directory for diagnosis and start a fresh run directory after correcting the cause.
- If Apple rejects a submission, inspect the saved diagnostic log. Do not use `--force`, bypass validation, or staple a rejected image.
- If the payload fails verification, stop. Repairing or regenerating the G26 application is outside G27.
- If any tracked commit changes after qualification, rerun both complete packages at the new packaging commit.
- Keep the dSYM archive private and restricted even though it contains no signing credential.

Do not publish, tag, upload, or create a GitHub release in G27. G28 later introduces protected release CI and a draft-release rehearsal using the exact verified packaging contract.

G28 invokes this same package script only after it has archived, exported, notarized, stapled, and
verified an application from the exact protected workflow commit. It constructs the same
commit-addressed handoff layout, uses that commit as both payload and packaging provenance, and does
not weaken any G27 package check. See [`release-workflow.md`](release-workflow.md).
