# Security And Privacy Review

This review describes the public CopyLasso 0.2.2 boundary. It reconciles the
source, shipped product, dependency graph, entitlements, persistence, and
public privacy promises. Version 0.1.x remains historical and contains none of
the updater, sound, or unified code-recognition additions described here.

G48 qualified `0.2.1 (4)` against this same boundary, and G49 published those
exact bytes without rebuilding. The maintenance release adds no permission,
entitlement, dependency, recognition mode, content persistence, or network
path. Immutable 0.2.0 evidence remains historical.

G50 published exact qualified `0.2.2 (5)` bytes without rebuilding. That
security-only release updates the shipping Sparkle dependency to 2.9.5 and
adds no permission, entitlement, destination, feature, or delta-update path.

G51 is an unreleased source amendment. It adds only an ordered local preference
of runtime-supported Vision language identifiers. It adds no model, dependency,
entitlement, permission, or network destination, and public 0.2.2 remains the
supported download.

G52 is a second unreleased v0.3 amendment. It adds an explicitly enabled,
bundle-scoped AES-256-GCM history of successful plain-text output. It adds no
dependency, entitlement, permission, network destination, account, analytics,
or screenshot persistence. Public 0.2.2 remains unchanged and has no history.

## Result

The implementation remains local-first and offline-capable. Screen Recording is
the only macOS privacy permission required by the core workflow. The app has no
account, telemetry, or crash-reporting SDK. Unreleased source contains one
default-off encrypted history store; its sole network capability remains the
isolated, user-controlled Sparkle updater. Capture, history, text and code
recognition, clipboard output, local success sound, Settings, onboarding, and
Launch at Login remain operational with update networking unavailable.

The tracked `CopyLasso.entitlements` contains App Sandbox, outbound network client, and exactly Sparkle's two versioned installer-service Mach lookup names. Both app configurations use that file and keep Hardened Runtime enabled. There is no inbound server, device, file, application-group, or other temporary-exception capability. Screen Recording consent is managed by macOS TCC rather than an entitlement.

## Data Flow And Lifetime

| Stage | Data | Lifetime and boundary | Persistent output |
| --- | --- | --- | --- |
| Request | Unified Capture command event and payload-free coordinator state | One operation | None |
| Permission | Two local history booleans and direct Core Graphics observation | Preferences plus current check | Requested-before and observed-granted booleans only |
| Selection and capture | Transient pointer/button samples that derive a user-controlled rectangle, then one ScreenCaptureKit `CGImage` | Selection-scoped sampler and private async operation scope | None; no encoded subprocess image, file, or screenshot-clipboard output exists |
| Text recognition | Text, confidence, and normalized bounds | Private async operation scope | None |
| Code recognition | String payload, supported symbology, confidence, and normalized bounds | Private async operation scope | None |
| Assembly | One inert plain `String` | Private async operation scope | None |
| Clipboard | Nonempty assembled text | Passed once to a write-only adapter | One system pasteboard plain-string item, controlled by macOS after the write |
| Optional history | Exact successful text/code output, type, timestamp, and random identifier | Decrypted only while recording or the History window is open | One authenticated encrypted archive plus one bundle-scoped Keychain key; off by default |
| Sound | Enabled state and one content-free play/stop command | Successful clipboard completion or lifecycle cleanup | One versioned Boolean preference; no content |
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
- the unreleased legacy `KeyboardShortcuts_captureCode` value is cleared during migration and Debug reset rather than retained as a user-facing second shortcut;
- the versioned `feedback.successSoundEnabled` Boolean, defaulting on and preserving explicit opt-out;
- the versioned ordered OCR language identifiers, defaulting to `en-US` and
  validated against the current accurate revision-3 Vision catalog;
- the unreleased `privacy.captureHistoryEnabled` Boolean, defaulting off;
- while that preference is on, one seven-day AES-256-GCM archive containing at
  most 100 successful outputs of at most 256 KiB each, plus the independently
  bundle-scoped Keychain account `archive-key-v1`;
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
- Screen Recording: requested only after a user Capture command. Current source may also show macOS's direct-screen-access confirmation for its native interactive selector; this is the same TCC category, not another entitlement.
- Accessibility and Input Monitoring: not required by the shortcut, menu, selection, OCR, or output path.
- Microphone and system-audio capture: not requested. The native selector receives no audio option, and the output-only success sound uses `NSSound` without requesting a privacy permission.
- Files and folders: no user-selected or temporary-file entitlement; the fixed
  selector's unused image destination is `/dev/null`, ScreenCaptureKit returns
  selected pixels directly in memory, and optional history uses only the app's
  sandboxed Application Support directory.

Settings links ask macOS to open the user's default browser. CopyLasso itself does not fetch those URLs. The shipping updater is isolated from core capture and has one fixed feed URL. Automatic checks default on at a 24-hour interval but can be disabled; manual checks remain available. Download and install never occur automatically. The user sees authenticated version, inline plain-text notes, and exact size before download, then explicitly confirms download and later install/relaunch.

The feed server and GitHub can observe ordinary transport metadata, including
IP address, request time, and the CopyLasso/Sparkle versions in the ordinary
user agent. Requests contain no pixels, geometry, recognized text, clipboard
data, HUD preview, frontmost-application identity, hardware profile, stable
identifier, analytics event, or telemetry. Public 0.2.2 authenticates the
published feed; users of 0.1.x must install the latest release manually once
because their existing binaries contain no updater.

Local Apple Development signing adds `com.apple.security.get-task-allow` to
audited development-signed products. That key is not present in the tracked
product entitlement or a Developer ID artifact. The historical public 0.1.1
application was verified to contain only the Boolean App Sandbox entitlement
before and after notarization. The public v0.2.0, v0.2.1, and v0.2.2 Developer ID artifacts verify
exactly Boolean App Sandbox, Boolean outbound network client, and the two
production-bundle Sparkle installer-service names, with no `get-task-allow`,
downloader-service name, or unrelated capability.

## Trust Boundaries And Misuse Cases

| Boundary or misuse case | Mitigation and limitation |
| --- | --- |
| Broad Screen Recording consent | CopyLasso starts the system selector only after a user command, derives only the completed rectangle, and asks ScreenCaptureKit for only those pixels. macOS consent still authorizes the process at the OS boundary. |
| Stale permission preflight | If the native selector exits without geometry, CopyLasso asks `SCShareableContent.current` to authoritatively verify access before classifying the result as Escape. The check captures no pixels and its shareable-content metadata is discarded immediately. |
| Selector subprocess misuse | Production invokes only `/usr/sbin/screencapture` with one fixed argument list, without a shell or caller-controlled value. Its standard streams and `/dev/null` image destination yield no screenshot data to CopyLasso; the actual selected pixels arrive only through the bounded ScreenCaptureKit service. |
| Passive selection tracking | While the native selector is active, CopyLasso samples only the current Core Graphics pointer position, left-button state, and Shift/Option/Space geometry-adjustment state. It intercepts no event, synthesizes no input, requests no Accessibility or Input Monitoring access, and discards all samples when selection ends. The tracker waits out a preexisting press, permits a real drag to replace a tiny confirmation click, and rejects adjusted geometry. An entire drag between samples can be missed or start at the first observed point; a dragged first-use confirmation followed by Escape can rarely remain a candidate. |
| Control-modified native selection | Shortcut routing waits for Shift, Option, and Control release before launch. macOS can redirect the native selector to its screenshot clipboard when Control is held, so CopyLasso polls and interrupts when it observes Control. Because input is not intercepted, exact Control at mouse-up can let macOS replace the clipboard before cancellation. CopyLasso never reads that value or forwards it to recognition. |
| Cross-display native selection | The system selector can display a rectangle spanning displays, while CopyLasso captures one display at a time. Half-open display bounds assign each shared edge to exactly one display; a release on a different known display cancels instead of silently cropping the visible rectangle. |
| Display changes during selection | The derived rectangle is clamped to the display where the drag began, then the existing ScreenCaptureKit request validator requires that display identity, complete global bounds including origin, scale, source bounds, and pixel dimensions still match before pixels can reach recognition. |
| Protected or DRM content | CopyLasso follows macOS capture restrictions and does not bypass protected pixels. Blank protected output may yield no text. |
| Misleading or hostile visible text | OCR output is untrusted plain text. CopyLasso copies it but never executes it, interprets markup, follows a link, or invokes a shell. Users must review text before using it as a command or credential. |
| Malicious or action-shaped code payload | Code output is untrusted inert plain text. CopyLasso never opens a URL, launches an application, joins a network, creates a contact or calendar item, invokes a shell, or otherwise interprets or acts on it. |
| Clipboard visibility | After a successful write, macOS and other clipboard-aware software control access. CopyLasso writes one plain-string representation and never reads prior contents. |
| Local history disclosure or corruption | History is off by default and receives only exact successful output after clipboard completion. AES-256-GCM authenticates every encrypted field with a bundle-scoped nonsynchronizing Keychain key. Missing keys, tampering, truncation, unknown versions, and write failures expose no entry and never overwrite unreadable bytes silently. Confirmed deletion cannot promise erasure from APFS snapshots or external backups. |
| Audio content leakage or playback failure | The sound service receives no pixels, recognized text, clipboard text, preview, geometry, or application identity. It plays one fixed bundled asset after a successful write; missing, muted, unavailable, or refused playback fails silently without delaying or failing capture. |
| Crash or forced termination during private processing | Operation values are memory-only and no in-app crash reporter receives them. Operating-system diagnostics or a privileged memory inspector remain outside the app's trust boundary. |
| Abnormal selector termination | Geometry observed before a signal is discarded. Only normal process exit can pass a completed rectangle to ScreenCaptureKit. |
| Diagnostic leakage | The only logger emits four fixed lifecycle messages. CI rejects interpolation and content-bearing logging APIs elsewhere. |
| Dependency compromise | KeyboardShortcuts and Sparkle are exact-version and exact-revision pinned, licensed, and covered by complete local notices. Sparkle is confined to one production adapter plus direct policy/session tests; canonical audits verify its framework, configuration, public key, installer entitlements, and absence of a second network stack. |
| Feed, hosting, DNS, or transport compromise | The compiled public key authenticates both the appcast and enclosure. Policy accepts one fixed feed, one exact version-matched GitHub asset shape, nonempty inline plain-text notes, canonical monotonic builds, and a 256 MiB cap. Transport cannot authorize installation. |
| Replay or downgrade | The installed build is the baseline and the highest authenticated build persists across deferral; lower candidates fail closed. Malformed persisted state also fails closed. |
| Oversized, truncated, or interrupted download | Expected and received bytes must match the signed length and remain within 256 MiB. Overflow, cancellation, timeout, disk failure, extraction failure, or installation failure cancels once, removes staging, and preserves the installed app. |
| Unwanted update | Automatic checks may be disabled. Automatic download and installation are disabled. The user must first choose Download and later choose Install and Relaunch; Later, Cancel, Escape, or closing the panel preserves the installed app. |
| Shortcut collision or spoofed event | The package validates and records the configured key combination; a narrow `RegisterEventHotKey` adapter delivers it without an event tap or additional permission, and every event enters the same busy-rejecting command. Recorder focus suspends delivery only while CopyLasso is active. A shortcut cannot bypass consent or selection. |
| Malformed OCR geometry or text | Pure formatting tests retain nonempty observations conservatively, reject invalid geometry safely, and output plain text only. |
| Malformed, unsupported, binary-only, or ambiguous code result | The adapter exposes only the five reviewed symbologies. Pure assembly rejects missing or empty strings and invalid geometry, removes exact duplicates, and preserves the clipboard when multiple unique payloads contain line breaks. |

## G52 Capture History Review

The reviewed history graph is `CaptureCommand` to the main-actor recorder to one
actor-isolated encrypted store. Clipboard output and sound happen first; storage
failure therefore cannot undo or suppress a successful copy and produces only
the bounded **Copied, History Not Saved** warning. All unsuccessful workflow
paths bypass the recorder, and history Copy writes directly to the clipboard
without recursive recording.

The archive includes content, type, timestamp, and random identifier only. Its
`CLH1` version header is AES-GCM authenticated additional data; all entry fields
are encrypted. Policy pruning uses an exact seven-day boundary, newest-first
100-entry cap, and 256 KiB UTF-8 ceiling on launch, read, write, and a next-expiry
timer. Atomic replacement uses `0600` permissions and backup exclusion. The
random 32-byte key uses Keychain service `<bundle>.capture-history`, account
`archive-key-v1`, synchronization disabled, and
`AfterFirstUnlockThisDeviceOnly` accessibility.

Closing History, session lock, and termination clear decrypted UI state. Turning
off nonempty or unreadable history and Clear All use destructive confirmation;
the former disables history while the latter rotates the key and leaves it on.
The focused audit confines AES/Keychain APIs and file persistence to the reviewed
adapter, rejects networking, logging, image types, and entitlement changes, and
retains the global screenshot-persistence prohibition.

## G38 Code Recognition Review

Unified code recognition adds no dependency, entitlement, permission, network route, persistence, file or camera input, logger, or automatic application action. `VNDetectBarcodesRequest` is confined to one adapter pinned to revision 3 and explicitly limited to QR, Code 128, Data Matrix, PDF417, and Aztec. The adapter runs off the main actor, supports cancellation through the same request boundary as text OCR, converts results to framework-neutral observations, and releases the captured image when the private operation unwinds. Text and code recognition consume the same in-memory image concurrently; an eligible code result takes precedence, and a selection without one falls back to OCR.

Complete payloads remain inside the private operation until the existing write-only clipboard call. The HUD receives only the established bounded preview. Nil, binary-only, empty, unsupported, partial, malformed, and no-code observations are ignored before OCR fallback. Ambiguous, no-content, cancellation, and complete-recognition-failure paths never call the clipboard or sound service. Permission recovery retries the one Capture request, and the shared coordinator rejects overlap.

## G39 Offline LaTeX Feasibility Review

G39 adds no production recognizer, model, runtime, dependency, resource,
entitlement, permission, network route, preference, clipboard branch, or UI.
The isolated benchmark scorer uses only Foundation and CryptoKit and never
links into the application target.

The study identified several risks that a future proposal must resolve before
the blind corpus is unsealed:

- source-code, checkpoint, tokenizer, and training-data licenses are separate
  trust decisions;
- pickle checkpoints are executable research inputs and cannot be shipping
  model data;
- ONNX external data, malformed graphs, Core ML compilation caches, and
  optional downloads require pinned lengths, digests, safe paths, and
  fail-closed loading;
- image dimensions, tensor allocation, token count, decoder iterations,
  cancellation, and disk use need hard bounds;
- package managers and preprocessing libraries can perform network version
  checks even when model inference is local; and
- output must remain inert clipboard text and must never be rendered, compiled,
  executed, opened, persisted, logged, or transmitted.

The compact Texo reference completed with networking denied, but its AGPL
license is incompatible and it returned nonempty output for every ordinary-text
negative. PP-FormulaNet-S exceeds the installed-size gate before its runtime is
included. LaTeX_OCR_rec's maintained runtime cannot initialize on arm64 and its
runtime alone exceeds the feature budget. MixTex fits as source model data, but
its Apache model metadata, linked AGPL reference source, and unreleased
training-data record do not establish compatible reproducible provenance; its
diagnostic reference run also emitted output for every negative. No candidate
reached the stage where Core ML conversion, a production sandbox, Developer ID
signing, or physical base-M1 and Intel qualification could establish a go
result.

[ADR-005](architecture/ADR-005-offline-latex-recognition.md) records the no-go.
All large artifacts and disposable runtime code remain outside Git and are not
part of the dependency inventory below.

## Dependency Inventory

| Dependency | Scope | Version and revision | Purpose | License | Upstream |
| --- | --- | --- | --- | --- | --- |
| KeyboardShortcuts | Shipping application and tests | 3.0.1, `49c3fc04ea827f816df67843bfcc57286b47ff06` | Global shortcut recording, validation, persistence, menu presentation, replacement, and clearing | MIT | <https://github.com/sindresorhus/KeyboardShortcuts> |
| Sparkle | Shipping application and tests | 2.9.5, `79bc9e872948e47877e76f194cb0c8e0412b0b90` | Signed appcast and enclosure verification, bounded download, staging, sandboxed installation, relaunch, and comparator behavior | Permissive Sparkle license bundle | <https://github.com/sparkle-project/Sparkle/blob/2.9.5/LICENSE> |

KeyboardShortcuts declares no transitive dependency. The Release executable contains its code statically. CopyLasso uses native permission-free hotkey registration for event delivery, while the package supplies the SwiftUI recorder, persistence, conflict validation, and menu presentation. Its exact license text and attribution are in [Third-Party Notices](../THIRD_PARTY_NOTICES.md). A July 22, 2026 GitHub Advisory Database query for KeyboardShortcuts 3.0.1 returned zero matching Swift advisories; this time-sensitive check must be repeated for each release.

Sparkle is a shipping binary framework. Historical public v0.2.1 contains the
affected 2.9.4 release; public v0.2.2 replaces it with 2.9.5. The current tag,
source revision, official artifact checksum, complete shipped
license bundle, About acknowledgement, fixed configuration, entitlement
boundary, and justification are recorded in [Third-Party
Notices](../THIRD_PARTY_NOTICES.md), [ADR-004](architecture/ADR-004-secure-updates.md),
and the secure-update audit. `SUEnableDownloaderService` is false; the bundled
downloader XPC is inert and receives no downloader-service Mach entitlement.
Release qualification repeats advisory, framework-signature, nested-code,
architecture, and notarization checks.

`CopyLassoSuccess.wav` is original project-authored audio generated deterministically by the tracked synthesis script from seeded texture and analytic partials. It contains no third-party recording, dependency, content, or metadata; its construction, fixed digest, cross-architecture reproduction, and provenance are recorded in [Brand Assets](brand-assets.md).

The July 22, 2026 advisory check for Sparkle 2.9.4 was time-bounded and became
stale. A refreshed August 9, 2026 GitHub advisory readback identified public
medium-severity `GHSA-gmj2-gq3j-vqmj`, affecting versions through 2.9.4.
CopyLasso's historical public v0.2.1 feed contains no delta item and every tracked appcast
generator uses `--maximum-deltas 0`, materially limiting reachability, but the
affected code remained shipped there. G50 therefore pins upstream security-fix
release 2.9.5 at commit `79bc9e872948e47877e76f194cb0c8e0412b0b90`
and published it unchanged as v0.2.2 instead of accepting residual risk. A
same-day refreshed upstream release and
advisory check found KeyboardShortcuts 3.0.1 unchanged and no published
repository security advisory for that dependency. These are dated results and
must be repeated before every updater-enabled release.

## Reproducible Verification

Run the tracked source audit:

```sh
./scripts/audit-privacy-security.sh
./scripts/audit-success-sound.sh
./scripts/audit-code-recognition.sh
./scripts/audit-latex-feasibility.sh
```

The canonical CI entrypoint runs each audit exactly once. They validate the exact three-key entitlement contract, both build-configuration references, updater-only networking, absence of content-persistence APIs, logger confinement, tracked-secret and local-path scans, exact dependency scope, shipping notices, absence of tracked prebuilt dependency binaries, deterministic original audio and code-fixture bytes, Vision barcode confinement and configuration, inert payload handling, one bundled sound asset, content-free service wiring, the LaTeX no-go production boundary, and no microphone, camera, file-import, system-audio-capture, notification, or alternate playback API.

G54 adds no entitlement, dependency, network destination, capture command, or
content flow. Its v0.3 qualification audit binds `0.3.0 (6)` to the reviewed
multilingual-preference and encrypted-history boundaries, keeps public 0.2.2
evidence immutable through pinned historical metadata, and rejects publication
or final-tag operations in candidate tooling. Release qualification repeats the
Sparkle advisory check and all nested Developer ID, notarization, Gatekeeper,
authenticated-update, ciphertext, Keychain-scope, and content-egress checks.

The complete application unit bundle also passes when invoked directly under a process sandbox with `(deny network*)`. This exercises real Vision fixtures plus permission, selection, capture planning, formatting, clipboard, feedback, lifecycle, Settings, and end-to-end orchestration tests without disabling the workstation's network connection; the canonical verification record reports the exact current suite count.

The signed manual privacy matrix in [Testing](testing.md) remains the release boundary for fresh real captures, container/temp-directory deltas, unified-log inspection, clipboard paste verification, and OS privacy-pane inspection. Static and injected tests are not substitutes for those observations.
