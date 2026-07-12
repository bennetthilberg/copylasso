# Manual QA And Performance Record

**Protocol version:** 1

**Goal:** G24

**Execution state:** G24R activation-handshake candidate pending signed rapid-reuse proof; complete clean G24 rerun pending

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

## Functional And Recovery Matrix

Run each row at least three times unless a larger sample is specified.
Replace each current **Blocked** entry with fresh signed-run evidence; do not
carry forward a historical result. Evidence must name the tested commit and
record the observed focus, clipboard, permission, display, and cleanup state
where those properties apply.

| Scenario | Expected result | Current result and evidence |
| --- | --- | --- |
| First launch from a clean installation | Onboarding appears once; no unexpected window, permission request, or Dock icon | **Blocked** — the app-local Debug reset reproduced onboarding without a launch-time permission request, but no quarantined release candidate exists before G27-G29 |
| Ordinary relaunch after completed onboarding | One status item, no onboarding, Dock icon, or initial window | **Pass** — ordinary signed relaunch preserved completed onboarding and `⌃⇧⌘2`, exposed one status item, and opened no app window or Dock item |
| Cold launch | One status item within 2 seconds; no Dock icon or initial app window after completed onboarding | **Blocked** — one observed signed launch became process-visible in 99 ms and exposed the status item, but the required ten visible samples and p95 remain pending |
| Shortcut setup and persistence | Confirm, replace, clear, and restore `⌃⇧⌘2`; relaunch and reboot preserve the stored choice | **Blocked** — confirm, conflict rejection, replacement with `⌃⇧⌘K`, clearing, default restoration, and ordinary-relaunch persistence passed; post-configuration reboot persistence remains untested |
| Suggested shortcut with Finder frontmost | Selection-only activation presents the crosshair, then restores Finder before downstream work | **Blocked** — the Chrome restoration path passed, but the Finder-specific observation remains pending |
| Shortcut with browser and TextEdit frontmost | Same command path and originating-app restoration | **Blocked** — Chrome focus restoration passed on the exact signed cursor-fix head; fresh TextEdit restoration remains pending |
| Shortcut with another native app frontmost | Same command path and restoration outside the specifically tested apps | **Blocked** — no fresh third-native-app result |
| Menu fallback with shortcut cleared | Capture Text remains usable and matches shortcut behavior | **Blocked** — a physical menu invocation reached the same production permission path, but it was not run while the shortcut was cleared |
| Rapid repeated shortcut while active | Requests during permission, selection, capture, or OCR are rejected; a request during feedback dismisses that HUD and immediately begins exactly one fresh selection | **Fail** — the first candidate intermittently failed around the third cycle; the decoupled-feedback candidate removed that workflow race but still sometimes left the arrow until mouse-down while a prior HUD was visible. The activation-handshake candidate is green in automation and requires a fresh signed rerun |
| Ordinary success | Selected text reaches plain-text clipboard; bounded success HUD appears after originating-app restoration | **Pass** — five signed selections completed through real ScreenCaptureKit, Vision, and the plain-text pasteboard; the cursor-fix run restored Chrome focus before the bounded success HUD finished |
| Selection cursor and drag rendering | Clear before mouse-down; one normal-sized crosshair replaces the pointer before and throughout the drag; initiating display dims outside the selection | **Pass** — on the exact signed cursor-fix head, one normal-sized crosshair appeared immediately and remained usable for a successful drag; no ordinary arrow or second reticle appeared |
| Reverse drag and every edge | Correct region, initiating-display clamp, no orphaned panel/cursor | **Blocked** — ordinary forward drags cleaned up, but reverse and four-edge coverage remains pending |
| Every connected display and backing scale | Correct display identity, point-to-pixel scale, crop, HUD placement, and focus restoration | **Blocked** — Dell 1× capture succeeded; physical Sidecar 2× capture remains pending |
| Cross-display drag | Initiating display alone dims; selection clamps at its edge and never spans displays | **Blocked** — both physical displays are connected, but neither cross-display direction has been exercised in this run |
| Full-screen app and changed Space | Selection-only activation appears over the intended full-screen Space, does not switch Spaces, and restores the originating app | **Blocked** — no fresh full-screen/Space result |
| Escape before/during drag | Normal cancellation; clipboard sentinel unchanged; immediate reuse | **Blocked** — no fresh physical Escape sequence |
| Click and sub-4-point drag | Too-small cancellation; sentinel unchanged | **Blocked** — no fresh tiny-drag sequence |
| Quit during selection | All panels/cursor state disappear exactly once and the process terminates without a clipboard change | **Blocked** — no fresh quit-during-selection sequence |
| No recognizable text | No-text HUD; sentinel unchanged | **Blocked** — no controlled blank-region result |
| Permission first request: Deny | One system request, singleton recovery, no downstream work | **Pass** — the first physical shortcut produced one macOS request and one CopyLasso recovery panel; Deny performed no capture, repeated **Try Again** reused the singleton panel, and the clipboard sentinel survived |
| Permission approval/retry | Follow actual Later/Quit & Reopen behavior; no automatic retry | **Pass** — System Settings opened directly to Screen & System Audio Recording, enabling CopyLasso and choosing **Later** caused no automatic retry, explicit retry remained unavailable until an ordinary quit/relaunch, and the next real capture succeeded after the macOS direct-screen-access **Allow** prompt |
| Permission revocation | Controlled likely-revoked recovery after authoritative denial | **Blocked** — the reset/deny/grant path passed, but post-grant revocation has not been exercised |
| Sleep and wake during every active phase | One system-interruption cancellation, cleanup, no auto-resume, immediate reuse | **Blocked** — no active-phase sleep/wake sequence |
| Lock and unlock during every active phase | Same lifecycle contract and no sensitive residue | **Blocked** — the session was successfully unlocked to resume G24, but no active-phase lock/unlock sequence ran |
| Launch at Login enabled/disabled | Correct dockless presence after real logout/login or reboot | **Blocked** — onboarding enabled exactly one login item pointing to the signed artifact; the required enabled and disabled login cycles remain pending |
| Light, dark, increased contrast, reduced motion, maximum text size | Legible native UI, two-tone selection, no app animation, no clipped text | **Blocked** — onboarding, Settings, recovery, and HUD were legible in the current dark appearance, and bright-background dimming passed; light mode, increased contrast, reduced motion, maximum text size, and border appearance remain pending after the cursor fix |
| VoiceOver and Full Keyboard Access | Clear labels/order/actions across menu, onboarding, Settings, recovery, selection, and HUD | **Blocked** — Computer Use confirmed labels/help/order for onboarding, Settings, recovery, and the selection overlay; VoiceOver speech and Full Keyboard Access remain untested |
| Offline success | Core workflow succeeds with process networking denied | **Blocked** for real pixels; 196 injected/fixture tests passed under deny-network sandbox in G23, but no signed interactive offline capture ran |
| Protected content | Controlled blank/unavailable/no-text behavior; no bypass or invented text | **Blocked** — no fresh protected-surface result |
| Clipboard preservation sweep | Sentinel survives every cancellation and failure before replacement begins. A fault-injected clear-success/write-rejection reports clipboard failure; the prior clipboard may already be lost under the accepted write-only v0.1 boundary | **Blocked** — denial and unavailable-retry preservation passed; remaining cancellation, no-text, lifecycle, and pre-replacement failure paths still need a coherent sweep. The post-clear rejection is deterministic service-boundary evidence rather than a claim that AppKit can be forced to reproduce it physically |
| Success feedback privacy | HUD shows the correct normalized, truncated preview; preserves focus; clears on time; leaves no preview in logs/preferences | **Pass** — the signed success HUD was bounded, truncated, nonactivating, and temporary; content-free preference and residue inspection found no feedback payload |
| Private-data residue | Before/after app-container and temporary-directory inventory contains no image/text output; unified log contains no selected content | **Blocked** — before/after inventory still reports zero CopyLasso image files and preferences contain settings keys only; the complete synthetic-fixture log/content sweep remains pending |
| Ordinary delete and reinstall | Onboarding remains complete when preferences remain; Launch at Login state is reconciled | **Blocked** — no installable release artifact exists yet |
| Complete uninstall and reinstall | Login item, preferences, app-owned container data, and Screen Recording entry are removed; onboarding returns cleanly | **Blocked** — final uninstall procedure is a G25 deliverable and authoritative VM proof is G29 |

### Resolved Cursor Block And Rerun Boundary

The first bright-background signed run showed only the ordinary arrow, and the
follow-up drawn-reticle candidate produced two pointers. The approved G24C fix
temporarily activates CopyLasso during selection, uses the normal system
crosshair, removes the drawn reticle, and restores the originating app before
completion. Exact-head signed testing passed that visual and focus-restoration
gate on July 12.

Per G24's stop condition, the earlier partial run is not promoted into a
complete result. After G24C's final review signal, G24 must restart its coherent
clean-state matrix and numeric baselines from the beginning.

## OCR Content Matrix

For each source, record the exact selected region, expected visible text, copied text, ordering errors, omissions, inventions, and elapsed time. Do not use real credentials or private content.

| Source | Required observation | Current result and evidence |
| --- | --- | --- |
| Native-app text | Ordinary horizontal single-column copy | **Blocked** |
| Dark text on a light background | Exact ordinary phrase with readable ordering | **Pass** — the single-line bright browser heading copied exactly |
| Light text on a dark background | Exact ordinary phrase with readable ordering | **Pass** — a three-line light-on-dark application message remained readable and in order; punctuation and shortcut glyphs showed minor OCR substitutions without a crash |
| Multiline paragraph | Top-to-bottom lines and left-to-right words remain readable | **Pass** — the same three-line region preserved top-to-bottom line order and readable word order; exact punctuation/glyph fidelity was imperfect |
| Small text | Honest recognition or omission without invention or crash | **Blocked** |
| Browser-rendered text | App-agnostic pixel recognition | **Pass** — the single-line browser fixture selection copied exactly through the pixel workflow without using page structure |
| PDF text in Preview | Works independently of PDF text layer | **Blocked** |
| Raster image | Visible text recognized from pixels | **Blocked** |
| Nonselectable raster text in an arbitrary app | OCR depends only on permitted screen pixels | **Blocked** |
| Paused video | Visible subtitle/title recognized | **Blocked** |
| macOS system UI | Menu/dialog/settings text recognized when permitted | **Blocked** |
| Desktop wallpaper text | Arbitrary permitted screen pixels | **Blocked** |
| Photograph of a street sign | Expected phrase without invented content | **Blocked** |
| Deliberately difficult text | Honest degradation or no-text; no crash/invention | **Blocked** |
| Unsupported multi-column layout | Imperfect ordering allowed; no crash or invented text | **Blocked** |

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
| Mouse-up to ScreenCaptureKit return | Pending | Pending | Pending | **Blocked** — interactive trace required |
| ScreenCaptureKit return to Vision return | Pending | Pending | Pending | **Blocked** — interactive trace required |
| Vision return to pasteboard change | Pending | Pending | Pending | **Blocked** — interactive trace required |
| Mouse-up to HUD presentation | Pending | Pending | Pending | **Blocked** — interactive trace required |

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

One provisional exact-artifact idle sample completed before the final
permission/relaunch phase. After a 30-second settle, 60 one-second samples
reported CPU minimum/average/maximum of 0.00%/0.002%/0.10%, all below the 1%
acceptance threshold. RSS minimum/average/maximum was 66,608/67,229.1/77,664
KiB. Raw samples remain ignored at
`.build/g24-interactive/idle-samples.tsv`. Because the app was subsequently
restarted to complete the permission flow, this is supporting evidence rather
than the final coherent-run idle result.

One signed launch became process-visible in 99 ms and the maintainer observed
the menu-bar item, with no onboarding, Dock icon, or app window. The required
ten human-visible cold-launch samples have not run, so no cold-launch median or
p95 is reported. Capture-to-clipboard and stage-signpost samples have not yet
been timed, and the 100-cycle series has not begun.

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
