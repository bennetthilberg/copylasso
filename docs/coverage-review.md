# Automated Coverage Review

This review records the G23 behavioral coverage audit. Coverage is diagnostic evidence and a regression gate; it does not replace assertions, real Screen Recording tests, signed UI checks, or physical display qualification.

## Stable Baseline

The application target is measured from the nonparallel, timeout-bounded `CopyLassoTests` result produced by Xcode 26.6. Xcode's `xccov` reports executable-line, function, and subrange execution. It does not expose a stable source-level Swift branch percentage, so branch review combines those subranges with direct inspection of every condition and its behavioral tests.

| Metric | G22 baseline | Current reviewed baseline |
| --- | ---: | ---: |
| Unit tests | 187 | 214 |
| Stable application aggregate | 2,382 / 3,396 (70.14%) | 2,594 / 3,592 (72.21%) |
| Models, CaptureWorkflow, and Settings | 922 / 1,006 (91.65%) | 986 / 1,030 (95.72%) |
| `SettingsController.swift` | 144 / 168 (85.71%) | 167 / 172 (97.09%) |
| `TextAssembler.swift` | 164 / 203 (80.78%) | 186 / 203 (91.62%) |

The stable application aggregate excludes `OnboardingView.swift`, `LaunchAtLoginStatusView.swift`, and `MenuBarLabelView.swift`. Those app-hosted SwiftUI builders execute incidentally only while the Debug preference domain says onboarding is incomplete; signed QA legitimately changes that retained state. Their layout, focus, accessibility, and first-run behavior remain owned by the signed UI and manual checks below. The 70% floor is unchanged, and every other application file remains in the aggregate.

The G23 tests exercise idempotent Launch at Login state, approval/unavailable states, failed postcondition readback, every disable failure, explicit continuation without login, deterministic positioned and unpositioned text-order ties, NaN confidence, and signed-zero geometry. Review propagation adds direct configuration, permission-retry, display-size, fractional-edge, Debug runtime-option, cursor activation/restoration, and appearance regressions. G24R adds ten-cycle visible-feedback replacement, stale-timer isolation, failure-feedback presentation, and lifecycle dismissal coverage. The postcondition test found and fixed one real state-reporting defect: an external re-enable after an idempotent disable now reports a recoverable disable failure instead of returning false with no issue.

## Enforced Gate

`scripts/audit-coverage.sh` reads the canonical `UnitTests.xcresult` and fails when:

- the stable application aggregate falls below 70%;
- the platform-neutral Models, CaptureWorkflow, and Settings aggregate falls below 90%;
- a required core file disappears from coverage; or
- a reviewed per-file floor regresses. The strictest floors retain 100% for coordinator and persistent-state primitives, 98% for selection geometry, 95% for clipboard output, 92% for Settings, and 90% for capture orchestration, permission decisions, OCR, and text assembly.

These are regression floors below the reviewed values, not targets to game. A change that adds meaningful behavior must add behavioral tests even if the aggregate remains above its floor. Raising a floor follows evidence; lowering one requires an explicit roadmap amendment and written branch review.

## Uncovered-Region Review

| Region | Why it remains uncovered in the unit result | Required evidence |
| --- | --- | --- |
| SwiftUI `SettingsView`, `AboutView`, onboarding, status, and menu builders | Instantiating declarative builder branches without a window does not prove layout, focus, keyboard order, or accessibility. The aggregate explicitly excludes the three retained-state-dependent onboarding builders so a developer completing setup cannot change the gate without changing code. | Signed focused XCUITests plus the G21/G24 manual accessibility matrix. UI tests have no unconditional retry and are not reported as hosted passes when the runner is unsigned or shielded by `loginwindow`. |
| `CopyLassoApp` entrypoint and real application termination | A unit test must not start a second app lifecycle or terminate its own process. Root wiring is exercised through injected command/menu tests. | Signed cold-launch, singleton-window, menu, login-item, and Quit checks. |
| Debug-only permission/selection/capture UI doubles | They exist solely to make signed XCUITests deterministic and are compiled out of Release. | Their controlled UI tests and Release binary/source guards. |
| AppKit selection panel/event-monitor paths | Pure geometry, clamping, session cancellation, cleanup ordering, and panel-controller seams are directly tested. WindowServer focus, Spaces, display change, cursor, and real mouse delivery are not faithfully reproducible in unit tests. | G13/G19 signed overlay matrices and G24 physical QA. |
| Live ScreenCaptureKit client closure | Request planning, fresh-display validation, error mapping, output size, and image lifetime use injected clients. Invoking the live closure would depend on TCC and real display pixels. | G14 signed capture matrix and G24 arbitrary-pixel QA. |
| Live Core Graphics permission and `SMAppService` backend closures | Neutral history/state decisions and every service result are injected. The OS dialogs, Settings deep links, and login registration belong to macOS state. | G10-G12 signed permission/login matrices. |
| Vision result edge subranges | Real fixtures cover blank, clean, low-contrast, small, dark, rasterized, and photographic text; cancellation and error mapping are injected. Vision does not offer a public constructor for a recognized observation whose `topCandidates(1)` is empty. | Fixture expectations plus G24 difficult-content QA. |
| Pasteboard item preparation failure | The service's false/failure decision is injected. AppKit does not expose a deterministic way to make a fresh `NSPasteboardItem.setString` reject an ordinary Swift string. | Isolated AppKit pasteboard success test and fault-injecting backend test. |
| Defensive collection fallbacks and impossible ordering ties | Text lines are constructed nonempty. Separate valid lines cannot share an identical top edge because their vertical overlap would group them. Exact same-text/same-geometry candidates are deduplicated before sort. | Invariant tests, deterministic permutation tests, and the 90% text-assembly floor. |
| Operation cancellation instruction-level races | Tests hold and cancel every async service phase, test cancellation before scheduled work, duplicate interruptions, 100 rapid busy requests, and exactly-once terminal recovery. Injecting cancellation between individual synchronous main-actor instructions would be scheduler testing rather than a stable product assertion. | Complete phase-gate suite and lifecycle stress tests. |

No production branch is excluded merely because it is difficult. The table identifies the boundary that makes automation nonrepresentative and points to the signed or physical evidence that owns it.

## Reproduction

Run the canonical pipeline and inspect the result:

```sh
./scripts/ci.sh
./scripts/audit-coverage.sh .build/ci-$(uname -m)/UnitTests.xcresult
```

Canonical CI already proves determinism with three fresh result bundles. Re-run that gate independently with:

```sh
./scripts/test-repeatability.sh
```

CI runs the coverage and three-pass repeatability gates on the macOS 26 arm64 and Intel jobs. A separate macOS 14 arm64 job downloads the exact Xcode 26.6 Release artifact, verifies deployment metadata, signs it ad hoc on that runner, and holds a live process for the smoke interval without invoking protected resources.
