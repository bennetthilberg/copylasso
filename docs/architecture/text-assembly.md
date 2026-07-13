# Plain-Text Assembly

CopyLasso converts Vision results into `RecognizedTextObservation` values before layout work begins. `TextAssembler` consumes only those neutral text, confidence, and normalized-bounds values; it does not import Vision, AppKit, SwiftUI, ScreenCaptureKit, or a pasteboard API.

## Deterministic Rules

1. Collapse leading, trailing, and internal whitespace in each observation to single spaces. Ignore observations that contain no non-whitespace text.
2. Deduplicate only observations whose normalized text and four exact bounding-box components are identical. When their confidence differs, retain the higher-confidence copy.
3. Preserve every other nonempty observation, including low-confidence text. Assembly does not silently decide that uncertain recognized content is noise.
4. Treat boxes with at least 35% vertical overlap as candidates for the same line. Sort items within each line from left to right and lines from top to bottom.
5. Use one line break between ordinary neighboring lines. Use two when the vertical gap exceeds 1.5 times the larger neighboring line height.
6. Preserve text with nonfinite, zero, or negative geometry in a deterministic fallback section after positioned text rather than crashing or dropping it.

These rules produce a Swift `String` containing plain characters and line breaks only. They do not interpret Markdown, HTML, or rich-text syntax.

## Intentional Limitations

The v0.1 contract is ordinary, approximately horizontal, single-column English text. The assembler does not reconstruct tables, columns, indentation, font styling, lists, vertical writing, rotated text, or page structure. Horizontally aligned columns are processed row by row and may interleave. Complex input still has stable output for the same observations, never invents content, and never emits a retained observation more than once.

G16 stops after producing the transient string. G17 owns clipboard output and user feedback; until then the string is discarded without touching the general pasteboard.
