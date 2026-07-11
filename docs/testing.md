# Testing CopyLasso

CopyLasso's canonical unsigned build and unit-test pipeline is:

```sh
./scripts/ci.sh
```

The pipeline lints all Swift source, resolves the exact package dependency, builds Debug and both XCTest bundles, runs the unit suite serially with timeouts, inspects required build and privacy boundaries, builds Universal 2 Release, and verifies both executable slices. It does not launch the unsigned UI-test runner or alter macOS privacy state.

## Controlled Permission UI Coverage

Signed UI tests use Debug-only permission doubles. They cover prior-request and previously-granted recovery wording, singleton reuse, System Settings failure instructions, retry routing, Cancel, menu availability, keyboard actions, and accessibility identifiers without calling Core Graphics permission functions or changing real TCC state.

The controlled launch arguments begin with `--g12-` and are compiled out of Release. CI inspects the Release executable to prevent them from leaking. The application uses the real production permission service unless the existing `--g10-g11-ui-testing` test boundary is also present.

Run the signed UI suite through Xcode with the shared `CopyLasso` scheme and **My Mac**, or use a locally signed `xcodebuild test` invocation. Keep the development team only in ignored `Local.xcconfig`; never paste signing identity details into logs or documentation.

## Real Screen Recording Permission Matrix

Use one stably Apple Development-signed Debug application for the entire matrix. Changing its signing requirement or bundle identifier can create a different macOS privacy identity and invalidate the result.

First clear CopyLasso-owned development state from **Settings > Reset Local Development State…**, quit CopyLasso, and then reset only the Debug bundle's Screen Recording decision:

```sh
/usr/bin/tccutil reset ScreenCapture io.github.bennetthilberg.copylasso.debug
```

This command changes macOS privacy state and must never run automatically in tests or CI.

Verify in this order:

1. Launch CopyLasso normally. Confirm there is no Screen Recording prompt or recovery panel before a user command.
2. With another application frontmost, invoke **Capture Text**, choose **Deny** in the macOS dialog, and confirm one CopyLasso recovery panel appears. Selection must not begin, and the clipboard must remain unchanged.
3. Invoke Capture Text again from both the menu and shortcut. Confirm macOS does not stack request dialogs, CopyLasso reuses one recovery panel, and each attempt returns the coordinator to idle.
4. Choose **Open System Settings**. Confirm the Screen & System Audio Recording pane opens. Enable CopyLasso and follow the actual macOS **Quit & Reopen** prompt if one appears; otherwise return to CopyLasso and explicitly choose **Try Again**. CopyLasso must not retry automatically. If **Later** was chosen and access is still unavailable, **Try Again** reports that CopyLasso must be quit and reopened rather than appearing inert.
5. After any required relaunch, invoke Capture Text. Confirm authorization reaches the temporary G13 selection boundary and returns to idle without an overlay, captured pixels, OCR, clipboard mutation, or feedback.
6. Disable CopyLasso in Screen & System Audio Recording and relaunch it. Invoke Capture Text and confirm the recovery copy says access was previously available and may have been turned off; it must not claim definitive revocation.
7. Repeat recovery while an ordinary full-screen application is frontmost. Confirm presenting or updating CopyLasso's nonactivating panel does not change the frontmost application. Only **Open System Settings** intentionally changes focus.
8. Confirm macOS did not show the ScreenCaptureKit private-window-picker-bypass warning and that no Accessibility, Input Monitoring, Microphone, or clipboard access was introduced.

Core Graphics preflight may remain positive inside a process after permission is disabled. G12 records revocation only once preflight reflects it, normally after relaunch. G14 must treat an actual ScreenCaptureKit capture denial as authoritative when preflight is stale.

### G12 Verified Result

The production matrix passed July 10, 2026 on macOS 26.5.1 (`25F80`) with Xcode 26.6 (`17F113`) and one stably Apple Development-signed Debug identity:

- Ordinary launch caused no Screen Recording prompt or recovery panel.
- The first shortcut request displayed only the macOS Screen Recording dialog. Choosing **Deny** produced one CopyLasso recovery panel after the system response.
- Three subsequent shortcut attempts reused that panel and produced no additional system dialog.
- **Open System Settings** opened Screen & System Audio Recording directly. Choosing **Later** after enabling access caused no automatic retry; the explicit retry guidance correctly required a relaunch.
- The designated signing requirement matched across clean build locations. After relaunch, three authorized shortcut requests reached the temporary selection boundary and returned with no overlay, pixels, OCR, clipboard change, or visible feedback.
- After revocation and relaunch, CopyLasso used the cautious previously-observed-access wording. The panel and its retry update appeared over a full-screen TextEdit Space while Launch Services still reported that CopyLasso was not frontmost.
- No ScreenCaptureKit private-window-picker warning, Accessibility, Input Monitoring, Microphone, capture, OCR, or pasteboard behavior occurred.

During the revocation check, macOS initially relaunched a retired scaffold from Xcode's default DerivedData because that duplicate bundle remained registered with Launch Services. Its normal window and missing `LSUIElement` identified it as stale, while the current G12 build was verified dockless and free of the retired placeholder. Unregistering only the stale generated build and registering the current signed bundle restored the intended test. Keep one Debug copy registered when validating **Quit & Reopen** so Launch Services cannot choose an obsolete duplicate with the same bundle identifier.

## Expected Permission Observations

| Direct observation and local history | CopyLasso observation |
| --- | --- |
| Preflight granted | Granted; record previously observed access |
| Not granted; never requested in this preferences history | Not granted; first user command may request access |
| Not granted; a request was recorded | Not granted after a prior request; macOS does not expose denied versus pending |
| Not granted; access was previously observed | Not granted after previously observed access; access may have been turned off |

Permission history contains only the two booleans needed for these neutral labels. It contains no pixels, recognized text, raw platform error, or definitive copy of macOS authorization state.
