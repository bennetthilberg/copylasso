# CopyLasso Privacy

**Status:** Approved privacy contract for CopyLasso 0.1.x and the updater and configurable success sound present in source for the planned v0.2 release.

CopyLasso is designed as a local-first macOS utility. Its core job is to capture a user-selected screen region, recognize visible text, and place the result on the clipboard without uploading or retaining the captured content.

## Local Processing

- Screen capture uses Apple's ScreenCaptureKit framework.
- OCR uses Apple's Vision framework on the Mac.
- Captured images and recognized text remain in memory only for the active operation and are released as soon as they are no longer needed.
- Core capture and OCR work without a network connection.

## Data Not Collected or Retained

CopyLasso v0.1 has no:

- screenshot, OCR, or clipboard history;
- cloud OCR or content upload;
- accounts or synchronization;
- analytics or telemetry; or
- logging of screenshots, recognized text, clipboard text, or copied-text previews.

The application stores only ordinary preferences needed for versioned onboarding, shortcut configuration, permission-history presentation, settings behavior, the success-sound choice, and secure-update control. The sound preference contains one schema version and one Boolean enabled state. Update state is limited to the automatic-check schedule and preference, a deferred build, and the highest authenticated build used to reject replay or downgrade. It never stores appcast bodies or release notes. Permission history records only whether CopyLasso has requested Screen Recording access and whether access was previously observed; it does not store screen content or a definitive macOS authorization status. Launch at Login state is read from macOS rather than copied into a preference that could become stale. These values never contain captured images or recognized text.

CopyLasso emits only four fixed lifecycle diagnostic messages: interruption while idle, cancellation for sleep/lock, resume, and application termination cleanup. Those messages contain no captured or frontmost application name, display geometry, pixels, recognized text, clipboard text, preview, raw error, or user-supplied value. Capture results and failures are never interpolated into diagnostics.

## macOS Permissions

CopyLasso needs macOS Screen Recording permission to capture the selected pixels. It performs no permission check or request merely by launching. A user-initiated Capture Text command checks access and requests it only when the current CopyLasso preference history has never requested it. When access remains unavailable, a nonactivating recovery panel explains the manual System Settings path without claiming macOS can distinguish denial from pending approval or definitively identify revocation.

After approval, CopyLasso creates temporary transparent AppKit panels so the user can select a rectangle. The panels retain only display metadata and in-memory geometry for the active selection. The result carries the initiating display identifier, point size, scale, and local rectangle so capture can reject a changed display rather than risk reading the wrong pixels. These values contain no captured content. Panels are ordered out and released before the next workflow stage, and the selected rectangle is not persisted or logged.

Core Graphics preflight can remain stale inside a running process after access changes. CopyLasso therefore treats an actual ScreenCaptureKit denial as authoritative and returns to permission recovery even if preflight had just reported access.

After the overlay is absent, the production capture service obtains one `CGImage` for the selected display-local rectangle. It disables cursor and audio capture, does not encode the image, and does not create a file-system intermediate. The production Vision service consumes that image locally at user-initiated priority, returns only neutral text, confidence, and normalized bounds, and releases the image on completion or cancellation. A pure formatter turns those transient observations into a plain `String` without logging or persisting it.

For a successful nonempty result, CopyLasso replaces the general pasteboard with a single plain-string representation. It never reads or snapshots the prior general-pasteboard contents: current macOS versions can ask for separate permission when an app reads them, and CopyLasso does not require that access. Cancellation, no text, permission failure, capture failure, recognition failure, and formatting failure never call the clipboard service, so those paths leave the existing clipboard untouched. AppKit requires a destructive clear before its fallible replacement write. If that clear succeeds but the write is rejected, CopyLasso reports a clipboard-stage failure, but the prior contents may already be lost. Avoiding a recurring clipboard-read alert and transient retention of arbitrary prior clipboard data is the explicit privacy-first v0.1 tradeoff.

Success, no-text, and stage-specific failure results use one nonactivating HUD. In current v0.2 source, a separate configurable service may play one bundled original sound only after a nonempty clipboard write succeeds. Success sound playback receives no captured pixels, recognized content, or clipboard text. Disabled output, system mute, a missing output device, a missing asset, or playback failure is silent and does not change clipboard or HUD success. One private operation scope owns the captured image, complete recognized observations, and unbounded assembled string. It returns only a no-text result or an at-most-80-character success preview after any clipboard write, so those larger values leave scope before the HUD presentation delay. Cancellation presents no HUD and never calls the clipboard or sound service. The bounded preview exists only in the HUD model for its 2.5-second presentation, then is cleared. Captured pixels, complete recognized observations, the unbounded assembled string, and HUD previews never enter preferences, logs, caches, history, analytics, or telemetry.

The v0.1 core workflow does not require Accessibility or Input Monitoring permission. The configurable success sound uses output playback only and requests neither microphone nor notification permission. macOS may prevent protected or DRM-restricted content from being captured, and CopyLasso does not attempt to bypass those protections.

## Network Activity

Core capture, OCR, clipboard output, Settings, onboarding, and Launch at Login do not require network access. Current source gives the sandboxed application outbound client access only for the user-controlled secure updater; it has no inbound server entitlement. Starting CopyLasso or performing a capture does not trigger update content in the capture pipeline, and an updater startup or network failure leaves capture fully usable.

Automatic checks default on, run no more often than every 24 hours, and can be disabled in Settings. A user can also choose **Check for Updates…**. Sparkle retrieves one fixed signed feed at `https://updates.copylasso.com/appcast.xml`; accepted enclosures must be the exact version-matched CopyLasso DMG URL on GitHub Releases. CopyLasso disables system profiling, cookies, custom headers, query parameters, external release-note downloads, automatic downloads, and automatic installation. Release notes are authenticated inline plain text. The feed and package are authenticated with the public key compiled into the app, and installation requires two explicit user decisions: one before download and one before quit, install, and relaunch.

Update transport can expose ordinary connection metadata such as the user's IP address and request time to the feed host and GitHub. Sparkle's ordinary user agent identifies the CopyLasso version and Sparkle version. Update requests send no screen pixels, selected rectangle, recognized text, clipboard data, HUD preview, frontmost-application identity, hardware profile, stable user or device identifier, analytics event, or telemetry. CopyLasso does not retain feed bodies or release notes after the active update transaction. Settings links still ask macOS to open the default browser rather than fetching those pages in CopyLasso.

The public CopyLasso 0.1.x line still updates manually. Users must manually install the first updater-enabled release before authenticated checks can begin; G36 does not publish a feed or a release.

The detailed, release-blocking privacy requirements are part of the public [v0.1 product contract](docs/v0.1-product-contract.md). The implementation data flow, entitlements, dependency inventory, trust boundaries, and misuse cases are reconciled in the [security and privacy review](docs/security-and-privacy-review.md).
