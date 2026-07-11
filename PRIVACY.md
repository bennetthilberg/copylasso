# CopyLasso Privacy

**Status:** Approved privacy contract for the pre-release v0.1 application.

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

The application stores only ordinary preferences needed for versioned onboarding, shortcut configuration, permission-history presentation, and settings behavior. Its permission history records only whether CopyLasso has requested Screen Recording access and whether access was previously observed; it does not store screen content or a definitive macOS authorization status. Launch at Login state is read from macOS rather than copied into a preference that could become stale. These values never contain captured images or recognized text.

## macOS Permissions

CopyLasso needs macOS Screen Recording permission to capture the selected pixels. It performs no permission check or request merely by launching. A user-initiated Capture Text command checks access and requests it only when the current CopyLasso preference history has never requested it. When access remains unavailable, a nonactivating recovery panel explains the manual System Settings path without claiming macOS can distinguish denial from pending approval or definitively identify revocation.

Core Graphics preflight can remain stale inside a running process after access changes. G12 detects revocation once preflight reflects it, typically after relaunch. A future real capture denial will be authoritative even if preflight still reports access. No screen pixels are captured by the current production workflow.

The v0.1 core workflow does not require Accessibility or Input Monitoring permission. macOS may prevent protected or DRM-restricted content from being captured, and CopyLasso does not attempt to bypass those protections.

## Network Activity

Core functionality does not require network access, and v0.1 contains no automatic updater. Users obtain releases manually from GitHub. Any network activity involved in visiting GitHub or downloading a release occurs outside the CopyLasso core OCR workflow.

The detailed, release-blocking privacy requirements are part of the public [v0.1 product contract](docs/v0.1-product-contract.md).
