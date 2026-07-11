# Manual QA And Performance Record

**Protocol version:** 1

**Goal:** G24

**Execution state:** blocked pending an unlocked, interactive, stably signed Debug session

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

The July 11, 2026 unattended context was an Apple M5 Pro MacBook Pro (`Mac17,9`, 15 cores, 24 GB), macOS 26.5.1 (`25F80`), and Xcode 26.6 (`17F113`). Only one online 1920×1080 Dell display was reported; Sidecar was disconnected. The graphical session remained behind the login-window shield, so this context is not the required interactive environment.

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

## Functional And Recovery Matrix

Run each row at least three times unless a larger sample is specified.

| Scenario | Expected result | July 11 unattended result |
| --- | --- | --- |
| Cold launch | One status item within 2 seconds; no Dock icon or initial app window after completed onboarding | **Blocked** — shield prevents status-item/window observation |
| Suggested shortcut with Finder frontmost | Overlay begins without opening the menu or stealing focus | **Blocked** — no interactive input |
| Shortcut with browser and TextEdit frontmost | Same command path and focus preservation | **Blocked** — no interactive input |
| Menu fallback | Capture Text remains usable and matches shortcut behavior | **Blocked** — menu inaccessible behind shield |
| Ordinary success | Selected text reaches plain-text clipboard; bounded success HUD appears without activation | **Blocked** — no real selection/capture/paste |
| Reverse drag and every edge | Correct region, initiating-display clamp, no orphaned panel/cursor | **Blocked** — no pointer input |
| Escape before/during drag | Normal cancellation; clipboard sentinel unchanged; immediate reuse | **Blocked** — no keyboard/pointer input |
| Click and sub-4-point drag | Too-small cancellation; sentinel unchanged | **Blocked** — no pointer input |
| No recognizable text | No-text HUD; sentinel unchanged | **Blocked** — no real capture |
| Permission first request: Deny | One system request, singleton recovery, no downstream work | **Blocked** — TCC dialog cannot be operated |
| Permission approval/retry | Follow actual Later/Quit & Reopen behavior; no automatic retry | **Blocked** — TCC/System Settings inaccessible |
| Permission revocation | Controlled likely-revoked recovery after authoritative denial | **Blocked** — requires interactive revoke/capture |
| Sleep and wake during every active phase | One system-interruption cancellation, cleanup, no auto-resume, immediate reuse | **Blocked** — disruptive physical lifecycle action unavailable |
| Lock and unlock during every active phase | Same lifecycle contract and no sensitive residue | **Blocked** — session is already locked and cannot be unlocked |
| Launch at Login enabled/disabled | Correct dockless presence after real logout/login or reboot | **Blocked** — requires maintainer login cycle |
| Light, dark, increased contrast, reduced motion, maximum text size | Legible native UI, two-tone selection, no app animation, no clipped text | **Blocked** — appearance and Accessibility UI unavailable |
| VoiceOver and Full Keyboard Access | Clear labels/order/actions across menu, onboarding, Settings, recovery, selection, and HUD | **Blocked** — accessibility shield prevents inspection |
| Offline success | Core workflow succeeds with process networking denied | **Blocked** for real pixels; 196 injected/fixture tests passed under deny-network sandbox in G23 |
| Protected content | Controlled blank/unavailable/no-text behavior; no bypass or invented text | **Blocked** — requires real protected surface |

## OCR Content Matrix

For each source, record the exact selected region, expected visible text, copied text, ordering errors, omissions, inventions, and elapsed time. Do not use real credentials or private content.

| Source | Required observation | July 11 unattended result |
| --- | --- | --- |
| Native-app text | Ordinary horizontal single-column copy | **Blocked** |
| Browser-rendered text | App-agnostic pixel recognition | **Blocked** |
| PDF text in Preview | Works independently of PDF text layer | **Blocked** |
| Raster image | Visible text recognized from pixels | **Blocked** |
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

### Capture To Clipboard

- Use one ordinary 600×200-ish text region for 30 shortcut captures.
- Measure mouse-up to pasteboard change. Separately note HUD appearance.
- Sort samples; use the median and nearest-rank p95.
- Acceptance: median at most 1 second and p95 at most 2 seconds.
- Repeat representative native, browser, PDF, raster, video, photograph, and difficult-text regions as qualitative signposts. Do not merge dissimilar content into the acceptance sample.

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
