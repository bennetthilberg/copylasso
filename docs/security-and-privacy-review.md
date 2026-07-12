# Security And Privacy Review

This review describes CopyLasso's pre-release v0.1 implementation boundary. It reconciles the source, built products, dependency graph, entitlements, persistence, and public privacy promises.

## Result

The implementation remains local-first and offline-capable. Screen Recording is the only macOS privacy permission required by the core workflow. The app has no network-client or server entitlement, networking implementation, content-history store, updater, account, telemetry, or crash-reporting SDK.

The tracked `CopyLasso.entitlements` contains only `com.apple.security.app-sandbox = true`. Both app configurations use that file and keep Hardened Runtime enabled. Screen Recording consent is managed by macOS TCC rather than an entitlement.

## Data Flow And Lifetime

| Stage | Data | Lifetime and boundary | Persistent output |
| --- | --- | --- | --- |
| Request | Command event and payload-free coordinator state | One operation | None |
| Permission | Two local history booleans and direct Core Graphics observation | Preferences plus current check | Requested-before and observed-granted booleans only |
| Selection | Display identity, frames, scale, and rectangle | Active selection through capture validation | None |
| Capture | One `CGImage` for the selected local rectangle | Private async operation scope | None; no encoder or image writer exists |
| OCR | Text, confidence, and normalized bounds | Private async operation scope | None |
| Assembly | One plain `String` | Private async operation scope | None |
| Clipboard | Nonempty assembled text | Passed once to a write-only adapter | One system pasteboard plain-string item, controlled by macOS after the write |
| Feedback | No-text/failure copy or an at-most-80-character success preview | Approximately 2.5 seconds | None; the observable model clears on dismissal |
| Diagnostics | Fixed lifecycle event class | Unified logging policy | No payload, application name, geometry, content, or raw error |

Cancellation before clipboard output leaves the existing pasteboard unchanged. If output already succeeded and a later lifecycle interruption dismisses feedback, CopyLasso does not read the pasteboard to roll that completed write back.

## Retained State

CopyLasso owns only these preference categories:

- completed onboarding version;
- whether shortcut and Launch at Login choices have been configured;
- whether Screen Recording was requested and whether access was previously observed; and
- `KeyboardShortcuts_captureText`, an encoded key/modifier choice maintained by the pinned shortcut package.

macOS and SwiftUI may also retain ordinary window-frame metadata. Launch at Login's actual state remains owned by `SMAppService` and is re-read rather than duplicated as authoritative app state.

An inspected development container contained preference/window metadata, one 240-byte macOS CrashReporter registration-date plist, and zero-byte XCTest coverage files. It contained no image or recognized-text file. The crash registration and coverage files are system/development artifacts, not CopyLasso capture history. A fresh before/after inventory across multiple real captures remains part of the signed manual matrix because the G22 session was locked.

## Permissions, Entitlements, And Network

- App Sandbox: required in the reviewed source entitlement and verified in locally signed Debug and Release products.
- Hardened Runtime: enabled in both app configurations and verified by the signed CodeDirectory runtime flag.
- Network client/server: absent from the entitlement, app source, and linked non-system libraries.
- Screen Recording: requested only after a user Capture Text command.
- Accessibility and Input Monitoring: not required by the shortcut, menu, selection, OCR, or output path.
- Microphone and system audio: not requested; ScreenCaptureKit capture disables audio.
- Files and folders: no user-selected or temporary-file entitlement; captured pixels never use a file intermediate.

Settings links ask macOS to open the user's default browser. CopyLasso itself does not fetch those URLs. Releases are downloaded manually; v0.1 has no automatic updater.

Local Apple Development signing adds `com.apple.security.get-task-allow` to both audited development-signed products. That key is not present in the tracked product entitlement. G26 must read back the final Developer ID-signed archive and reject `get-task-allow` or any entitlement beyond App Sandbox before notarization.

## Trust Boundaries And Misuse Cases

| Boundary or misuse case | Mitigation and limitation |
| --- | --- |
| Broad Screen Recording consent | CopyLasso captures only after a user command and region selection, validates the initiating display snapshot, and keeps pixels in memory. macOS consent still authorizes the process at the OS boundary. |
| Wrong display after reconfiguration | Identity, point size, scale, bounds, and derived pixel dimensions must match a fresh ScreenCaptureKit snapshot or capture fails before OCR. |
| Protected or DRM content | CopyLasso follows macOS capture restrictions and does not bypass protected pixels. Blank protected output may yield no text. |
| Misleading or hostile visible text | OCR output is untrusted plain text. CopyLasso copies it but never executes it, interprets markup, follows a link, or invokes a shell. Users must review text before using it as a command or credential. |
| Clipboard visibility | After a successful write, macOS and other clipboard-aware software control access. CopyLasso writes one plain-string representation and never reads prior contents. |
| Crash or forced termination during private processing | Operation values are memory-only and no in-app crash reporter receives them. Operating-system diagnostics or a privileged memory inspector remain outside the app's trust boundary. |
| Diagnostic leakage | The only logger emits four fixed lifecycle messages. CI rejects interpolation and content-bearing logging APIs elsewhere. |
| Dependency compromise | The only third-party package is exact-version and exact-revision pinned, source-built, MIT licensed, covered by a full notice and justification, and has no transitive package dependency or network service. |
| Shortcut collision or spoofed event | The package validates and records the configured key combination; every event enters the same busy-rejecting command. A shortcut cannot bypass consent or selection. |
| Malformed OCR geometry or text | Pure formatting tests retain nonempty observations conservatively, reject invalid geometry safely, and output plain text only. |

## Dependency Inventory

| Dependency | Version and revision | Purpose | License | Upstream |
| --- | --- | --- | --- | --- |
| KeyboardShortcuts | 3.0.1, `49c3fc04ea827f816df67843bfcc57286b47ff06` | Global shortcut recording, validation, persistence, registration, replacement, and clearing | MIT | <https://github.com/sindresorhus/KeyboardShortcuts> |

The package manifest declares no transitive dependency. The Release executable contains its code statically and embeds no third-party dynamic framework. Native macOS APIs provide lower-level event registration but no SwiftUI recorder plus persistence/conflict-management abstraction; the package materially reduces input and lifecycle risk. Its exact license text and attribution are in [Third-Party Notices](../THIRD_PARTY_NOTICES.md). A GitHub Advisory Database query during this audit returned no advisory for the Swift package; this time-sensitive check must be repeated for each release.

## Reproducible Verification

Run the tracked source audit:

```sh
./scripts/audit-privacy-security.sh
```

The canonical CI entrypoint runs it before compiling. It validates the one-key entitlement, both build-configuration references, absence of network and content-persistence APIs, logger confinement, tracked-secret and local-path scans, the exact dependency inventory/notice/justification, and absence of prebuilt dependency binaries.

The complete application unit bundle also passes when invoked directly under a process sandbox with `(deny network*)`. This exercises real Vision fixtures plus permission, selection, capture planning, formatting, clipboard, feedback, lifecycle, Settings, and end-to-end orchestration tests without disabling the workstation's network connection; the canonical verification record reports the exact current suite count.

The signed manual privacy matrix in [Testing](testing.md) remains the release boundary for fresh real captures, container/temp-directory deltas, unified-log inspection, clipboard paste verification, and OS privacy-pane inspection. Static and injected tests are not substitutes for those observations.
