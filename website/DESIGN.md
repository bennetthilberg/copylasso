# CopyLasso website design system

## Discovery

- Artifact: static product landing page and temporary design lab.
- Audience: Mac users who need text from pixels, plus privacy-conscious open-source users.
- Primary outcome: understand the capture workflow and choose the v0.3.0 download.
- Secondary outcome: inspect the source on GitHub.
- Positioning: technical, independent, calm, and useful.
- Brand adjectives: clear, quiet, precise, human.
- Aesthetic essence: a clean page with one blue gesture.
- Single-minded proposition: select visible text, copy clean text, keep the capture on your Mac.

## Shared design commitments

- Astro static output with no hydrated framework, external font, image request, analytics, or third-party script.
- System sans typography only. `Avenir Next` and `Helvetica Neue` lead the stack on macOS; the fallback remains sans-serif.
- Blue is the only chromatic family. No purple/indigo gradients, sepia tones, glass, or decorative glow.
- Layouts stay minimal but use one intentional compositional gesture per direction: a paper window, proof strip, margin note, line, clipboard, desktop, still frame, split screen, or one-gesture stage.
- No eyebrow text, pointless dot/pill indicators, or cards with accent left borders.
- No monospace type anywhere. Do not use tiny utility labels as decoration; if information matters, give it normal reading size and a sensible place in the page.
- Headings use a light or regular weight, with deliberate line breaks and generous whitespace. The page is always a light theme.
- Real page text remains in semantic HTML. Decorative motion is CSS-only, causally tied to selection and clipboard output, and has a reduced-motion state.
- Primary action: `Download CopyLasso 0.3.0` with a real download icon. Do not repeat the version elsewhere in the page.
- The only supporting hero metadata is `macOS 14+ · Apple silicon + Intel`.
- Secondary action: `View source on GitHub`.

## Content contract

- Hero: copy text from anywhere on the Mac's capturable screen.
- How it works: press `⇧⌘2`, select a region, and receive plain text on the clipboard.
- Features: on-device Apple Vision OCR, supported QR/barcode recognition, language selection, optional encrypted history, menu-bar operation, and configurable shortcut.
- Privacy: screenshots are never retained; capture and recognition stay local; no account, cloud OCR, analytics, or telemetry; history is optional and encrypted locally.
- Compatibility: macOS 14 or newer, Apple silicon or Intel, Screen Recording permission for region capture.
- Footer: Created by Bennett Hilberg; `me@bennetthilberg.com`; MIT source link.

## Ten directions

1. **Paper Window** — a quiet split layout turns a believable spreadsheet capture into a clean clipboard result.
2. **Proof Strip** — a wide single hero is followed by three visual proof moments for language, QR, and code recognition.
3. **Margin Note** — a reading-first column leaves room for a blue selection note and a visible before/after.
4. **Blue Line** — one thin blue route carries the eye from screen pixels through OCR to copied text.
5. **Clipboard First** — the result is the hero; a source image and selection box sit behind it as context.
6. **Window Within** — a restrained macOS-like surface makes the crosshair-and-copy sequence immediately legible.
7. **Still Frame** — a street-sign-like still image becomes a tactile OCR demonstration without needing a remote asset.
8. **Split Screen** — `what you see` and `what you get` stay side by side, with language and QR examples in the proof row.
9. **Quiet Catalog** — a sparse editorial page uses large visual samples instead of feature-card copy.
10. **One Gesture** — the smallest direction: one oversized hero action, one animated selection, and only the essential proof below.

## Token table

| Role | Token |
| --- | --- |
| Display and body type | `Avenir Next`, `Helvetica Neue`, `-apple-system`, `BlinkMacSystemFont`, sans-serif |
| Utility type | Same system sans stack; no monospace type |
| Type ratio | 1.25, base 16px |
| Spacing unit | 4px; section spacing uses 16/24/40/64/96px relationships |
| Radii | 8px for controls; 14px for product surfaces |
| Edge approach | crisp borders; no border plus diffuse shadow on one element |
| Background | cool near-white surfaces only |
| Foreground | deep blue-black |
| Muted | desaturated blue-gray |
| Accent | clear medium blue |
| Accent foreground | cool white |
| Success | dark green with text label when used |
| Focus | high-contrast blue outline |

## Signature move

Every option uses one restrained blue lasso/selection gesture to make the invisible act of selecting pixels visible. It never replaces text, controls, or accessible state.

## Verification status

The ten-route redesign builds as 12 static Astro pages (overview, index, and ten options). The ten option routes all use the exact hero heading `Copy anything on your screen.`, light system-sans typography, a real download icon, a selection-to-clipboard animation, and no visible duplicate version label. Browser checks at the default 1280px viewport and an explicit 390px viewport found one `h1`, no horizontal overflow, the required CTA/source/compatibility content, and visual proof for QR, language, code, or clipboard behavior on every route. All ten routes include reduced-motion CSS fallbacks. Representative desktop renders were reviewed for Paper Window, Clipboard First, Still Frame, and One Gesture; the overview is left open in the local dev server for comparison.
