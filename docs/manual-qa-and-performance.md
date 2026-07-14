# Manual QA And Performance Record

**Protocol version:** 1

**Goal:** G24

**Execution state:** final clean post-G24U rerun in progress; signed Sidecar capture and idle passed, Dell and cross-display sample counts pending

This is the release record for system behavior that unit tests and unsigned hosted runners cannot faithfully validate. A result is **Pass**, **Fail**, **Blocked**, or **Not applicable**. Historical spike screenshots and injected-service tests provide context but never replace a fresh G24 result.

## Required Environment Record

Fill every field before the interactive run:

| Field | Required value |
| --- | --- |
| Commit | Exact tested SHA |
| Configuration | Stably Apple Development-signed Debug |
| App version/build | Bundle values |
| Hardware | Model identifier, chip, core count, memory |
| macOS | Product version and build |
| Xcode | Version and build |
| Displays | Name, layout, point frame, pixel resolution, scale, refresh rate |
| Spaces | Separate-Spaces setting and full-screen test Space |
| Permission state | Screen Recording reset/enabled/revoked state for each phase |
| Network | Connected and process-denied/offline phases |
| Clipboard sentinel | Synthetic non-secret text used for preservation checks |

### July 11, 2026 Signed Interactive Run

The interactive run uses exact commit
`287e1eb87dd68faec402d900903675514cebbee6`, version 0.1.0 build 1, from
`.build/g24-signed/Build/Products/Debug/CopyLasso.app`. Strict deep signing
verification passed for the Apple Development-signed Debug bundle
`io.github.bennetthilberg.copylasso.debug`; Hardened Runtime, App Sandbox, and
the expected Debug `get-task-allow` entitlement were present. The designated-
requirement SHA-256 is
`81238cd9755ca53d0c9307165aae3c065554145b7b474c008943dfdfd08a9755`.

The workstation is an Apple M5 Pro MacBook Pro (`Mac17,9`, 15 cores, 24 GB),
macOS 26.5.1 (`25F80`), and Xcode 26.6 (`17F113`). The coherent post-reboot
display snapshot is:

| Display | Runtime ID | AppKit frame | Core Graphics bounds | Backing and refresh |
| --- | ---: | --- | --- | --- |
| Dell S2721HGF, primary | `5` | `(0, 0, 1920, 1080)` | `(0, 0, 1920, 1080)` | 1×, 1920×1080, 144 Hz |
| Sidecar Display | `6` | `(-1298, -147, 1298, 954)` | `(-1298, 273, 1298, 954)` | 2×, 2596×1908, 60 Hz |

The run uses synthetic, non-secret clipboard sentinels whose names identify the
scenario without retaining clipboard or OCR contents. The run stopped at the
release-blocking cursor failure described below, so results distinguish
complete passes from partial evidence and tests deferred until the required
fix and clean rerun.

The earlier July 11 unattended context used the same hardware and toolchain,
but only the Dell was online and the graphical session was behind the login-
window shield. Its measurements remain historical context rather than signed
interactive results.

### July 12, 2026 G24C Signed Cursor-Fix Run

The cursor fix uses exact commit
`64f28f5d76ee6faabb2d64e85707c1cd3856a1e4` from the same exact artifact path.
Strict verification passed for version 0.1.0 build 1, arm64 Debug, Hardened
Runtime, App Sandbox, development-only `get-task-allow`, and no network
entitlement. A duplicate `.build/ci-arm64` app with the same Debug bundle
identifier initially reopened and produced a false permission failure; it was
terminated, and executable-path readback confirmed the exact signed artifact
before testing continued.

With Chrome's controlled bright fixture frontmost, the physical shortcut
immediately produced exactly one normal-sized system crosshair. A real drag
completed ScreenCaptureKit, Vision, clipboard output, and the success HUD.
Computer Use then found Chrome's fixture content focused again, proving the
selection-only focus handoff restored the originating app before feedback
finished. An immediate second shortcut while the success HUD remained visible
produced no overlapping selection under the then-current `.completing`
busy-state contract. That historical result motivated the approved G24R
amendment; it is not evidence for the new immediate-replacement behavior.

### July 12, 2026 G24R First Signed Candidate

The first interruptible-feedback candidate used exact commit
`fdf420a535ba80921a91150d1b4076a9ae4fe1c8`. Strict signature, bundle,
Hardened Runtime, App Sandbox, Debug entitlement, arm64, and no-network checks
passed. The first shortcut during a success HUD dismissed it and produced one
fresh normal-sized crosshair immediately. Repeating the full capture/HUD/
shortcut cycle around a third time produced visible flicker and intermittently
failed to enter selection. This is a signed **Fail**, not a partial pass.

The replacement implementation removes the cause instead of tuning the race:
feedback presentation now returns synchronously, the coordinator reaches idle,
and the panel alone owns its cancellable 2.5-second timer. Ten-cycle automated
coverage passes, but a fresh exact-head signed physical run is still required.

### July 12, 2026 G24R Decoupled-Feedback Candidate

The decoupled-feedback candidate used exact commit
`41129e603b642fa48b82ae8938f264285ebc0fb7`. Strict bundle, signature,
runtime, sandbox, Debug-entitlement, architecture, and no-network checks passed.
Repeated capture no longer waited for a feedback task, and most replacement
requests produced the crosshair immediately. The maintainer nevertheless saw
the pointer flicker and sometimes remain an arrow until mouse-down when a new
shortcut followed a successful copy while its HUD was visible. Escape restored
the arrow correctly. This is a signed **Fail** because the crosshair contract
requires the stationary pointer to change before mouse-down.

The remaining cause is narrower than the feedback workflow: requesting
`NSApp.activate` and presenting the selection surfaces in the same main-actor
turn can precede WindowServer's completed activation. The next candidate waits
for AppKit's actual application-active notification before constructing an
input-ready surface, rebuilding cursor rectangles, or pushing the crosshair.
Automated coverage holds and cancels that activation callback, but the exact
signed repeated-capture sequence must be rerun.

### July 12, 2026 G24R Activation-Handshake Candidate

The application-activation candidate used exact commit
`ab4e6a263c52164d9cadc7a28a5bde0cf38c0548`. It passed the full local and
hosted gates plus strict signed-artifact verification. The maintainer's physical
rapid-reuse run still showed cursor flicker. Waiting for CopyLasso itself to
become active therefore did not prove that the pointer display's selection panel
had become key and owned AppKit's cursor rectangles. This is a signed **Fail**.

The approved G24S replacement waits for the exact input panel's one-shot key
callback before rebuilding cursor rectangles or pushing the native crosshair.
It also changes the suggested/default shortcut to `Shift-Command-2` (`⇧⌘2`)
without altering existing customized shortcuts. Automated evidence does not
promote either behavior until a fresh exact-head signed run passes.

### July 12, 2026 G24T Signed Dashed-Outline Run

The initial animated-outline candidate used exact code head
`f2ef0efc4f21156e0916982081568d8d8785716e`. Strict verification passed for
the Debug bundle, version 0.1.0 build 1, arm64, Hardened Runtime, App Sandbox,
development-only `get-task-allow`, and no network entitlement. Computer Use
launched only the canonical signed artifact, invoked `⇧⌘2` over the controlled
browser fixture, observed the selection surface, and verified Escape cleanup.

The maintainer physically confirmed that the retired heavy two-tone border was
replaced by exactly one thin gray dashed outline and that its dashes moved
steadily. The same run exposed a movement-time cursor regression: moving the
pointer could alternate repeatedly between arrow and crosshair. The outline
therefore passed, but the combined selection treatment remained a signed
**Fail** until the follow-up below.

### July 12, 2026 G24T Cursor-And-Radius Follow-Up

The follow-up used exact signed head
`7c335aad174a8b7d79765f742b1383d4c75a65a1` from the canonical artifact path.
Strict verification again passed for the expected Debug bundle, version/build,
arm64 architecture, Hardened Runtime, App Sandbox, development-only Debug
entitlement, and absence of network entitlements. Computer Use launched that
artifact as the sole CopyLasso process, invoked `⇧⌘2` on the controlled browser
fixture, observed the selection surface, and verified Escape cleanup.

The correction keeps native full-window crosshair cursor rectangles active,
refreshes the exact keyed surface through its owning window, waits one
main-actor turn, and only then applies the selection-wide native crosshair. The
outline retains its steady linear dash motion and adds a subtle two-point visual
radius without changing square selection or capture geometry. The maintainer's
physical follow-up confirmed that the cursor no longer alternated with the arrow
during movement and accepted the updated treatment. This is a signed **Pass**
for the G24T standard-appearance cursor, outline, radius, and Escape boundary;
it does not promote the remaining full G24 matrix or accessibility-mode rows.

### July 13, 2026 Signed G24 Evidence Run

The current run uses exact commit
`4d889f42e2e8a43bcc019f179db7bd07fd38f9b2`, version 0.1.0 build 1, from
`.build/g24-signed/Build/Products/Debug/CopyLasso.app`. Strict deep verification
passed for the Apple Development-signed Debug bundle
`io.github.bennetthilberg.copylasso.debug`; it is arm64, uses Hardened Runtime
and App Sandbox, retains only the expected development `get-task-allow`
entitlement, and has no network client or server entitlement. The content-free
designated-requirement SHA-256 is
`6f577fdd7211af22e909a6937f6b6758b6b9875bc2aad64ae909f32455b8e4fd`;
the executable SHA-256 is
`30635b04fc528f2a4371962c30b9e8d5f203c85cb248f987b407931977d8b6f9`.

The workstation is an Apple M5 Pro MacBook Pro (`Mac17,9`, 15 cores, 24 GB),
macOS 26.5.1 (`25F80`), and Xcode 26.6 (`17F113`). The final display readback
reported only the primary Dell S2721HGF at 1920×1080, 1×, 144 Hz, mirrored off.
Sidecar was unavailable for this run, so Sidecar-only and physical cross-display
rows remain **Blocked** rather than inheriting the July 11 display snapshot.

The run began from app-local Debug reset state and reset Debug Screen Recording
permission, then exercised onboarding, denial, approval with **Later**, ordinary
relaunch, revocation, reapproval with **Quit & Reopen**, real logout/login with
Launch at Login enabled and disabled, offline process enforcement, controlled
OCR fixtures, full-screen edges, lock and quit cleanup, latency, idle, and
repeated capture/cancellation. All app restarts and login cycles used the exact
artifact above; executable-path readback found no second CopyLasso process.

The maintainer explicitly accepted the remaining stationary-pointer edge case
as deferred before this run: an immediate retrigger can briefly show the arrow
until pointer movement or mouse-down. The 30-capture latency batch and the first
exact 100-cycle sequence both completed every expected success/cancellation,
but the maintainer observed the occasional crosshair miss in each. This is
recorded as a visible residual, not silently promoted to a perfect cursor result
and not treated as a new G24 release blocker under the approved disposition.

All debugger callbacks emitted only stage labels, monotonic timestamps, and
thread identifiers. Raw LLDB, Time Profiler, Allocations, idle, and memory files
remain under ignored `.build/g24-interactive-current`; they are not committed
because profiler metadata includes local paths and environment values.

### July 13, 2026 Release-Blocking Sleep/Wake Failure

With controlled TextEdit pixels frontmost, the maintainer invoked `⇧⌘2`, saw
selection begin, and put the Mac to sleep before dragging. After wake and sign-
in, the normal arrow was visible rather than the crosshair, but CopyLasso was
still intercepting input in an active selection session. A drag completed OCR,
changed the clipboard, and presented the success HUD. The exact signed process
remained PID 32630 throughout.

This is a signed **Fail**. Sleep/wake must produce one system-interruption
cancellation, remove every overlay/cursor surface, preserve the clipboard, never
resume automatically, and return the app to immediate idle reuse. Instead, the
app resumed an invisible selection mode whose ordinary arrow did not communicate
that clicks were still being captured. The result is both a lifecycle cleanup
failure and a misleading-input-state failure.

Read-only follow-up found that the root lifecycle source subscribes to workspace
sleep, screen-sleep, and session-resign notifications, while the selection
overlay's local lifecycle observer covers display changes and application
termination only. The failing process emitted no lifecycle interruption or
resume diagnostic in the unified log, although the same fixed-message logger
recorded termination cleanup in earlier processes. This narrows the owning area
to physical interruption delivery and selection teardown without claiming a
root cause from one signed observation.

Per G24's stop condition, no production fix is included here and the remaining
appearance/accessibility/manual rows were not continued after this observation.
G24 requires a narrowly scoped lifecycle amendment that handles sleep/session
interruption, proves stale selection events cannot survive wake, passes focused
and canonical automation, rebuilds the exact signed artifact, and restarts the
G24 matrix from clean state.

### July 13, 2026 G24U Signed Sleep-Selection Fix

The physically tested candidate was built from the production and test source
tree committed unchanged as `7d1eba8` at
`.build/g24u-signed/Build/Products/Debug/CopyLasso.app`. Strict deep signing
verification passed for Debug bundle
`io.github.bennetthilberg.copylasso.debug`, version 0.1.0 build 1, arm64,
Hardened Runtime, App Sandbox, development-only `get-task-allow`, and no network
client/server entitlement. Its tested executable SHA-256 was
`cf517ce31e73c52c1ae4c9aa5ef994dd0409bad763b66dd5a0c8dc8c5b2ca292`, and
executable-path readback confirmed it was the only running CopyLasso process.

Focused arm64 coverage passed 64/64. Canonical arm64 and x86_64 pipelines each
passed 241/241 ordinary tests, the offline rebuild, three repeatability passes,
coverage gates, Debug and Release builds, and Universal 2 verification.

Computer Use invoked `⇧⌘2` over the controlled fixture before the maintainer
put the Mac to sleep pre-drag. After wake, no dim, outline, cursor override, or
HUD returned; the synthetic sentinel remained unchanged, an ordinary drag did
not start OCR or alter the clipboard, and the next explicit capture produced a
success HUD. The same exact process then entered a real drag before a second
actual sleep. Wake again showed complete cleanup, no automatic work, and the
same sentinel. A non-capture drag remained inert, and a fresh explicit capture
again produced the success HUD. This is a signed **Pass** for G24U's pre-drag
and drag-phase sleep interruption, clipboard, no-resume, and reuse boundary.

A separate `Control-Command-Q` screen-lock probe did not produce the public
workspace session-switch event on this macOS build. The window looked clean
after unlock, but a content-free drag probe exposed an invisible retained
selection and the sentinel was replaced with an empty clipboard value. The
maintainer explicitly accepted this lock-only behavior as a v0.1 residual on
July 13, 2026; it does not block G24U or require a separate fix goal. Actual
sleep remains covered by the passing boundary above. Source inspection confirms
the only lifecycle diagnostics remain fixed strings without captured app names,
geometry, pixels, recognized text, clipboard text, previews, or raw errors; the
signed process produced no stored lifecycle entry during this run.

### July 13-14, 2026 Final Clean G24 Rerun In Progress

The final clean rerun uses merged `main` head
`f6f75c0da23f8e58fe2ce3d8a3f273cf17a37be8` from branch
`a/g24-final-manual-qa-performance`. A clean arm64 Debug build at
`.build/g24-signed/Build/Products/Debug/CopyLasso.app` passed strict deep
signing verification. Safe readback confirms Debug bundle
`io.github.bennetthilberg.copylasso.debug`, version 0.1.0 build 1, arm64,
Hardened Runtime, App Sandbox, development-only `get-task-allow`, no network
client/server entitlement, executable SHA-256
`e728fcde475b25bc7ad6ed5b3593a019647d93fbf93cbd77b3c8bb299540580f`, and
content-free designated-requirement SHA-256
`6e972a6b202a4ef4edf08846acce3246a16bdf4bd63ab0bccc31f266bb228da0`.
Canonical arm64 and x86_64 pipelines each passed 241/241 ordinary tests and
all three 241/241 repeatability runs, plus the offline, coverage, format,
privacy, Debug/Release, and Universal 2 gates.

The final-clean environment record is:

| Field | Final-clean value |
| --- | --- |
| Hardware | Apple M5 Pro MacBook Pro (`Mac17,9`), 15 cores, 24 GB memory |
| macOS | 26.5.1 (`25F80`) |
| Xcode | 26.6 (`17F113`) |
| Displays | Dell S2721HGF primary, runtime ID 5, `(0, 0, 1920, 1080)` AppKit/Core Graphics, 1x, 1920x1080, 144 Hz; extended Sidecar, runtime ID 16, AppKit `(-1298, -147, 1298, 954)`, Core Graphics `(-1298, 273, 1298, 954)`, 2x, 2596x1908, 60 Hz |
| Spaces | Separate Spaces enabled; final-clean full-screen/changed-Space repeat pending |
| Permission state | Screen Recording reset before launch, denied for the recovery phase, then enabled with **Later** and made effective by ordinary quit/relaunch; enabled during capture and idle measurements |
| Network | Host connected; the signed app has no network entitlement and had zero internet sockets; dedicated final-clean process-denied capture repeat pending |
| Clipboard sentinels | Fresh synthetic non-secret values per controlled phase; denial and unavailable retry verified individually, shared Escape/click/tiny/no-text batch inconclusive and pending isolated values |

Computer Use drove the app-owned reset, verified onboarding's default
`Shift-Command-2` shortcut and deferred Launch at Login choice, completed
onboarding after explicit login-item approval, and read back one enabled item
whose URL names the exact signed artifact. The first menu command produced one
macOS Screen Recording request. Denial produced one accessible recovery panel;
repeated **Try Again** stayed unavailable and preserved a fresh synthetic
sentinel. Enabling access in System Settings and choosing **Later** caused no
automatic retry; a second fresh-sentinel retry stayed unavailable until an
ordinary quit and exact-path relaunch. A physical shortcut then presented the
crosshair and a hand-driven controlled TextEdit capture copied the three visible
lines exactly. Computer Use key and drag injection did not route through the
selection overlay reliably, so those synthetic attempts are not counted as
product failures or manual passes.

The Dell remained the main 1920 by 1080, 1x, 144 Hz display at AppKit/Core
Graphics origin `(0, 0)` with runtime ID 5. Sidecar runtime ID 16 was extended,
not mirrored, at AppKit `(-1298, -147, 1298, 954)`, Core Graphics
`(-1298, 273, 1298, 954)`, 2x, and 60 Hz. Three Sidecar-initiated captures each
showed the crosshair, dimmed only the iPad, presented a HUD, restored the
originating app, and copied the controlled three-line fixture exactly. Physical
Sidecar-to-Dell once and Dell-to-Sidecar twice kept the crosshair across the
boundary while the dashed selection box stopped at the initiating display edge
and only that display dimmed.

The Escape, click, 1-2-pixel drag, and larger blank-box batch produced the
expected no-HUD, no-HUD, no-HUD, and no-text-HUD outcomes. Its final clipboard
value did not match the batch sentinel, so clipboard preservation for this
batch remains pending a controlled repeat instead of being inferred from the
visual result. After a new 30-second settle, 60 one-second idle samples all
reported 0.0% CPU; RSS stayed between 98,832 and 98,928 KiB with a 98,909.6 KiB
average. Post-sample physical footprint was 66 MiB, and `/usr/bin/leaks`
reported 0 leaks for 0 leaked bytes. The app container still held four state
files, zero image/PDF files, and zero controlled-text matches; the process had
zero open image/PDF files, zero internet sockets, and zero controlled-text
matches in two hours of unified logs. Raw current-run samples remain ignored at
`.build/g24-final-current`.

This rerun is intentionally still in progress. Physical appearance and assistive
technology changes, protected-content and wallpaper probes, remaining lifecycle
phases, visible status-item cold launch, the official 30-capture ordinary-region
series, and the simultaneous Time Profiler/Allocations 100-cycle sequence have
not yet been promoted from historical context.

## Clean-State Preparation

1. Build Debug with the stable Apple Development identity and verify its designated requirement.
2. Quit every CopyLasso process. Use **Reset Local Development State…**, then quit again.
3. Reset only Debug Screen Recording permission:

   ```sh
   /usr/bin/tccutil reset ScreenCapture io.github.bennetthilberg.copylasso.debug
   ```

4. Restore the normal Dell resolution/refresh rate, connect the Sidecar iPad as an extended display, and record fresh display descriptors.
5. Set a synthetic clipboard sentinel. Open Finder, a browser, TextEdit, Preview with a PDF, a raster image, a paused video, System Settings, and the test photograph/difficult-text fixtures.
6. Start Activity Monitor or Instruments without granting CopyLasso any additional permission. Record baseline system load.

If this preparation cannot complete, mark every dependent row **Blocked** and stop rather than mixing states from different builds.

The interactive preparation completed in this order: stale LaunchServices
registrations and two stale CopyLasso login-item rows were removed, only the
exact signed artifact was registered, **Reset Local Development State…**
cleared app-owned Debug state and disabled the login item, Debug Screen
Recording permission was reset with the command above, and the exact artifact
was relaunched. Onboarding reopened with the suggested shortcut selected and
Launch at Login enabled. Completing onboarding produced exactly one enabled
login item whose URL points to the exact signed artifact. Sidecar was then
reconnected as an extended display. No permission request occurred merely from
launching or completing onboarding.

For the July 13 run, **Reset Local Development State…** again reopened
onboarding, disabled the exact login item, and left permission prompting deferred
until the first capture request. Onboarding advertised and stored `⇧⌘2`; Launch
at Login was enabled only after the user completed onboarding. Debug Screen
Recording permission was reset before launch. The clean denial/grant phase used
synthetic sentinels and the controlled fixture app. Sidecar could not be
reconnected, so the final coherent matrix used the Dell only and isolates the
display-dependent blockers below.

For the final clean rerun, the same app-local and TCC reset sequence was repeated
against exact merged head `f6f75c0`. Sidecar was connected before display work,
and only the exact signed artifact remained running. The current result is the
in-progress record immediately above; older Dell-only evidence remains
historical until each pending physical row is repeated or explicitly classified.

## Functional And Recovery Matrix

Run each row at least three times unless a larger sample is specified.
Replace each current **Blocked** entry with fresh signed-run evidence; do not
carry forward a historical result. Evidence must name the tested commit and
record the observed focus, clipboard, permission, display, and cleanup state
where those properties apply.

| Scenario | Expected result | Current result and evidence |
| --- | --- | --- |
| First launch from a clean installation | Onboarding appears once; no unexpected window, permission request, or Dock icon | **Blocked** — app-local Debug reset reproduced onboarding without a launch-time permission request, but clean quarantined installation remains owned by G27-G29 |
| Ordinary relaunch after completed onboarding | One status item, no onboarding, Dock icon, or initial window | **Blocked** for sample count — one final-clean post-permission relaunch exposed one status item with no onboarding/window/Dock item and preserved `⇧⌘2`; two more current observations are required by the three-run minimum |
| Cold launch | One status item within 2 seconds; no Dock icon or initial app window after completed onboarding | **Blocked** — the maintainer watched the status item disappear and reappear for ten launches with no unexpected window or Dock item, but the recorded timestamps measured process visibility rather than the visible, interactive status item required by this protocol |
| Shortcut setup and persistence | Confirm, replace, clear, and restore `⇧⌘2`; relaunch and reboot preserve the stored choice | **Blocked** for final clean promotion — the historical run replaced, cleared, restored, relaunched, and logged out/in successfully but did not reboot after final restoration. The final-clean run confirms the onboarding default and ordinary relaunch only; replace, clear, restore, logout/login, and reboot remain pending |
| Suggested shortcut with Finder frontmost | Selection-only activation presents the crosshair, then restores Finder before downstream work | **Blocked** for final clean promotion — the historical controlled Finder capture and focus restoration passed, but the current final-clean run has not repeated this row |
| Shortcut with browser and TextEdit frontmost | Same command path and originating-app restoration | **Blocked** for final clean promotion — one current controlled TextEdit capture passed; the browser path and two more current observations remain pending |
| Shortcut with another native app frontmost | Same command path and restoration outside the specifically tested apps | **Blocked** for final clean promotion — the historical native-fixture focus and capture series passed, but the current final-clean run has not repeated this row |
| Menu fallback with shortcut cleared | Capture Text remains usable and matches shortcut behavior | **Blocked** for final clean promotion — the historical clear/no-op/menu-capture/restore sequence passed, but the current final-clean run has not repeated this row |
| Rapid repeated shortcut while active | Requests during permission, selection, capture, or OCR are rejected; a request during feedback dismisses that HUD and immediately begins exactly one fresh selection | **Blocked** for the full active-phase matrix — ten immediate success/HUD retriggers completed, and the exact 100-cycle sequence produced 50 success/HUD outcomes plus 50 Escape cancellations without stale feedback. No physical shortcut request was isolated during permission, capture, or OCR work, so deterministic busy-state tests are not promoted into a signed pass |
| Ordinary success | Selected text reaches plain-text clipboard; bounded success HUD appears after originating-app restoration | **Pass** — the final-clean run produced one exact controlled Dell capture and three exact controlled Sidecar captures; all four copied the expected three lines and presented a bounded HUD |
| Selection cursor and drag rendering | Clear before mouse-down; one normal-sized crosshair replaces the pointer before and throughout the drag; initiating display dims outside the selection; one thin gray dashed two-point-radius outline moves steadily | **Pass with accepted residual** — the final-clean Dell capture, three Sidecar captures, and three cross-display drags produced the crosshair and initiating-display selection treatment with correct cleanup. The explicitly deferred G24S immediate-reuse stationary-arrow residual remains accepted |
| Reverse drag and every edge | Correct region, initiating-display clamp, no orphaned panel/cursor | **Blocked** for final clean promotion — the historical reverse and four edge drags passed, but the current final-clean run has not repeated this row |
| Every connected display and backing scale | Correct display identity, point-to-pixel scale, crop, HUD placement, and focus restoration | **Blocked** for Dell sample count — final clean head `f6f75c0` produced one exact controlled 1× Dell capture and three exact 2× Sidecar captures. Each Sidecar capture copied the expected three lines, placed its HUD on the iPad, dimmed only the iPad, and restored TextEdit, but two more current Dell observations are required by the three-run minimum |
| Cross-display drag | Initiating display alone dims; selection clamps at its edge and never spans displays | **Pass** — final clean head `f6f75c0` produced the expected result in three physical drags, once Sidecar-to-Dell and twice Dell-to-Sidecar: the crosshair followed the pointer across the boundary, while the dashed box stopped at the initiating display edge and only that display dimmed |
| Full-screen app and changed Space | Selection-only activation appears over the intended full-screen Space, does not switch Spaces, and restores the originating app | **Blocked** for final clean promotion — the historical full-screen/Space sequence passed, but the current environment record and final-clean run leave this repeat pending |
| Escape before/during drag | Normal cancellation; clipboard sentinel unchanged; immediate reuse | **Blocked** for final clean promotion — the current pre-drag Escape produced no HUD and cleaned up visually, while the historical isolated during-drag and 50-cycle results remain useful context. The shared current-batch sentinel changed before final readback, so pre-drag and during-drag clipboard preservation must be repeated with isolated sentinels |
| Click and sub-4-point drag | Too-small cancellation; sentinel unchanged | **Blocked** for final clean promotion — current click and 1-2-pixel drags produced no HUD, and a larger blank selection produced the no-text HUD. Because the shared final sentinel changed, each current clipboard assertion must be repeated with its own sentinel rather than inferred from the visual result |
| Quit during selection | All panels/cursor state disappear exactly once and the process terminates without a clipboard change | **Blocked** for final clean promotion — the historical run completed two active-selection quits with immediate cursor cleanup and sentinel preservation, but the current final-clean run has not repeated this row |
| No recognizable text | No-text HUD; sentinel unchanged | **Blocked** for final clean promotion — the current controlled blank region produced the expected no-text HUD, but the shared batch sentinel did not survive to final readback; repeat this row with an isolated sentinel |
| Permission first request: Deny | One system request, singleton recovery, no downstream work | **Blocked** for invocation coverage and sample count — one final-clean reset/denial sequence used the menu fallback, produced one macOS request and one recovery panel, performed no capture, reused the singleton panel on **Try Again**, and preserved its sentinel. A physical-shortcut denial plus two more current reset/denial observations remain required |
| Permission approval/retry | Follow actual Later/Quit & Reopen behavior; no automatic retry | **Blocked** for sample count — one final-clean enable-with-**Later** sequence caused no automatic retry, stayed unavailable until ordinary quit/relaunch, and then captured successfully after direct-screen-access **Allow**. Two more current approval/retry observations are required by the three-run minimum |
| Permission revocation | Controlled likely-revoked recovery after authoritative denial | **Blocked** for final clean promotion — the historical run passed revoke/recover/re-enable with sentinel preservation, but the current final-clean run has not repeated this row |
| Sleep and wake during every active phase | One system-interruption cancellation, cleanup, no auto-resume, immediate reuse | **Blocked** for the complete phase matrix — exact signed pre-drag and drag-phase sleeps now pass with cleanup, sentinel preservation, no auto-resume, and successful reuse; capture, OCR, and feedback-phase sleep rows remain pending |
| Lock and unlock during every active phase | Same lifecycle contract and no sensitive residue | **Not applicable for further final-clean execution by maintainer direction** — the historical pre-drag probe cleaned up, while a drag-phase lock retained an invisible selection and replaced its sentinel with an empty value. The maintainer explicitly accepted this lock-only v0.1 residual and directed the run to move past further lock testing; actual sleep remains covered separately |
| Launch at Login enabled/disabled | Correct dockless presence after real logout/login or reboot | **Blocked** for final clean promotion — the final-clean run confirms one exact enabled item after onboarding, while the historical enabled/disabled logout/login sequence remains context. Current enabled and disabled logout/login or reboot checks are pending |
| Light, dark, increased contrast, reduced motion, maximum text size | Legible native UI, one thin gray dashed two-point-radius selection outline, static dash phase under Reduce Motion, no clipped text | **Blocked** for the complete accessibility-mode sweep — the current standard bright-browser treatment passed physically, while Light/Dark system variation, Increased Contrast, Reduce Motion, and maximum text size still require a coherent signed run |
| VoiceOver and Full Keyboard Access | Clear labels/order/actions across menu, onboarding, Settings, recovery, selection, and HUD | **Blocked** — Computer Use confirmed labels/help/order for onboarding, Settings, recovery, and the selection overlay; VoiceOver speech and Full Keyboard Access remain untested |
| Offline success | Core workflow succeeds with process networking denied | **Blocked** for final clean promotion — the final-clean process had no network entitlement and zero internet sockets, while the historical process-denied capture passed. A current process-denied physical capture remains pending |
| Protected content | Controlled blank/unavailable/no-text behavior; no bypass or invented text | **Blocked** — no fresh protected-surface result |
| Clipboard preservation sweep | Sentinel survives every cancellation and failure before replacement begins. A fault-injected clear-success/write-rejection reports clipboard failure; the prior clipboard may already be lost under the accepted write-only v0.1 boundary | **Blocked** for the complete sweep — the final clean run freshly confirms denial and unavailable-retry preservation. Its shared Escape/click/tiny/no-text batch was inconclusive because the final sentinel changed, so none of those current clipboard checks is promoted until isolated repeats pass. Historical revocation, active-selection quit, sleep, and lock-residual observations remain context; current revocation, quit, lifecycle-phase, capture, OCR, and feedback interruption rows remain pending |
| Success feedback privacy | HUD shows the correct normalized, truncated preview; preserves focus; clears on time; leaves no preview in logs/preferences | **Blocked** for complete preview validation — HUDs were bounded, nonactivating, replaceable, and temporary, the controlled fixture regained focus, and no preview text appeared in logs/preferences. Exact normalized/truncated preview content and timed clearing were not recorded in the coherent run |
| Private-data residue | Before/after app-container and temporary-directory inventory contains no image/text output; unified log contains no selected content | **Blocked** for the complete delta — retained baseline/current app-container manifests are identical; the final container held four state files, zero image/PDF files, and zero controlled-text matches. Logs contained zero controlled-text matches and the process had zero internet sockets. A final-clean temporary-directory inventory was not retained |
| Ordinary delete and reinstall | Onboarding remains complete when preferences remain; Launch at Login state is reconciled | **Blocked** — no installable release artifact exists yet |
| Complete uninstall and reinstall | Login item, preferences, app-owned container data, and Screen Recording entry are removed; onboarding returns cleanly | **Blocked** — final uninstall procedure is a G25 deliverable and authoritative VM proof is G29 |

### Resolved Cursor Block

The first bright-background signed run showed only the ordinary arrow, and the
follow-up drawn-reticle candidate produced two pointers. The approved G24C fix
temporarily activates CopyLasso during selection, uses the normal system
crosshair, removes the drawn reticle, and restores the originating app before
completion. Exact-head signed testing passed that visual and focus-restoration
gate on July 12.

The earlier partial cursor-failure run is not promoted into a complete result.
The July 13 evidence above is the required clean-state restart and supersedes
that historical boundary. Its accepted stationary-pointer residual remains
explicit, and its independent sleep/wake failure now blocks G24.

## OCR Content Matrix

For each source, record the exact selected region, expected visible text, copied text, ordering errors, omissions, inventions, and elapsed time. Do not use real credentials or private content.

| Source | Required observation | Current result and evidence |
| --- | --- | --- |
| Native-app text | Ordinary horizontal single-column copy | **Blocked** for final clean promotion — the historical isolated native fixture copied exact small and multiline text and regained focus; the current run has one controlled TextEdit result but no native-fixture repeat |
| Dark text on a light background | Exact ordinary phrase with readable ordering | **Blocked** for final clean promotion — the historical phrase copied exactly; the current OCR-source sweep is pending |
| Light text on a dark background | Exact ordinary phrase with readable ordering | **Blocked** for final clean promotion — the historical phrase copied exactly; the current OCR-source sweep is pending |
| Multiline paragraph | Top-to-bottom lines and left-to-right words remain readable | **Blocked** for source coverage — current TextEdit and Sidecar captures copied the controlled three-line paragraph exactly, but current raster, PDF, and paused-video presentations remain pending |
| Small text | Honest recognition or omission without invention or crash | **Blocked** for final clean promotion — the historical small-text and latency series copied exactly; the current small-text repeat is pending |
| Browser-rendered text | App-agnostic pixel recognition | **Blocked** for final clean promotion — the historical browser phrase copied successfully; the current browser repeat is pending |
| PDF text in Preview | Works independently of PDF text layer | **Blocked** for final clean promotion — the historical Preview capture copied exactly; the current PDF repeat is pending |
| Raster image | Visible text recognized from pixels | **Blocked** for final clean promotion — the historical five-image sweep matched; the current raster repeat is pending |
| Nonselectable raster text in an arbitrary app | OCR depends only on permitted screen pixels | **Blocked** for final clean promotion — the historical native-fixture raster matched; the current repeat is pending |
| Paused video | Visible subtitle/title recognized | **Blocked** for final clean promotion — the historical paused-video capture copied exactly; the current repeat is pending |
| macOS system UI | Menu/dialog/settings text recognized when permitted | **Blocked** for final clean promotion — the historical controlled `NSAlert` copied correctly; the current system-UI repeat is pending |
| Desktop wallpaper text | Arbitrary permitted screen pixels | **Blocked** |
| Photograph of a street sign | Expected phrase without invented content | **Blocked** for final clean promotion — the historical photographic fixture copied exactly; the current repeat is pending |
| Deliberately difficult text | Honest degradation or no-text; no crash/invention | **Blocked** for final clean promotion — the historical moderate-low-contrast fixture copied exactly. The current blank-region visual result produced a no-text HUD, but its shared sentinel batch was inconclusive and requires an isolated repeat |
| Unsupported multi-column layout | Imperfect ordering allowed; no crash or invented text | **Blocked** for final clean promotion — the historical column tokens appeared without invention; the current repeat is pending |

## Performance Protocol

Use an otherwise idle workstation. Preserve raw Instruments traces outside Git and record only aggregate, content-free results here.

### Cold Launch

- Run ten true cold launches after completed onboarding.
- Measure from process launch request to the visible, interactive menu-bar item.
- Record every sample and median/p95. Acceptance: every observed cold launch exposes the item within 2 seconds.
- Record `cold_launch_ms: [s1, s2, ..., s10]`, median, nearest-rank p95,
  minimum, and maximum. Do not retain only an aggregate.

### Capture To Clipboard

- Use one ordinary 600×200-ish text region for 30 shortcut captures.
- Measure mouse-up to pasteboard change. Separately note HUD appearance.
- Sort samples; use the median and nearest-rank p95.
- Acceptance: median at most 1 second and p95 at most 2 seconds.
- Repeat representative native, browser, PDF, raster, video, photograph, and difficult-text regions as qualitative signposts. Do not merge dissimilar content into the acceptance sample.
- Record `capture_to_clipboard_ms: [s1, s2, ..., s30]`, median,
  nearest-rank p95, minimum, and maximum. Record failed attempts separately;
  never silently discard or replace an outlier.

### Capture And OCR Stage Signposts

- During at least ten successful ordinary-region captures, use a Time Profiler
  trace to record the best directly observable boundaries for selection
  completion, ScreenCaptureKit return, Vision return, clipboard change, and HUD
  presentation.
- Report capture and OCR stage medians/p95 separately when the trace exposes
  defensible boundaries. Never infer a stage duration merely by subtracting
  unrelated UI timestamps.
- Do not add captured text, image dimensions tied to private content, or OCR
  output to logs or signposts. Raw traces remain ignored because they may contain
  local paths and process metadata.
- If the production build exposes no reliable content-free boundary for an
  individual stage, mark that stage **Blocked** and request a narrowly scoped
  instrumentation amendment. End-to-end latency is still mandatory and cannot
  substitute for the missing per-stage signpost.

| Stage | Samples | Median | p95 | Evidence or blocker |
| --- | ---: | ---: | ---: | --- |
| Mouse-up to ScreenCaptureKit return | 30 | 102.276 ms | 112.303 ms | **Blocked** — the required ordinary-region trace did not run; content-free LLDB entry/async-resume timings for the small-text line remain diagnostic context |
| ScreenCaptureKit return to Vision return | 30 | 42.229 ms | 144.185 ms | **Blocked** — the required ordinary-region trace did not run; capture async-resume to Vision async-resume timings for the small-text line remain diagnostic context |
| Vision return to pasteboard change | 30 | 6.612 ms | 8.111 ms | **Blocked** — the required ordinary-region trace did not run; Vision async-resume to write-only clipboard timings for the small-text line remain diagnostic context |
| Mouse-up to HUD presentation | 30 | 159.710 ms | 263.869 ms | **Blocked** — the required ordinary-region trace did not run; selection mouse-up to feedback presentation timings for the small-text line remain diagnostic context |

### Idle CPU And Memory

- After launch, wait 30 seconds, then sample CPU and memory once per second for 60 seconds.
- Record private memory and RSS consistently; do not compare unlike measures.
- Acceptance: idle CPU settles below 1% on the maintainer workstation.

### Repeated-Capture Growth

- Record baseline memory after the idle settle.
- Execute 100 cycles: 50 successful captures and 50 cancellations, alternating where possible.
- Sample after every ten cycles and again after a 30-second settle.
- Use Allocations and Leaks plus a Time Profiler trace. Record peak, final settled memory, leak count, and any retained `CGImage`, recognized observation, unbounded string, overlay, or feedback controller.
- Acceptance: no sustained growth trend attributable to CopyLasso and no retained private-operation payload.

Record cycle number, outcome, private memory, RSS, and any retained-object or
leak observation after each ten-cycle checkpoint. Keep all 11 checkpoints
(baseline plus cycles 10 through 100) in the signed result rather than only the
peak and final values.

### Interactive Measurements To Date

The historical cold-launch, capture, stage, idle, and repeated-capture sections
below use the July 13 exact signed artifact, with raw files ignored at
`.build/g24-interactive-current`. The separately labeled final-clean idle result
uses exact head `f6f75c0` and `.build/g24-final-current`.

#### Cold Launch Result

The maintainer watched the menu-bar icon disappear and reappear during ten
exact-artifact launches. No app window or Dock item appeared. The recorded
timestamps measured process visibility, not status-item visibility or
interactivity, and therefore remain diagnostic context:

`cold_launch_ms: [72, 70, 72, 68, 59, 74, 69, 73, 73, 68]`

Median process visibility was 71 ms; nearest-rank p95 was 74 ms; minimum was 59
ms and maximum was 74 ms. Because those samples do not time the protocol's
visible, interactive menu-bar item, cold launch remains **Blocked**.

#### Capture-To-Clipboard Result

Thirty consecutive captures selected the same controlled small-text line. All 30
produced clipboard text and a HUD; the maintainer reported only the accepted
occasional crosshair miss. The first 30 complete samples were retained in
original order, and one subsequent extra capture was excluded explicitly rather
than used to replace any outlier. This line was not the protocol's ordinary
600×200-ish region, so the samples are diagnostic context rather than the final
capture-to-clipboard acceptance series.

`capture_to_clipboard_ms: [279.367, 255.590, 148.761, 165.272, 166.092, 158.250, 156.766, 145.901, 146.187, 140.337, 148.870, 143.554, 158.241, 155.355, 148.874, 154.155, 146.564, 147.992, 153.763, 149.268, 149.671, 139.559, 150.499, 166.430, 156.413, 162.778, 146.656, 159.900, 155.979, 152.314]`

Median was 153.038 ms; nearest-rank p95 was 255.590 ms; minimum was 139.559 ms
and maximum was 279.367 ms. These values are below the one-second median and
two-second p95 limits for this small-text line, but capture-to-clipboard remains
**Blocked** until the required ordinary 600×200-ish region is sampled.

The same content-free probe recorded these supporting arrays:

- `mouse_up_to_capture_return_ms: [104.902, 103.509, 102.986, 111.207, 109.597, 109.457, 108.904, 96.073, 98.635, 95.395, 100.031, 95.506, 101.648, 98.952, 92.505, 107.835, 98.589, 101.394, 103.793, 100.574, 102.030, 90.548, 102.523, 108.927, 107.570, 112.303, 96.624, 113.625, 105.964, 95.695]`
- `capture_return_to_vision_return_ms: [165.704, 144.185, 39.247, 47.256, 49.851, 42.151, 41.474, 43.288, 40.969, 38.321, 42.207, 41.605, 49.625, 49.882, 49.838, 39.815, 41.418, 39.831, 43.520, 42.324, 40.525, 42.219, 41.280, 50.548, 42.239, 43.937, 41.920, 38.863, 43.436, 50.102]`
- `vision_return_to_clipboard_ms: [8.762, 7.896, 6.528, 6.810, 6.643, 6.642, 6.388, 6.540, 6.584, 6.620, 6.632, 6.443, 6.968, 6.521, 6.530, 6.505, 6.558, 6.767, 6.449, 6.369, 7.116, 6.792, 6.696, 6.955, 6.604, 6.538, 8.111, 7.412, 6.579, 6.518]`
- `mouse_up_to_hud_ms: [286.993, 263.869, 155.565, 172.253, 173.199, 164.993, 163.322, 152.304, 152.867, 146.923, 155.587, 150.308, 164.929, 161.985, 155.517, 160.675, 153.369, 154.726, 160.442, 155.832, 156.553, 146.796, 157.089, 173.437, 163.677, 169.316, 153.234, 167.110, 163.040, 158.978]`

The debugger breakpoints add conservative measurement overhead rather than
making these results artificially faster. A simultaneous 56.536-second Time
Profiler trace covered all 30 captures and exported 4,290 time-profile rows,
with zero potential-hang and zero hang-risk rows.

#### July 13 Idle Result

After a 30-second settle, 60 one-second samples all reported 0.0% CPU. RSS
minimum/average/maximum was 101,472/108,606.4/115,872 KiB and declined across
the sample. Idle CPU therefore **Passes** the below-1% criterion. Raw samples
remain ignored at `.build/g24-interactive-current/idle-samples.tsv`.

#### Final-Clean `f6f75c0` Idle Result

The final clean rerun independently repeated the same protocol after
the clean permission and Sidecar work. All 60 samples again reported 0.0% CPU;
RSS minimum/average/maximum was 98,832/98,909.6/98,928 KiB. Physical footprint
was 66 MiB immediately afterward, and `/usr/bin/leaks` reported zero leaked
bytes. This exact-head rerun therefore **Passes** the idle criterion. Its raw
samples remain ignored at `.build/g24-final-current/idle-samples.tsv`.

#### Repeated-Capture Growth Result

A fresh exact process ran under an Allocations trace and a minimal content-free
cycle counter. The first exact 100 outcomes were 50 successful captures and 50
Escape cancellations in alternating order. Every success produced copied text
and a HUD; every cancellation returned to reuse. The maintainer observed only
the accepted occasional crosshair miss.

| Checkpoint | Success | Cancel | Physical footprint (MiB) | RSS (KiB) |
| --- | ---: | ---: | ---: | ---: |
| Baseline after 30-second settle | 0 | 0 | 20 | 88,656 |
| 10 | 5 | 5 | 100 | 184,288 |
| 20 | 10 | 10 | 101 | 186,080 |
| 30 | 15 | 15 | 220 | 186,736 |
| 40 | 20 | 20 | 223 | 187,392 |
| 50 | 25 | 25 | 223 | 187,792 |
| 60 | 30 | 30 | 226 | 187,936 |
| 70 | 35 | 35 | 223 | 187,984 |
| 80 | 40 | 40 | 221 | 188,144 |
| 90 | 45 | 45 | 225 | 188,176 |
| 100 | 50 | 50 | 223 | 188,272 |

The stop cue reached the maintainer after seven extra pairs, so those 14 extra
events were excluded from the exact 100-cycle acceptance sequence but retained
in the raw trace. The first automated settle was rejected because it overlapped
those events. After a new uninterrupted 30-second idle interval, physical
footprint was 94 MiB and RSS was 173,312 KiB; after stopping Allocations and
running Leaks, they declined further to 62 MiB and 140,800 KiB.

From checkpoints 30 through 100, active physical footprint stayed within
220–226 MiB with a fitted slope of 0.026 MiB/cycle; RSS stayed within
186,736–188,272 KiB with a fitted slope of 18.781 KiB/cycle. The post-operation
drop, bounded plateau, and zero-leak result are consistent with one-time Vision/
ScreenCaptureKit caches rather than per-cycle retained payload. `/usr/bin/leaks`
reported 101,957 malloc nodes using 19,235 KiB and **0 leaks for 0 leaked
bytes**; measured peak physical footprint was 248.8 MiB. The Allocations trace
covered 326.751 seconds. Final residue inspection found no controlled OCR text,
image, or PDF retained by the app. This is strong no-sustained-growth context,
but the repeated-capture protocol remains **Blocked** because its required Time
Profiler trace did not run alongside the 100-cycle process; the existing Time
Profiler trace covers the separate 30-capture latency batch.

## Noninteractive Process Context

These measurements used the exact G23 Release artifact at `98656f26b3bc7667663fe1cf14daa6921d5ab947`, version 0.1.0 build 1, ad-hoc signed with App Sandbox and Hardened Runtime. They did not execute Capture Text and do not satisfy the signed Debug or real-workflow criteria.

| Measurement | Result | Interpretation |
| --- | --- | --- |
| Post-settle CPU, ten 1-second samples | min/average/max all 0.0% | **Context pass** for an idle locked Release process; interactive signed rerun required |
| Private memory from `top` | 31 MB first sample, then 28–29 MB | No growth during the short idle sample |
| RSS from `ps` | 99,232–99,696 KiB; average 99,368 KiB | Stable across the ten samples; not comparable to private-memory column |
| Time Profiler | 10.710 seconds, nine rows, two running timer samples, zero potential-hang rows, zero hang-risk rows | Very little sampled CPU activity while idle |
| Leaks template | **Blocked** — did not honor its 10-second limit while attached in the locked session and required terminating the profiler | No leak conclusion; rerun interactively during the 100-cycle matrix |
| Cold process survival | Process remained alive through the smoke interval | Does not reveal status-item visibility or interactivity |

The raw `.trace`, XML, logs, and samples remain ignored build artifacts and must not be committed because Instruments metadata contains local paths and environment details.

## Completion Rule

G24 is complete only when every row above has a fresh Pass, Fail, Blocked, or Not-applicable result from one coherent signed run **and** the four numeric acceptance criteria have actual interactive measurements. Any product failure becomes a narrowly scoped defect goal; do not modify production behavior inside G24. After that fix merges, restart this protocol from clean state.

The final clean rerun has fresh passing idle CPU and three 2x Sidecar capture
measurements. It also has one exact 1x Dell capture and the expected clamp
behavior across three cross-display drags. The cross-display row passes; the
display-scale row remains blocked until two more Dell observations meet its
three-run minimum.
Interactive status-item cold launch, the official ordinary-region latency
series, the simultaneous 100-cycle Time Profiler/Allocations requirement, the
isolated clipboard repeats, Finder/browser/native-app/menu/full-screen/offline
repeats, remaining lifecycle and persistence phases, appearance and assistive
technology, protected content, and wallpaper remain pending. Every matrix row
has an explicit state; G24 remains **in progress**, not complete, and no pending
row is promoted from historical or automated evidence.
