# ADR-001: Vision OCR Is Viable for v0.1

- **Status:** Accepted
- **Date:** July 9, 2026
- **Scope:** G05 feasibility spike; production integration remains deferred to G15

## Context

CopyLasso needs local, private OCR for approximately horizontal English text captured from the screen. Before building capture and selection infrastructure, G05 must show that Apple's Vision framework can meet explicit quality thresholds, run without a network connection, and leave enough time inside the one-second end-to-end target.

The application supports macOS 14. The newer Swift Vision text-recognition API requires a later deployment target, so the experiment uses `VNRecognizeTextRequest` revision 3, which is available across CopyLasso's supported systems.

## Decision

Vision is viable for CopyLasso v0.1. The experimental adapter:

- accepts only an in-memory `CGImage` and its orientation;
- performs `.accurate` recognition using revision 3;
- fixes the recognition language to `en-US` and disables automatic language detection;
- enables language correction;
- performs recognition away from the main actor at user-initiated priority; and
- returns only recognized text, confidence, and normalized bounding boxes.

The adapter does not write images or recognized text to disk, log recognized content, or make network requests. This narrow implementation is evidence for the production service planned in G15, not a public product API.

## Evidence

Six project-owned fixtures cover clean multiline text, small text, light text on a dark background, moderate low contrast, rasterized native application text, and text inside a generated photograph. Their exact sources, expected text, and licensing are recorded beside the fixtures.

On macOS 26.5.1 (build 25F80), Xcode 26.6, and an Apple M5 Pro:

- all four deterministic clean fixtures matched their exact normalized expected text;
- the moderate-low-contrast fixture exceeded 90% character similarity, contained every expected token, and stayed within the one-unexpected-token limit;
- the photographic fixture contained the exact phrase `CEDAR TRAIL`, contained every expected token, and stayed within the one-unexpected-token limit;
- blank-image, orientation, supported-language, bounding-box, confidence, and error-propagation tests passed;
- language correction and no correction each passed 6 of 6 fixtures, so correction remains enabled; and
- two repeated benchmarks, each using two warmups followed by 11 recognitions of the 1200 × 500 clean fixture, produced medians of 48.3 ms and 48.5 ms. The latest run ranged from 47.7 ms to 49.2 ms, well below the 500 ms G05 limit.

The same quality suite passes for both arm64 and x86_64 through the canonical CI entrypoint. The five deterministic fixtures also regenerate byte-for-byte identically. A direct run of the already-built XCTest bundle under a process sandbox with all network operations denied passed all seven substantive OCR checks; only the two intentionally opt-in benchmark and language-comparison methods skipped. This proves offline execution without changing the workstation's Wi-Fi state.

## Quality Contract

Deterministic clean fixtures require exact normalized text. The low-contrast fixture requires at least 90% character similarity, every expected token, and at most one unexpected token. The photograph requires its exact phrase, every expected token, and at most one unexpected token. Nonempty output alone is never sufficient.

Test failure messages identify fixtures and metrics without printing recognized content. The workstation-only comparison and benchmark are activated with explicit Swift compilation conditions; ordinary CI skips them while continuing to run every quality assertion.

## Limitations

- The evidence covers approximately horizontal English text, not handwriting, arbitrary rotation, or other languages.
- The test normalization establishes reading order for simple single-column fixtures only. It does not promise formatting preservation or correct ordering for complex layouts.
- Recognition quality still depends on resolution, contrast, source appearance, and the Vision implementation shipped with the operating system.
- Revision 3 is intentionally pinned for macOS 14 compatibility. A later production goal should re-evaluate newer APIs only if the minimum system requirement changes.
- This experiment does not implement screen capture, region selection, clipboard output, feedback, or any user-facing OCR flow.

## Consequences

G06 may proceed with screen-capture feasibility after G05 is merged. G15 should turn this evidence into the production OCR service while preserving the in-memory, local-only boundary and the explicit fixture thresholds.
