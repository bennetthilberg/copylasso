# Clean Installation Testing

This reusable procedure describes how to exercise an exact CopyLasso release
candidate as a new user receives it. G29 retained a partial macOS 14 rehearsal
and an incomplete latest-stable setup attempt; the maintainer ended further VM
execution before the full matrix completed. Those gaps are recorded explicitly
and are not release passes. G30 instead performs a fresh browser-download,
Gatekeeper, install, and core capture smoke on the maintainer's latest-stable
host from a disposable local macOS user account. Before download, verify that
account has no CopyLasso application, production preferences, production
container, login item, or Screen Recording approval. This document does not
publish a release.

## G33 Current Public-Release Qualification

G33 applies the reusable install and removal boundaries below to the exact
public CopyLasso 0.1.1 release: version `0.1.1`, build `2`, DMG
`CopyLasso-0.1.1.dmg`, and SHA-256
`8e2c139ee13d181a7928c9b29b37d9367f5f7296cf069404f12c0c5df5a389dc`.
The procedure defines the maintainer's latest-stable host plus a freshly
recreated disposable local macOS user as the clean-state boundary. The
application in `/Applications` is shared across users, but preferences, the
sandbox container, login-item approval, and TCC state are account-scoped. The
maintainer stopped the G33 run after deleting the retained disposable account
and before recreating it, so the account-isolation row remains explicitly
skipped rather than inferred from the completed maintainer-account checks.

This replaces the unexecuted VirtualBuddy clone recreation row. It does not
claim virtual-machine, APFS-clone, or additional operating-system coverage. A
macOS 15 hosted smoke does not qualify macOS 14 behavior. Real macOS 14
qualification remains a manual release gate using the preserved Sonoma evidence
and a fresh real-host run before a future release when runtime-sensitive code or
packaging changes.

The G33 sequence is:

1. Verify the installed app and public DMG identity, version/build, Developer ID
   signature, notarization, Gatekeeper result, and Universal 2 slices.
2. With production preferences retained, reinstall the exact app and confirm
   onboarding, shortcut, Settings, capture, and the selected Launch at Login
   state remain reconciled.
3. Enable Launch at Login and sign out/in or restart; confirm the dockless app
   returns. Disable it, repeat the transition, and confirm it stays absent until
   manually launched.
4. Perform only the documented CopyLasso uninstall: disable Launch at Login,
   quit, remove the application, delete the production preference domain and
   production container, and reset only `ScreenCapture` for
   `io.github.bennetthilberg.copylasso`. Reinstall and confirm clean onboarding,
   absent prior preference/container/login approval, and a fresh permission
   transition.
5. Recreate the disposable user, verify clean account-scoped state, install or
   use the shared public app, complete one capture, remove the user, recreate it,
   and prove the account-scoped state is clean again. Restore the exact public
   app and intended maintainer settings afterward.

| G33 scenario | Result |
| --- | --- |
| Exact public 0.1.1 artifact and installed-app identity | **Pass** - trusted DMG digest and disk-image verification matched; the installed app passed strict signing, stapled-ticket, Gatekeeper, production identity, `0.1.1 (2)`, and Universal 2 checks |
| Ordinary reinstall retains preferences and reconciles Launch at Login | **Pass** - Finder replaced the app from the exact DMG; preferences remained byte-identical, Settings and capture worked, and the enabled login item remained reconciled |
| Enabled Launch at Login survives sign-in or restart | **Pass** - the menu agent returned automatically after a real sign-out/sign-in and Background Task Management remained enabled |
| Disabled Launch at Login stays disabled across sign-in or restart | **Pass** - the menu agent stayed absent after a second real sign-out/sign-in and Background Task Management remained disabled |
| Complete scoped uninstall/reinstall returns clean state | **Pass** - only the production app, preference domain, container, login item, and scoped Screen Recording decision were removed; exact-DMG reinstall returned clean onboarding and a fresh permission transition, then capture succeeded |
| Recreated disposable user proves account isolation | **Skipped by maintainer** - the retained disposable account and home were deleted, but the maintainer stopped before replacement-account creation or testing; no account-isolation pass is claimed |
| Maintainer's exact public installation and intended settings restored | **Pass** - exact public app, default shortcut, enabled login item, granted Screen Recording access, working capture, and one production Launch Services registration were restored |

## G30 Host Account Substitution

G30 follows the bounded
[`release-candidate-qualification.md`](release-candidate-qualification.md)
procedure instead of this document's VM bridge steps. The maintainer account
downloads and verifies all four private draft assets, then serves only the DMG
and checksum on `127.0.0.1`. Safari in the disposable local account performs
the genuine quarantined download after the system-wide Applications directory
and that account's CopyLasso-owned state have been proved clean. The account is
not signed in to GitHub, quarantine is not fabricated, and the accepted G29 VM
gaps remain blocked. Do not resume VirtualBuddy for v0.1.

## Qualified Tool And Candidate

The G29 host uses VirtualBuddy 2.1 build 325 from the project's official
[GitHub release](https://github.com/insidegui/VirtualBuddy/releases/tag/2.1).
The downloaded `VirtualBuddy_v2.1-325.dmg` must be exactly 18,013,135 bytes and
have SHA-256
`6ed17e8d7245931fd405c419321ace7ef9333fe2e3d59b3a7f78e34fcbe628b6`.
Before installation, verify its app with `codesign --verify --deep --strict`,
`spctl --assess --type execute`, and `xcrun stapler validate`. VirtualBuddy is
licensed under the BSD 2-Clause license. No VirtualBuddy binary, macOS restore
image, VM bundle, or guest disk belongs in this repository.

The G29 candidate is the unpublished G28 draft tag
`v0.1.0-g28.295914448081`, built from commit
`5fe10a68a8438b5cd346030eb1e9ad70918e76b4`. Its authoritative payload is:

| Field | Required value |
| --- | --- |
| File | `CopyLasso-0.1.0.dmg` |
| SHA-256 | `0b38f85acd7507cbacfacb820d534ac60907c8d12bec08c3b7f41f6cf1d1952f` |
| Bundle | `io.github.bennetthilberg.copylasso` |
| Version/build | `0.1.0 (1)` |
| Architectures | `arm64 x86_64` |

The candidate commit and the later G29 documentation commit are intentionally
different. G30 must qualify its own immutable candidate rather than treating
this record as publication authority.

## Environment Record

Record these values before each run. Keep screenshots and raw logs outside the
repository. Do not retain an Apple Account, local account password, signing
subject, raw login-item database, TCC database, private host path, or captured
user content.

| Field | Required record |
| --- | --- |
| Date and operator | Calendar date and maintainer role |
| Host | Mac model/chip, memory, macOS version and build |
| Virtualizer | VirtualBuddy version/build, verified digest and Gatekeeper result |
| Baseline | Immutable VM name and guest version/build |
| Disposable clone | Unique clone name and source baseline |
| Resources | CPU count, memory, sparse boot-disk capacity |
| Isolation | NAT, Safari, no shared folders, no guest app, no Apple Account |
| Candidate | Draft tag, payload commit, filename, and SHA-256 above |
| Result | Pass, Fail, or Blocked with content-free notes |

The documented workflow uses one four-CPU, 8 GB memory, 64 GB sparse-disk VM at
a time. Recommended guest families are macOS 14, the product minimum, and the
latest stable macOS available to the maintainer. Record the exact installed
point release and build after Software Update; a planned label is not evidence.

## Create An Untouched Baseline

Create each baseline from an Apple-hosted signed restore image. Use NAT and
Safari. Turn off the VirtualBuddy guest app, leave Sharing set to None, and do
not sign in to an Apple Account. Complete Setup Assistant with a disposable
local administrator account, install the intended stable point release through
Software Update, and restart until no required update remains.

Before sealing the baseline, prove all of the following:

- `/Applications/CopyLasso.app` is absent.
- `defaults read io.github.bennetthilberg.copylasso` reports no domain.
- `$HOME/Library/Containers/io.github.bennetthilberg.copylasso` is absent.
- CopyLasso is absent from **System Settings > General > Login Items &
  Extensions**.
- CopyLasso is absent from **System Settings > Privacy & Security > Screen &
  System Audio Recording**.
- Safari is usable, shared folders remain off, the guest app remains off, and
  no Apple Account is present.

Shut down the guest from macOS. Label the stopped VM as an immutable baseline
and never boot it for testing. Do not install CopyLasso, grant its permission,
or repair a failed test in the baseline.

## Duplicate, Download, And Verify

Use VirtualBuddy's APFS duplicate action only while the baseline is stopped.
Name the disposable clone with the OS family and run number. Boot one clone at
a time.

The G28 release is an unpublished draft. Do not sign in to GitHub inside a
guest. Instead, stage only the byte-identical DMG and checksum outside the
repository and serve them from a temporary HTTP endpoint bound only to the
VirtualBuddy host-only/NAT interface. Do not bind to every interface, use a
public upload, enable a shared folder, copy the app from the host, or fabricate
a quarantine attribute.

On the host, set `COPYLASSO_G29_SERVE_DIRECTORY` to the external directory that
contains only the staged DMG and checksum. Confirm `8765` is unused, or choose a
different unused high port for that run, then derive the VM-only bridge address
and start the scoped server:

```sh
: "${COPYLASSO_G29_SERVE_DIRECTORY:?set the external G29 serve directory}"
vm_interface=bridge100
vm_host_address="$(/sbin/ifconfig "$vm_interface" | \
  /usr/bin/awk '/^[[:space:]]*inet / { print $2; exit }')"
vm_port=8765
test -n "$vm_host_address"
! /usr/sbin/lsof -nP -iTCP:"$vm_port" -sTCP:LISTEN
/usr/bin/python3 -m http.server "$vm_port" \
  --bind "$vm_host_address" \
  --directory "$COPYLASSO_G29_SERVE_DIRECTORY"
```

The interface name, derived host address, and selected port are content-free,
run-local values. The Sonoma run used this VM-only bind pattern; its historical
ephemeral port was not retained as release evidence. In guest Safari, turn off
automatic opening of safe downloads, navigate to
`http://<vm-host-address>:<vm-port>/`, download the DMG normally, and download
the checksum file the same way. Stop the host server immediately after both
downloads. Set the two candidate variables from the protected qualification
record, not from the downloaded checksum file, then run this in the guest:

```sh
(
  set -eu

  : "${COPYLASSO_CANDIDATE_DMG:?set the exact downloaded DMG basename}"
  : "${COPYLASSO_CANDIDATE_SHA256:?set the trusted candidate SHA-256}"

  candidate_dmg="$COPYLASSO_CANDIDATE_DMG"
  candidate_sha256="$COPYLASSO_CANDIDATE_SHA256"
  candidate_checksum="${candidate_dmg}.sha256"

  test "$candidate_dmg" = "$(/usr/bin/basename "$candidate_dmg")"
  case "$candidate_dmg" in
    *.dmg) ;;
    *)
      echo "COPYLASSO_CANDIDATE_DMG must name a DMG." >&2
      exit 1
      ;;
  esac
  printf '%s\n' "$candidate_sha256" |
    /usr/bin/grep -Eq '^[0-9a-f]{64}$'

  cd "$HOME/Downloads"
  test -f "$candidate_dmg"
  test -f "$candidate_checksum"
  printf '%s  %s\n' "$candidate_sha256" "$candidate_dmg" |
    /usr/bin/shasum -a 256 -c -
  /usr/bin/shasum -a 256 -c "$candidate_checksum"
  /usr/bin/xattr -p com.apple.quarantine "$candidate_dmg"
)
```

Both checksum commands must succeed against the independently recorded digest,
and the quarantine value must be nonempty. If the browser download does not
create genuine quarantine, stop: host copying or manually adding an attribute
is not an acceptable substitute.

## Full Clean-Install Run

When performing the optional full matrix, run the complete sequence on a fresh
clone of each selected OS.

1. Double-click the quarantined DMG. Confirm it mounts read-only with only
   CopyLasso and the Applications alias, then drag CopyLasso to Applications.
2. Open the installed app normally. Do not remove quarantine, disable
   Gatekeeper, right-click around a warning, or use **Open Anyway**. Record
   normal Gatekeeper acceptance as identified, notarized Developer ID software
   without recording the signing subject.
3. Confirm first launch shows onboarding once, requests no privacy permission
   until capture, creates no Dock icon, proposes `⇧⌘2`, and defers the Launch at
   Login change until setup completes.
4. Complete onboarding with Launch at Login enabled. Confirm one status item
   and one enabled login item, then relaunch and confirm onboarding stays
   complete and the shortcut persists.
5. Start capture, deny the first Screen Recording request, and confirm one
   recovery window, no pixels/OCR/clipboard replacement, and no automatic
   retry.
6. Follow CopyLasso's System Settings route, enable only CopyLasso, and follow
   the actual macOS **Later** or **Quit & Reopen** transition. Start a fresh
   capture; confirm crosshair, dimming, selection, OCR, plain-text clipboard,
   HUD, and originating-app restoration.
7. Repeat one capture through the menu. Choose **Quit CopyLasso** and confirm
   its status item and process disappear, the shortcut becomes inert, no HUD or
   retained selection remains, and the clipboard is unchanged. Then launch it
   manually. Open Settings, change and restore the shortcut, disable Launch at
   Login, quit CopyLasso, and restart the guest with **Reopen windows when
   logging back in** off; confirm CopyLasso is absent. Launch it manually,
   re-enable Launch at Login, quit it, restart again with window restoration
   off, and confirm one dockless status item returns. This prevents session
   restoration from being mistaken for login-item behavior.
8. Quit CopyLasso and remove only the application from Applications. Do not
   manually alter preferences, the container, the login item, or TCC state.
   Record the actual login-item state after macOS reconciles the missing app,
   then reinstall the exact DMG. Confirm onboarding remains complete, the
   shortcut persists, Settings accurately reconciles the actual login-item
   state, and capture still succeeds.
9. Perform the complete uninstall below, verify every owned state is absent,
   and reinstall the exact DMG. Confirm onboarding returns and Screen Recording
   remains ungranted until the next capture request.

Read back the installed candidate after each reinstall:

```sh
defaults read /Applications/CopyLasso.app/Contents/Info CFBundleIdentifier
defaults read /Applications/CopyLasso.app/Contents/Info CFBundleShortVersionString
defaults read /Applications/CopyLasso.app/Contents/Info CFBundleVersion
lipo -archs /Applications/CopyLasso.app/Contents/MacOS/CopyLasso
```

The values must match the candidate table. A product failure blocks this
immutable candidate and requires a separate approved fix; do not silently
change application code within G29.

## Complete Uninstall In A Disposable Clone

This procedure destroys only CopyLasso's production settings and permission
state. Confirm the test is running in a disposable VM before continuing.

1. In CopyLasso Settings, disable **Launch CopyLasso at Login** and verify it
   reports disabled. Quit CopyLasso and remove it from Applications.
2. Delete only the production preference domain and exact production
   container, then reset only CopyLasso's Screen Recording entry:

   ```sh
   defaults delete io.github.bennetthilberg.copylasso 2>/dev/null || true
   rm -rf "$HOME/Library/Containers/io.github.bennetthilberg.copylasso"
   tccutil reset ScreenCapture io.github.bennetthilberg.copylasso
   ```

3. Confirm the app, production preferences, exact production container, login
   item, and CopyLasso Screen Recording row are all absent. Do not use a broad
   login-item reset, reset every application's TCC state, or inspect/copy the
   raw TCC database.

## Discard And Recreate Proof

Shut down and delete the disposable clone after its run; never promote it to a
baseline. Duplicate the same stopped baseline again, boot the second clone,
and repeat the baseline-absence checks. Confirm onboarding and Screen Recording
state are clean after the exact browser-download/install path begins again.

If any test fails, discard that clone and retry from the untouched baseline.
Never repair or boot the baseline. Retain only content-free result notes and
the minimum screenshots needed to substantiate the system UI result.

## Content-Free Run Records

Keep one record for each disposable-clone run. Every cell must contain either a
directly observed `Pass` or a reasoned `Blocked` classification; never promote
an unexecuted scenario to Pass. Result notes must describe only product and
system behavior; keep account names, passwords, signing subjects, private
paths, raw TCC/login-item databases, and captured text out of this document.

### Sonoma 14 Run Record

| Field | Recorded value |
| --- | --- |
| Date/operator | July 17, 2026; maintainer |
| Host model/chip | MacBook Pro (`Mac17,9`); Apple M5 Pro; Apple Silicon `arm64` |
| Host memory/OS | 24 GB; macOS 26.5.2 (`25F84`) |
| Virtualizer | VirtualBuddy 2.1 build 325; required digest matched; signature, Gatekeeper, and stapled-ticket validation passed |
| Baseline | `CopyLasso Baseline - macOS 14`; Apple-hosted macOS 14.6.1 restore image updated before sealing |
| Disposable clone | `CopyLasso Clean Run - macOS 14 - 1`; duplicated from `CopyLasso Baseline - macOS 14` while the baseline was stopped |
| Guest version/build | macOS 14.8.7 (`23J528`) |
| Resources | 4 CPUs; 8 GB memory; 64 GB sparse boot disk |
| Isolation | NAT and Safari; no shared folder, VirtualBuddy guest app, Apple Account, CopyLasso installation, or CopyLasso permission in the sealed baseline |
| Candidate | Draft `v0.1.0-g28.295914448081`; commit `5fe10a68a8438b5cd346030eb1e9ad70918e76b4`; `CopyLasso-0.1.0.dmg`; SHA-256 `0b38f85acd7507cbacfacb820d534ac60907c8d12bec08c3b7f41f6cf1d1952f` |
| Browser delivery | Pass - Safari download from the VM-only endpoint; literal digest and checksum record matched; quarantine was nonempty |
| Gatekeeper/install | Pass - two-item read-only DMG layout, drag installation, and normal identified-developer launch without bypass |
| Permission transition | Pass - native denial and singleton recovery preserved the clipboard; enabling only CopyLasso, relaunching as required, and starting a fresh shortcut capture produced crosshair, dimming, OCR, one plain-text clipboard result, HUD feedback, and originating-app restoration |
| Launch at Login restarts | Blocked - the disabled restart with Reopen windows off left CopyLasso absent; the enabled restart was not completed before the maintainer ended VM testing |
| Ordinary reinstall | Blocked - not executed after the maintainer ended VM testing |
| Complete uninstall | Blocked - not executed after the maintainer ended VM testing |
| Discard/recreate | Blocked - not executed after the maintainer ended VM testing |
| Overall result | Blocked - partial macOS 14 rehearsal only; unexecuted rows are accepted evidence gaps, not passes |

### Latest Stable Run Record

| Field | Recorded value |
| --- | --- |
| Date/operator | July 17, 2026; maintainer |
| Host model/chip | MacBook Pro (`Mac17,9`); Apple M5 Pro; Apple Silicon `arm64` |
| Host memory/OS | 24 GB; macOS 26.5.2 (`25F84`) |
| Virtualizer | VirtualBuddy 2.1 build 325; required digest matched; signature, Gatekeeper, and stapled-ticket validation passed |
| Baseline | Blocked - macOS installation completed, but Setup Assistant stopped at a second Terms and Conditions screen and no immutable baseline was sealed |
| Disposable clone | Blocked - no clone was created because the baseline was not sealed |
| Guest version/build | Blocked - the Apple restore image targeted macOS 26.5.2 (`25F84`), but no post-setup guest readback was completed |
| Resources | 4 CPUs; 8 GB memory; 64 GB sparse boot disk |
| Isolation | Blocked - NAT, no sharing, and no VirtualBuddy guest app were configured, and Apple Account setup was skipped, but no post-setup clean-state readback was completed |
| Candidate | Draft `v0.1.0-g28.295914448081`; commit `5fe10a68a8438b5cd346030eb1e9ad70918e76b4`; `CopyLasso-0.1.0.dmg`; SHA-256 `0b38f85acd7507cbacfacb820d534ac60907c8d12bec08c3b7f41f6cf1d1952f` |
| Browser delivery | Blocked - CopyLasso was never downloaded in this guest |
| Gatekeeper/install | Blocked - CopyLasso was never installed in this guest |
| Permission transition | Blocked - CopyLasso was never launched in this guest |
| Launch at Login restarts | Blocked - not executed |
| Ordinary reinstall | Blocked - not executed |
| Complete uninstall | Blocked - not executed |
| Discard/recreate | Blocked - no sealed baseline or disposable clone existed |
| Overall result | Blocked - Setup Assistant remained incomplete and no CopyLasso qualification ran |

## G29 Partial Rehearsal Record

This table closes every G29 scenario as factual Pass or reasoned Blocked. The
full procedure remains reusable for a future release, but further VirtualBuddy
execution is not a v0.1 release gate.

| Scenario | macOS 14 clone | Latest stable clone |
| --- | --- | --- |
| Exact guest version/build and isolation readback | Pass - 14.8.7 (23J528); clean baseline readback | Blocked - no completed Setup Assistant or clean-state readback |
| Browser download, SHA-256, and quarantine | Pass - exact digest, checksum `OK`, Safari quarantine present | Blocked - not executed |
| DMG layout, drag install, and Gatekeeper | Pass - two-item layout; normal Gatekeeper open without bypass | Blocked - not executed |
| First launch, onboarding, shortcut, and no Dock icon | Pass - one onboarding, `⇧⌘2`, deferred login item, no Dock icon | Blocked - not executed |
| Launch at Login enabled and disabled across restart | Blocked - disabled restart passed; enabled restart was not completed | Blocked - not executed |
| Permission denial, recovery, grant, relaunch, and capture | Pass - deny/recovery, explicit grant, required relaunch, and fresh capture passed | Blocked - not executed |
| Shortcut and menu OCR, clipboard, HUD, and Settings | Pass - shortcut and menu captures passed; shortcut clear/restore persisted across quit/relaunch | Blocked - not executed |
| Ordinary uninstall/reinstall retains preferences | Blocked - not executed | Blocked - not executed |
| Complete uninstall/reinstall returns clean state | Blocked - not executed | Blocked - not executed |
| Clone discarded and fresh duplicate proved clean | Blocked - not executed | Blocked - no sealed baseline or clone existed |
