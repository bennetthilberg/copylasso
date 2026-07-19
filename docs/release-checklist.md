# CopyLasso Release Checklist

This checklist defines the ordered evidence required to publish CopyLasso. G25 creates and reviews the checklist only. Developer ID signing, notarization, packaging, clean-install evidence, release-candidate promotion, tagging, and publication belong to G26 through G31.

Record every command, artifact name, SHA-256 checksum, commit, tag, signing identity class, notarization submission identifier, test host, and result in the corresponding roadmap goal evidence.

## G25 - Source And Documentation Preflight

- [ ] Confirm the release commit has a clean worktree and contains no build products, credentials, local paths, or unrelated changes.
- [ ] Confirm product name `CopyLasso`, production bundle identifier `io.github.bennetthilberg.copylasso`, version `0.1.0`, and monotonically increasing build `1` across Release settings and the built Info.plist.
- [ ] Repeat and record the exact-name collision review before creating public artifacts.
- [ ] Verify the original Default, Dark, and Mono app-icon renditions, every compiled macOS icon size, and the template menu-bar symbol.
- [ ] Verify About, README, privacy documentation, changelog draft, third-party notices, contribution guidance, known limitations, and complete uninstall instructions agree with implemented behavior.
- [ ] Run canonical local arm64 and x86_64 CI, hosted architecture jobs, macOS 14 runtime validation, formatting, source audits, and exact-head review.

## G26 - Developer ID Signing And Notarization

- [ ] Create the Release archive from the exact reviewed commit with the approved Developer ID Application identity.
- [ ] Record the archive path outside the repository, Xcode and SDK versions, signing identity class, confirmation that the configured Team ID matched without recording the identifier itself, version, build, architectures, and source commit.
- [ ] Verify the designated requirement, nested-code signatures, Hardened Runtime, App Sandbox entitlement, production bundle identifier, approved release team supplied outside the repository, and absence of debug-only settings.
- [ ] Submit the exact signed application or approved test container to Apple's notary service using the validated Team API key profile in the nonsynchronized login Keychain.
- [ ] Record the submission identifier and successful status, then staple and validate the notarization ticket.
- [ ] Re-run strict signature, Gatekeeper, entitlements, version/build, bundle-identifier, and architecture checks after stapling. Export only the qualified application for the next gate; do not publish it.

## G27 - Reproducible Release Package

- [ ] Follow the version-controlled process in [`release-packaging.md`](release-packaging.md) from a clean, exact packaging commit.
- [ ] Build the final disk image from the exact stapled application without rebuilding the app; include CopyLasso and an Applications-folder alias only.
- [ ] Verify the read-only DMG mount, drag-to-Applications layout, production identity, Universal 2 architectures, version/build, strict signature, Gatekeeper assessment, and stapled ticket.
- [ ] Record the DMG SHA-256 checksum, file size, embedded-app checksum, source commit, version/build, and notarization linkage.
- [ ] Preserve the matching dSYM separately and verify its UUIDs match both shipped executable architectures.
- [ ] Run the package process twice from a clean source state and compare the verified results, allowing only expected signing/notarization metadata differences. Keep all output in ignored `dist/` and do not publish it.

## G28 - Protected Release Workflow

- [ ] Add a manually triggered or protected-tag GitHub Actions workflow that runs the complete test gate before archive generation.
- [ ] Prove ordinary pull requests cannot trigger signing or read release secrets; import credentials only for the protected job and clean them up afterward.
- [ ] Produce the signed, notarized DMG, checksum, and dSYM from the exact protected commit and run the same verification as G27.
- [ ] Inspect workflow permissions, secret masking, cleanup, failure behavior, and logs; failed tests or verification must prevent draft creation.
- [ ] Create and verify a draft GitHub release only. Download its artifacts and rerun local package verification; do not publish it.
- [ ] Keep the dSYM and verification bundle restricted to the draft and remove both before any G31 public publication.

## G29 - Clean Installation Test Environment

- [ ] Preserve the version-controlled [`clean-install-testing.md`](clean-install-testing.md) procedure and classify every recorded result as a factual Pass or a reasoned accepted Blocked gap.
- [ ] Retain the verified VirtualBuddy installation, stopped macOS 14 baseline, disposable-clone workflow, and exact candidate/isolation metadata without committing VM assets.
- [ ] Record the exact browser-downloaded Sonoma rehearsal evidence for quarantine, checksum, Gatekeeper, first launch, permission denial and recovery, shortcut/menu capture, OCR, clipboard, and HUD behavior.
- [ ] Record the incomplete latest-stable setup and unexecuted enabled-login restart, ordinary reinstall, complete uninstall, and clone-recreation scenarios as Blocked rather than inferring results.
- [ ] Keep the scoped ordinary and complete uninstall procedures reusable. Do not resume VM qualification or publish the release during G29.

## G30 - Release Candidate Qualification

For G30, "remaining" means the rows in this section plus exact-candidate revalidation of the
applicable automated G25-G29 gates. Earlier unchecked template boxes retain their recorded goal
evidence and are not silently reclassified. Use
[`release-candidate-qualification.md`](release-candidate-qualification.md) for the bounded host
matrix and accepted-risk record.

- [ ] Phase 1: add reviewed RC mode support to the protected workflow, draft helper, static audit, and regression tests, then obtain separate approval to merge that source-enablement pull request to protected `main`.
- [ ] Phase 2: dispatch the post-merge protected workflow from that exact `main` commit with a new positive `candidate_number`; require it to derive and create the immutable `v0.1.0-rc.N` tag and corresponding draft prerelease without accepting an arbitrary tag.
- [ ] Read back the RC draft as `draft: true` and `prerelease: true`; verify its reviewed notes, exact target commit, four required assets, GitHub asset digests, DMG checksum, and refusal to overwrite an existing tag or release. Collision and rollback behavior is proven through focused fake-GitHub regressions rather than a second privileged live dispatch.
- [ ] Download the private draft DMG and checksum with authenticated maintainer tooling, verify them, then expose only those files through a temporary loopback-only server for the disposable account's Safari download. Do not sign the disposable account in to GitHub or add quarantine manually.
- [ ] Confirm canonical and hosted CI, package verification, host manual QA, Intel automated checks, and a fresh browser-download/Gatekeeper/install/core-capture smoke in a disposable local macOS user account on the maintainer's latest-stable host all identify that same commit and artifact checksum.
- [ ] Before downloading the candidate in that account, verify CopyLasso's application, production preferences, production container, login item, and Screen Recording approval are absent so stale state cannot satisfy first-launch or permission-recovery checks.
- [ ] Carry the G29 partial rehearsal and every accepted VM/reinstall evidence gap into the candidate risk record; do not describe a Blocked row as qualified.
- [ ] Classify every issue as release-blocking, known limitation, or deferred; any fix creates a new candidate and reruns the complete gate.
- [ ] Land final release notes and the risk template before candidate creation, then use the disposable account's one fresh Safari download after draft creation as the candidate qualification and final browser readback.
- [ ] Confirm the release remains unpublished and the candidate tag, artifacts, notes, changelog, and documentation identify the same version/build and commit.

## G31 - Final Tag And Publication

- [ ] Confirm every required prior gate is green, every accepted evidence gap is recorded, and no source or artifact has changed since candidate qualification.
- [ ] Create the final `v0.1.0` tag on the same commit as the qualified release candidate and verify the tag remotely.
- [ ] Date the `0.1.0` changelog entry, update the README download link and checksum instructions, and verify the final documentation commit relationship required by the roadmap.
- [ ] Publish only the exact qualified DMG and checksum assets; never replace an asset under an existing release tag.
- [ ] Download the public artifacts in a fresh browser session, verify hashes, signatures, notarization, version/build, and successful launch, then record the public URLs and results.
- [ ] Confirm the release page, repository homepage, security policy, contribution link, privacy policy, license, and third-party notices are reachable.
- [ ] Announce completion only after the post-publication smoke check is green.
