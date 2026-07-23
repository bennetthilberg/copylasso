# Security And Privacy Review

This review describes the public CopyLasso 0.1.x boundary and the secure updater now present in source for the planned v0.2 release. It reconciles the source, built products, dependency graph, entitlements, persistence, and public privacy promises. The public 0.1.1 artifact remains the current release and contains no updater.

## Result

The implementation remains local-first and offline-capable. Screen Recording is the only macOS privacy permission required by the core workflow. The app has no content-history store, account, telemetry, or crash-reporting SDK. Its sole network capability is the isolated, user-controlled Sparkle updater; capture, OCR, clipboard output, Settings, onboarding, and Launch at Login remain operational with update networking unavailable.

The tracked `CopyLasso.entitlements` contains App Sandbox, outbound network client, and exactly Sparkle's two versioned installer-service Mach lookup names. Both app configurations use that file and keep Hardened Runtime enabled. There is no inbound server, device, file, application-group, or other temporary-exception capability. Screen Recording consent is managed by macOS TCC rather than an entitlement.

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
| Update check | Fixed HTTPS feed request and authenticated inline metadata | Active check or user-visible transaction | Automatic-check schedule and preference, deferred build, and highest authenticated build only |
| Update package | Signed DMG bytes staged by Sparkle | Bounded active transaction through verified installation or cleanup | Installed application after explicit final consent; no CopyLasso content data |

Cancellation before clipboard output leaves the existing pasteboard unchanged. If output already succeeded and a later lifecycle interruption dismisses feedback, CopyLasso does not read the pasteboard to roll that completed write back.

## Retained State

CopyLasso owns only these preference categories:

- completed onboarding version;
- whether shortcut and Launch at Login choices have been configured;
- whether Screen Recording was requested and whether access was previously observed; and
- `KeyboardShortcuts_captureText`, an encoded key/modifier choice maintained by the pinned shortcut package;
- Sparkle's automatic-check schedule and user preference; and
- `updates.deferredBuild` plus `updates.highestAuthenticatedBuild`, which contain canonical build numbers only.

macOS and SwiftUI may also retain ordinary window-frame metadata. Launch at Login's actual state remains owned by `SMAppService` and is re-read rather than duplicated as authoritative app state.

An inspected development container contained preference/window metadata, one 240-byte macOS CrashReporter registration-date plist, and zero-byte XCTest coverage files. It contained no image or recognized-text file. The crash registration and coverage files are system/development artifacts, not CopyLasso capture history. A fresh before/after inventory across multiple real captures remains part of the signed manual matrix because the G22 session was locked.

## Permissions, Entitlements, And Network

- App Sandbox: required in the reviewed source entitlement and verified in locally signed Debug and Release products.
- Hardened Runtime: enabled in both app configurations and verified by the signed CodeDirectory runtime flag.
- Network client: present solely for Sparkle's fixed signed-feed and immutable GitHub enclosure requests. The app has no second networking stack, custom headers, cookie use, query parameters, system profiling, or external release-note request.
- Network server: absent.
- Sparkle installer services: exactly `$(PRODUCT_BUNDLE_IDENTIFIER)-spks` and `$(PRODUCT_BUNDLE_IDENTIFIER)-spki`; the separate downloader service is disabled.
- Screen Recording: requested only after a user Capture Text command.
- Accessibility and Input Monitoring: not required by the shortcut, menu, selection, OCR, or output path.
- Microphone and system audio: not requested; ScreenCaptureKit capture disables audio.
- Files and folders: no user-selected or temporary-file entitlement; captured pixels never use a file intermediate.

Settings links ask macOS to open the user's default browser. CopyLasso itself does not fetch those URLs. The shipping updater is isolated from core capture and has one fixed feed URL. Automatic checks default on at a 24-hour interval but can be disabled; manual checks remain available. Download and install never occur automatically. The user sees authenticated version, inline plain-text notes, and exact size before download, then explicitly confirms download and later install/relaunch.

The feed server and GitHub can observe ordinary transport metadata, including IP address, request time, and the CopyLasso/Sparkle versions in the ordinary user agent. Requests contain no pixels, geometry, recognized text, clipboard data, HUD preview, frontmost-application identity, hardware profile, stable identifier, analytics event, or telemetry. The public 0.1.x line remains a manual-update bootstrap; G36 creates no public feed or release.

Local Apple Development signing adds `com.apple.security.get-task-allow` to audited development-signed products. That key is not present in the tracked product entitlement or shipped Developer ID artifact. The released application was verified to contain only the Boolean App Sandbox entitlement, with no `get-task-allow` or unreviewed capability, before and after notarization.

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
| Dependency compromise | KeyboardShortcuts and Sparkle are exact-version and exact-revision pinned, licensed, and covered by complete local notices. Sparkle is confined to one production adapter plus direct policy/session tests; canonical audits verify its framework, configuration, public key, installer entitlements, and absence of a second network stack. |
| Feed, hosting, DNS, or transport compromise | The compiled public key authenticates both the appcast and enclosure. Policy accepts one fixed feed, one exact version-matched GitHub asset shape, nonempty inline plain-text notes, canonical monotonic builds, and a 256 MiB cap. Transport cannot authorize installation. |
| Replay or downgrade | The installed build is the baseline and the highest authenticated build persists across deferral; lower candidates fail closed. Malformed persisted state also fails closed. |
| Oversized, truncated, or interrupted download | Expected and received bytes must match the signed length and remain within 256 MiB. Overflow, cancellation, timeout, disk failure, extraction failure, or installation failure cancels once, removes staging, and preserves the installed app. |
| Unwanted update | Automatic checks may be disabled. Automatic download and installation are disabled. The user must first choose Download and later choose Install and Relaunch; Later, Cancel, Escape, or closing the panel preserves the installed app. |
| Shortcut collision or spoofed event | The package validates and records the configured key combination; every event enters the same busy-rejecting command. A shortcut cannot bypass consent or selection. |
| Malformed OCR geometry or text | Pure formatting tests retain nonempty observations conservatively, reject invalid geometry safely, and output plain text only. |

## Dependency Inventory

| Dependency | Scope | Version and revision | Purpose | License | Upstream |
| --- | --- | --- | --- | --- | --- |
| KeyboardShortcuts | Shipping application and tests | 3.0.1, `49c3fc04ea827f816df67843bfcc57286b47ff06` | Global shortcut recording, validation, persistence, registration, replacement, and clearing | MIT | <https://github.com/sindresorhus/KeyboardShortcuts> |
| Sparkle | Shipping application and tests | 2.9.4, `b6496a74a087257ef5e6da1c5b29a447a60f5bd7` | Signed appcast and enclosure verification, bounded download, staging, sandboxed installation, relaunch, and comparator behavior | Permissive Sparkle license bundle | <https://github.com/sparkle-project/Sparkle/blob/2.9.4/LICENSE> |

KeyboardShortcuts declares no transitive dependency. The Release executable contains its code statically. Native macOS APIs provide lower-level event registration but no SwiftUI recorder plus persistence/conflict-management abstraction; the package materially reduces input and lifecycle risk. Its exact license text and attribution are in [Third-Party Notices](../THIRD_PARTY_NOTICES.md). A July 22, 2026 GitHub Advisory Database query for KeyboardShortcuts 3.0.1 returned zero matching Swift advisories; this time-sensitive check must be repeated for each release.

Sparkle is a shipping binary framework in G36. Its exact tag, source revision, official artifact checksum, complete shipped license bundle, About acknowledgement, fixed configuration, entitlement boundary, and justification are recorded in [Third-Party Notices](../THIRD_PARTY_NOTICES.md), [ADR-004](architecture/ADR-004-secure-updates.md), and the secure-update audit. `SUEnableDownloaderService` is false; the bundled downloader XPC is inert and receives no downloader-service Mach entitlement. Release qualification must repeat advisory, framework-signature, nested-code, architecture, and notarization checks.

GitHub's tag readback records Sparkle 2.9.4 as a non-draft, non-prerelease release published July 3, 2026. A July 22, 2026 GitHub Advisory Database query for `sparkle@2.9.4` returned zero matching Swift advisories. This is a dated result, not a permanent guarantee; repeat it and review upstream release/security notices before every updater-enabled release.

## Reproducible Verification

Run the tracked source audit:

```sh
./scripts/audit-privacy-security.sh
```

The canonical CI entrypoint runs it before compiling. It validates the exact three-key entitlement contract, both build-configuration references, updater-only networking, absence of content-persistence APIs, logger confinement, tracked-secret and local-path scans, exact dependency scope, shipping notices, and absence of tracked prebuilt dependency binaries.

The complete application unit bundle also passes when invoked directly under a process sandbox with `(deny network*)`. This exercises real Vision fixtures plus permission, selection, capture planning, formatting, clipboard, feedback, lifecycle, Settings, and end-to-end orchestration tests without disabling the workstation's network connection; the canonical verification record reports the exact current suite count.

The signed manual privacy matrix in [Testing](testing.md) remains the release boundary for fresh real captures, container/temp-directory deltas, unified-log inspection, clipboard paste verification, and OS privacy-pane inspection. Static and injected tests are not substitutes for those observations.
