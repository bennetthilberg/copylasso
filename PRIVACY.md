# Privacy

CopyLasso 0.3 processes captures on your Mac. It has no accounts, analytics,
telemetry, advertising, cloud OCR, or content-upload service.

## Screen capture and recognition

CopyLasso captures only the region you select. Apple ScreenCaptureKit provides
the pixels in memory, and Apple Vision recognizes text and supported codes on
your Mac.

CopyLasso does not save, log, or upload screenshots. Recognition results remain
in memory unless you copy them or enable capture history. QR and barcode
payloads are treated as plain text; CopyLasso does not open or run them.

Screen Recording is the only macOS privacy permission required for capture.
CopyLasso does not require Accessibility, Input Monitoring, microphone, camera,
location, or contacts access.

## Clipboard

A successful capture writes one plain-text value to the system clipboard.
CopyLasso does not read the existing clipboard. Cancelling a capture or finding
no content leaves it unchanged.

## Capture history

Capture history is optional and off by default. When you enable it, CopyLasso
stores successful text and code results in an encrypted archive on your Mac.
It keeps up to 100 entries for seven days and rejects entries larger than
256 KiB.

The archive uses AES-256-GCM encryption. Its key is stored separately in a
CopyLasso-scoped, device-only Keychain item that does not sync. History never
contains screenshots, source-app names, screen coordinates, or previous
clipboard contents.

You can copy or delete individual entries, clear the archive, or disable
history in the app.

## Network use

The updater is CopyLasso's only network feature. It checks a fixed,
authenticated feed and downloads approved releases from GitHub only after you
choose to do so. You can disable automatic checks in Settings.

As with any web request, the feed host and GitHub can receive ordinary network
metadata such as your IP address, request time, and user agent. Update requests
do not include screenshots, recognized content, clipboard data, OCR language
choices, analytics identifiers, or a hardware profile.

For security reporting, see [Security](SECURITY.md).
