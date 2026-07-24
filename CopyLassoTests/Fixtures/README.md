# OCR Fixture Provenance

These fixtures were created specifically for CopyLasso. No screenshot, photograph, text, logo, or other asset was copied from a third-party product or website. To the extent copyright subsists in these fixtures, they are contributed under the repository's MIT License.

| Fixture | Dimensions | Expected text | Source |
| --- | ---: | --- | --- |
| `clean-multiline.png` | 1200 × 500 | `Read every visible line` / `Keep the original order` / `Process all text offline` | Deterministically rendered by `scripts/generate-ocr-fixtures.swift` using AppKit system text. |
| `small-text.png` | 1200 × 320 | `Small screen text should remain readable` | Deterministically rendered by the project fixture generator using 18-point AppKit system text. |
| `light-on-dark.png` | 1200 × 360 | `LIGHT TEXT ON DARK BACKGROUND` | Deterministically rendered by the project fixture generator. |
| `moderate-low-contrast.png` | 1200 × 360 | `Moderate contrast should preserve these words` | Deterministically rendered by the project fixture generator with moderate foreground/background contrast. |
| `rasterized-application-text.png` | 1200 × 600 | `CopyLasso Settings` / `Capture text from any screen` / `Recognition stays on this Mac` / `Save Changes` | Rasterized from project-created native AppKit controls by the project fixture generator. |
| `photo-cedar-trail.png` | 1536 × 1024 | `CEDAR TRAIL` | Generated specifically for CopyLasso on July 9, 2026 with OpenAI's built-in image-generation tool; no source image was used. |
| `code-qr.png` | 640 × 640 | `https://copylasso.com/g38?mode=qr` | Deterministically rendered by `scripts/generate-code-fixtures.swift` using Apple's Core Image QR generator. |
| `code-code128.png` | 900 × 360 | `COPYLASSO-CODE128` | Deterministically rendered by the project fixture generator using Apple's Core Image Code 128 generator. |
| `code-data-matrix.png` | 640 × 640 | `DM` | Deterministically rendered through Core Image from the project fixture generator's scoped ECC 200 encoder and standard 10 × 10 module construction. |
| `code-pdf417.png` | 640 × 640 | `COPYLASSO PDF417` | Deterministically rendered by the project fixture generator using Apple's Core Image PDF417 generator. |
| `code-aztec.png` | 640 × 640 | `COPYLASSO AZTEC` | Deterministically rendered by the project fixture generator using Apple's Core Image Aztec generator. |

## Photographic Fixture Prompt

The photographic fixture used the `photorealistic-natural` workflow with this material specification:

> Create a realistic landscape photograph of a modest public trail entrance with one weathered green metal sign beside a natural wooded path. Use neutral overcast daylight and a slight natural perspective. The sign must contain the exact, one-line, bold uppercase text "CEDAR TRAIL" and no other readable text. Include no people, vehicles, logos, brands, watermarks, addresses, maps, UI, or identifiable location.
