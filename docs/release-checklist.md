# CopyLasso Release Checklist

This checklist defines the ordered evidence required to publish CopyLasso. G25 creates and reviews the checklist only. Developer ID signing, notarization, packaging, clean-host qualification, release-candidate promotion, tagging, and publication belong to G26 through G31.

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
- [ ] Verify the designated requirement, nested-code signatures, Hardened Runtime, App Sandbox entitlement, production bundle identifier, and absence of debug-only settings.
- [ ] Submit the exact signed application or approved test container to Apple's notary service using the validated Team API key profile in the nonsynchronized login Keychain.
- [ ] Record the submission identifier and successful status, then staple and validate the notarization ticket.
- [ ] Re-run strict signature, Gatekeeper, entitlements, version/build, bundle-identifier, and architecture checks after stapling. Export only the qualified application for the next gate; do not publish it.

## G27 - Reproducible Release Package

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

## G29 - Clean Installation Test Environment

- [ ] Create untouched baseline and disposable-clone workflows for macOS 14 and the latest stable macOS; keep CopyLasso absent and unapproved on every baseline.
- [ ] Download the exact draft-release DMG through a browser inside each clone so normal quarantine and Gatekeeper behavior remain authoritative.
- [ ] Verify first launch, onboarding, Screen Recording denial and recovery, shortcut/menu capture, OCR, clipboard, HUD, Settings, Launch at Login, relaunch, and restart behavior.
- [ ] Verify ordinary deletion/reinstall retains preferences, while complete uninstall removes only CopyLasso's login item, production preferences/container, and production Screen Recording entry.
- [ ] Record host/VM details, OS build, artifact hash, steps, results, clone discard, and successful reset from a fresh baseline. Do not publish the release.

## G30 - Release Candidate Qualification

- [ ] Create the immutable release-candidate tag from the exact qualified commit.
- [ ] Confirm canonical and hosted CI, package verification, both clean-install VM runs, host manual QA, and Intel automated checks all identify that same commit and artifact checksum.
- [ ] Classify every issue as release-blocking, known limitation, or deferred; any fix creates a new candidate and reruns the complete gate.
- [ ] Prepare final release notes from the qualified implementation and evidence, then verify the draft-release artifacts through a fresh browser download.
- [ ] Confirm the release remains unpublished and the candidate tag, artifacts, notes, changelog, and documentation identify the same version/build and commit.

## G31 - Final Tag And Publication

- [ ] Confirm every prior gate is green and no source or artifact has changed since clean-host qualification.
- [ ] Create the final `v0.1.0` tag on the same commit as the qualified release candidate and verify the tag remotely.
- [ ] Date the `0.1.0` changelog entry, update the README download link and checksum instructions, and verify the final documentation commit relationship required by the roadmap.
- [ ] Publish only the exact qualified DMG and checksum assets; never replace an asset under an existing release tag.
- [ ] Download the public artifacts in a fresh browser session, verify hashes, signatures, notarization, version/build, and successful launch, then record the public URLs and results.
- [ ] Confirm the release page, repository homepage, security policy, contribution link, privacy policy, license, and third-party notices are reachable.
- [ ] Announce completion only after the post-publication smoke check is green.
