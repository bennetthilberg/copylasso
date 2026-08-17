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

- [x] Confirm every required prior gate is green, every accepted evidence gap is recorded, and no source or artifact has changed since candidate qualification.
- [x] Create the final `v0.1.0` tag on the same commit as the qualified release candidate and verify the tag remotely.
- [x] Date the `0.1.0` changelog entry, update the README download link and checksum instructions, and verify the final documentation commit relationship required by the roadmap.
- [x] Publish only the exact qualified DMG and checksum assets; never replace an asset under an existing release tag.
- [x] Download the public artifacts in a fresh browser session, verify hashes, signatures, notarization, version/build, and successful launch, then record the public URLs and results.
- [x] Confirm the release page, repository homepage, security policy, contribution link, privacy policy, license, and third-party notices are reachable.
- [x] Announce completion only after the post-publication smoke check is green.

## G32 - v0.1.1 Settings Hotfix

- [x] Confirm the exact protected commit contains the merged Settings presentation fix, version `0.1.1`, build `2`, and no unrelated application behavior.
- [x] Pass the release-metadata, Developer ID, package, protected-workflow, brand, privacy, CI-contract, canonical arm64/x86_64, and macOS 14 gates.
- [x] After separate pull-request merge approval, dispatch candidate `v0.1.1-rc.N` from that exact protected `main` commit and approve only the protected release environment.
- [x] Read back the private draft, four exact assets, reviewed `0.1.1` notes, checksums, GitHub digests, target commit, signed application, notarization, Gatekeeper result, version/build, Universal 2 slices, and two-item DMG layout.
- [x] Create a signed annotated `v0.1.1` tag on the qualified commit, publish only the exact DMG and checksum as the latest non-prerelease release, and leave `v0.1.0` plus all private historical drafts unchanged.
- [x] Download the public DMG with genuine quarantine, repeat checksum/signature/notarization/Gatekeeper/install verification, and smoke Settings plus one capture.
- [x] With action-time confirmation, reset only `ScreenCapture` for `io.github.bennetthilberg.copylasso`, grant the public app once, and verify one current CopyLasso privacy row.

## G33 - Platform And Reinstall Qualification

- [x] Prevent canonical ordinary Release builds from retaining generated production-identifier Launch Services registrations while refusing every installed, symlinked, or out-of-root app.
- [x] Run the platform-qualification audit and behavior tests exactly once through canonical CI, including successful-build and failed-build cleanup.
- [x] Move continuous artifact launch smoke to maintained macOS 15 while retaining deployment target 14.0, Mach-O minimum-version verification, Universal 2 output, and real macOS 14 as a manual release gate.
- [x] Qualify ordinary reinstall with preferences retained and enabled/disabled Launch at Login across sign-in or restart using the exact public CopyLasso 0.1.1 DMG.
- [x] Qualify the complete scoped uninstall/reinstall; record the maintainer-stopped disposable-account recreation as skipped rather than an account-isolation or VM-clone pass.
- [x] Restore the exact public installation and intended maintainer settings, confirm it is the sole production Launch Services registration, and close issue #41 through the ready G33 pull request.

## G34 - v0.2 Product Contract

- [x] Preserve the historical v0.1 contract and document v0.2 as approved planned scope rather than shipped 0.1.1 behavior.
- [x] Lock automatic-update, success-sound, separate capture-command, QR/barcode, conditional LaTeX, privacy, accessibility, and version/build decisions.
- [x] Add the focused v0.2 contract audit and enforce exactly one canonical CI invocation.
- [x] Narrow issue #38 to on-screen QR/barcode recognition and create separate issues for file/PDF input, configurable success sound, and conditional offline LaTeX recognition.
- [x] Pass both canonical architectures, hosted checks, exact-head review, and final ready-PR readback without changing application source, dependencies, entitlements, release metadata, feeds, tags, or public artifacts.

## G35 - Secure Update Architecture Proof

- [x] Compare a maintained permissive updater with a first-party implementation and record the accepted architecture, scope, dependency pin, license, and acknowledgement gate.
- [x] Threat-model feed, hosting, transport, workflow, signing-key, replay/downgrade, malformed input, interruption, disk, cancellation, privacy, and recovery boundaries.
- [x] Prove real comparator and offline Ed25519 archive/appcast behavior with only ephemeral fixture keys; reject tampering, wrong keys, mismatched metadata, unapproved URLs, replay, downgrade, malformed/oversized input, and interrupted transactions.
- [x] Confirm Sparkle remains test-only during G35, CopyLasso.app has no updater configuration or network entitlement at that historical goal, release metadata remains `0.1.1 (2)`, and no key, appcast, or public update artifact is created.
- [x] Run focused proofs, privacy/security and secure-update audits, canonical arm64/x86_64 pipelines, hosted checks, exact-head review, and ready-PR readback.
- [x] Preserve the operations and 0.1.x manual-bootstrap record for G36; do not create production key material, publish a feed, install an update, or start G36.

## G36 - User-Controlled Secure Updates

- [x] Link only pinned Sparkle 2.9.4 into the application, ship its complete local notice, and verify the Universal 2 framework plus nested helpers in Debug and Release products.
- [x] Retain only App Sandbox, outbound network client, and Sparkle's two versioned installer-service names; disable the downloader service, system profiling, cookies, external release notes, automatic downloads, and automatic installation.
- [x] Verify the fixed signed-feed/public-key configuration, exact GitHub enclosure policy, canonical build ordering, authenticated high-water replay protection, inline plain-text notes, 256 MiB cap, and exact streaming length.
- [x] Verify automatic checks default on and can be disabled, the menu and Settings manual command share one updater, and Download plus Install and Relaunch are separate keyboard- and VoiceOver-accessible decisions with Later, Cancel, close, retry, and offline recovery.
- [x] Confirm capture, onboarding, Settings, TCC recovery, Launch at Login, lifecycle cleanup, clipboard privacy, and core offline behavior remain independent of updater startup or networking failure.
- [x] Store the production private key only in the nonsynchronized login Keychain, protected GitHub `release` environment, and encrypted offline recovery; compile only the public key and scan repository, logs, build products, and evidence for leakage.
- [x] Generate and verify one exact signed appcast inside the protected candidate verification bundle; do not upload a standalone appcast, publish a feed, create a public update artifact, or modify the public 0.1.x release.
- [x] Qualify a private signed older-to-newer update, deferral, cancel/failure preservation, install/relaunch, preference retention, Launch at Login reconciliation, post-update capture, rollback rejection, and update networking denied while capture remains usable.
- [x] Run focused updater tests, privacy/security and dependency audits, canonical arm64/x86_64 pipelines, hosted macOS checks, Developer ID/notarization/Gatekeeper verification, exact-head review, and ready-PR readback.

## G37 - Configurable Success Sound

- [x] Ship exactly one original, deterministic, documented success-sound asset and verify its source, format, digest, and bytes in Debug plus Universal 2 Release products.
- [x] Default the versioned preference on while preserving explicit opt-out, expose one native accessible Settings toggle, and verify persistence plus Debug reset.
- [x] Request sound exactly once only after a successful nonempty clipboard write; keep cancellation, no text, permission, selection, capture, OCR, formatting, and clipboard-failure paths silent.
- [x] Confirm playback receives no private content, fails silently when unavailable, never requests recording or notification permission, never activates the app, and never delays or fails capture.
- [x] Verify rapid reuse restarts one short sound without stacking and lifecycle cancellation/termination performs idempotent cleanup.
- [x] Run focused service/workflow/settings tests, deterministic asset and privacy audits, canonical arm64/x86_64 pipelines, hosted checks, signed manual audibility/accessibility/output checks, exact-head review, and ready-PR readback.

## G38 - Unified On-Screen Code Recognition

- [x] Recognize QR, Code 128, Data Matrix, PDF417, and Aztec through the existing Capture command and shortcut, with code precedence and OCR fallback.
- [x] Keep payloads inert, local, memory-only, deterministically ordered, deduplicated, and protected from ambiguous multiline merging.
- [x] Pass deterministic real-Vision fixtures, workflow integration, shortcut/Space regressions, privacy audits, signed UI smoke, both canonical architectures, hosted checks, and exact-head review.
- [x] Leave issue #38 open for public-release verification and create no file, camera, payload-action, or additional-permission path.

## G39 - Offline LaTeX Feasibility

- [x] Screen candidate models and runtimes against licensing, provenance, size, macOS 14, Universal 2, sandbox, and required-hardware preblind gates.
- [x] Record no-go because no candidate passed every mandatory preblind gate; do not unseal a blind corpus or create production LaTeX code, model data, dependency, command, or UI.
- [x] Pass deterministic feasibility tests, production-boundary audit, both canonical architectures, hosted checks, exact-head review, and maintainer no-go confirmation.

## G40A - Refined Success Sound

- [x] Replace the original sound with maintainer-selected candidate 17 while retaining the existing default, preference, playback timing, accessibility, and failure policy.
- [x] Prove deterministic native/Rosetta generation, exact bundled digest, one shipped audio asset, sound and workflow tests, both canonical architectures, hosted checks, exact-head review, and signed enabled/disabled listening acceptance.

## G41 - v0.2 Feature Qualification

An unchecked G41 manual row is an explicitly retained Blocked result, not an
inferred pass; see [`v0.2-release-qualification.md`](v0.2-release-qualification.md).

- [x] Freeze source at `0.2.0 (3)` with updater, candidate-17 sound, unified text/code recognition, and no LaTeX implementation.
- [x] Finalize the undated changelog draft, reviewed release notes, public-versus-source wording, known limitations, manual 0.1.x updater bootstrap, and scoped uninstall.
- [x] Pass the v0.2 contract and release-qualification audits exactly once through canonical CI, plus focused preference, updater, sound, recognition, lifecycle, accessibility, and privacy tests.
- [x] Complete the signed current-host functional, appearance, VoiceOver, multi-display, lifecycle, latency, idle, memory, and 100-cycle delta matrix without promoting historical blocked rows.
- [ ] Complete every row of one fresh, narrow real macOS 14
      browser-quarantined clean-install smoke. A separate Sonoma 14.6.1 guest
      passed download, quarantine, digest, install, Gatekeeper, onboarding,
      permission denial/recovery, OCR, settings, safe unavailable-update
      handling, and quit/relaunch; VirtualBuddy input/audio limitations keep QR
      precedence, audible sound, and post-updater capture Blocked.
- [x] Verify an exact-head Developer ID application, notarization, stapled DMG, checksum, Gatekeeper, Universal 2 slices, dSYM, reviewed entitlements, and locally authenticated update metadata.
- [x] Pass local and hosted arm64/x86_64 plus maintained macOS 15 checks and exact-head review; stop with a ready PR and no release candidate.

## G42 - v0.2 Release Candidate

- [x] After G41 merges, dispatch the protected workflow from the exact protected-main commit with a new positive `candidate_number`.
- [x] Create and qualify one immutable private `v0.2.0-rc.N` draft, four restricted assets, authenticated update metadata, and browser-quarantined installation without rebuilding.
- [x] Exercise the private staged updater path, classify blockers and accepted gaps, and obtain explicit maintainer approval or rejection. Do not publish.

## G43 - Publish CopyLasso v0.2.0

- [x] Merge the green G43 publication-control PR before dispatching the protected preparation workflow.
- [x] Dispatch the input-free G43 workflow from that exact protected-main commit and approve the existing `release` environment.
- [x] Read back the unchanged private `v0.2.0-rc.1` candidate, four restricted assets, exact source commit, reviewed notes, and all recorded sizes and SHA-256 digests.
- [x] Reverify the exact candidate package without rebuilding, then generate and independently authenticate one final-URL `appcast.xml` through the existing Sparkle signing boundary.
- [x] Create and read back one private, non-prerelease `v0.2.0` draft containing only the approved DMG and checksum. Keep the dSYM and verification bundle restricted to the RC draft.
- [x] Create a signed annotated `v0.2.0` tag on the same source commit as `v0.2.0-rc.1`; verify it locally and require GitHub `verified: true` before publication.
- [x] Publish the exact final draft by release ID as public, non-prerelease, and latest without replacing an asset or moving either tag.
- [x] Establish the feed-only Cloudflare Pages project and `updates.copylasso.com` CNAME without changing apex DNS or nameservers, then deploy the exact signed appcast only after the public GitHub URL is valid.
- [x] Verify public release state, two uploaded assets, generated source archives, feed and enclosure signatures, final URL and length, version ordering, and unauthenticated download behavior.
- [x] Perform a genuine-quarantine Safari download, complete signature/notarization/Gatekeeper/package verification, manual installation smoke, and isolated public updater-path smoke.
- [x] Confirm `0.1.x` users are told to install `0.2.0` manually and publish no website, Mac App Store build, Homebrew Cask, or unrelated artifact.

## G44 - Close the v0.2 Release State

- [x] Date the changelog from the actual publication timestamp and update release-state documentation without changing immutable release bytes.
- [x] Close only shipped-and-publicly-verified feature issues, install the exact public app locally, and read back protected main, checks, tags, assets, feed, source archives, issues, and the final ready PR.

## G48 - Qualify CopyLasso v0.2.1

- [x] Phase 1: freeze current source at `0.2.1 (4)`, add reviewed maintenance notes, reconcile public-versus-candidate documentation, and pass the focused G48 qualification audit exactly once through canonical CI.
- [x] Phase 1: update the protected workflow from historical G42 execution paths to G48 while retaining exact-main provenance, one positive `candidate_number`, protected credentials, derived asset names, draft-only output, and no publication path.
- [x] Phase 1: pass local and hosted arm64/x86_64 plus maintained macOS 15 checks, Universal 2 Release verification, exact-head review, and ready-PR readback; stop for separate merge approval without dispatching the workflow.
- [x] Phase 2: after the reviewed head is separately merged, dispatch from exact protected main with the first unused candidate number and create one immutable private `v0.2.1-rc.N` draft with four restricted assets.
- [x] Phase 2: verify signatures, notarization, Gatekeeper, package layout, checksums, GitHub digests, dSYM UUIDs, authenticated candidate metadata, browser quarantine, and the compact current-host capture matrix without rebuilding.
- [x] Phase 2: exercise an isolated update from exact public `0.2.0 (3)` to the byte-identical candidate, record the maintainer decision, and leave the candidate unpublished.

## G49 - Publish CopyLasso v0.2.1

- [x] Begin only after the exact G48 private candidate is separately approved. Revalidate immutable candidate identity before changing publication controls.
- [x] Phase 1: merge the green G49 publication-control PR before dispatching the protected preparation workflow.
- [x] Phase 2: reverify the immutable candidate without rebuilding, create the private two-asset final draft and final-URL appcast, then publish the signed final tag, exact DMG and checksum, and authenticated feed through the approved transaction.
- [x] Phase 2: complete unauthenticated public-download, updater, installation, source-archive, feed, and immutable-tag verification.
- [x] Phase 3: date and close the public release state in a separate green ready PR without changing release bytes, tags, feed, or application code.

## G50 - Patch Sparkle Security Advisory

- [x] Phase 1: freeze source at `0.2.2 (5)`, pin Sparkle 2.9.5 at reviewed
  commit `79bc9e872948e47877e76f194cb0c8e0412b0b90`, and reject affected
  versions through 2.9.4 in canonical CI.
- [x] Phase 1: preserve exact current entitlements, updater-only networking,
  full-package-only appcast generation, and the immutable public v0.2.1 state.
- [x] Phase 1: pass local and hosted arm64/x86_64 checks, Universal 2 Release
  verification, bounded review, and ready-PR readback; stop for merge approval.
- [x] Phase 2: after a separately approved merge, create and fully qualify one
  private exact-head `v0.2.2-rc.N` candidate without publication.
- [x] Phase 3: merge the green, input-free protected preparation controls, then
  create and verify one private final draft and signed final-URL appcast without
  rebuilding, publishing, tagging, or deploying.
- [x] Phase 3: publish only the exact approved candidate through a verified
  signed final tag, two-asset public release, and byte-identical authenticated
  feed deployment; complete public download and updater verification.
- [x] Phase 3: close release-state documentation in a separate green pull
  request without changing release bytes, tags, application code, or feed.

## G54 - Qualify CopyLasso v0.3.0

- [x] Freeze merged v0.3 source at `0.3.0 (6)` while keeping public 0.2.2 and
  every historical tag, asset, feed record, and publication workflow immutable.
- [x] Draft reviewed v0.3 release notes, changelog, public-versus-source copy,
  upgrade guidance, complete uninstall, retained limitations, and the G55-G57
  gates.
- [x] Pass focused migration/integration checks, the v0.3 qualification audit
  exactly once through canonical CI, arm64/x86_64, Universal 2, hosted runtime,
  signed host, exact-head review, and private qualification-package gates.
- [x] Stop with a ready G54 PR. Do not dispatch a protected workflow, upload an
  artifact, create a tag, publish an update feed, or merge without the separate
  checkpoint.

## G55 - Private v0.3.0 Release Candidate

- [x] Record the unexecuted macOS 14 runtime row as an explicit maintainer-
  accepted residual risk after repeated VirtualBuddy black-screen failure;
  never relabel the row as passed or infer it from the macOS 15 hosted launch.
- [x] After G54 merges, dispatch one exact protected-main candidate build and
  derive a unique `v0.3.0-rc.N` private draft with exactly four restricted
  assets.
- [x] Qualify signatures, notarization, Gatekeeper, package layout, checksums,
  dSYM, authenticated candidate metadata, and a clean install of exact public
  0.2.2 and the exact candidate without modifying either release binary.
- [x] Build only the nonshipping 0.2.2-source updater fixture from signed tag
  `v0.2.2` with the existing loopback compile condition, update it with an
  archive of the untouched candidate app, and prove the installed payload
  matches that candidate byte-for-byte, mode-for-mode, and link-for-link.
- [x] With candidate approval, explicitly accept or reject the missing direct
  `updates.highestAuthenticatedBuild = 6` readback. The signed rollback check
  and persistence tests passed, but the operator guide omitted this command
  before the disposable account was deleted; do not call the readback passed.
- [x] Obtain explicit approval of the immutable candidate before publication.

## G56 - Publish CopyLasso v0.3.0

- [ ] Merge the reviewed G56 preparation controls before dispatching from exact
  protected `main`.
- [ ] Reverify immutable `v0.3.0-rc.1` candidate commit
  `c99bec65be187c02b920b6519152ba935ec44253` and DMG SHA-256
  `96f07eff7719f6c5b4b819af846d9ac825e13d4959d6f45d14d19fffa943bb96`
  without rebuilding.
- [ ] Create and read back one private non-prerelease final draft containing
  only the approved DMG and checksum plus one final-URL authenticated feed
  handoff.
- [ ] Create and verify one signed annotated `v0.3.0` tag on the approved
  candidate commit; never move the final or RC tag.
- [ ] Publish the exact draft by release ID as public, non-prerelease, and
  latest; never replace an uploaded asset.
- [ ] Deploy only the verified `appcast.xml` and headers after the public
  enclosure URL succeeds.
- [ ] Complete unauthenticated release, source-archive, genuine-quarantine
  download, install, and public `0.2.2` to `0.3.0` updater verification.
- [ ] Preserve the accepted macOS 14 and direct high-water readback gaps as
  accepted gaps rather than inferred passes.
- [ ] Stop before G57 release-state documentation, local final installation,
  or issue closure.

## G57 - Close The v0.3 Release State

- [ ] Date and reconcile release-facing documentation in a separate green PR,
  install the exact public build locally, and verify protected-main state.
- [ ] Close issue #37 after public history verification. Narrow issue #39 to
  deferred translation and text-to-speech instead of closing unshipped scope.
