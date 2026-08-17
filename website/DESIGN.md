# CopyLasso website design system

## Discovery

- Artifact: static product landing page and temporary design lab.
- Audience: Mac users who need text from pixels, plus privacy-conscious open-source users.
- Primary outcome: understand the capture workflow and choose the v0.3.0 download.
- Secondary outcome: inspect the source on GitHub.
- Positioning: technical, independent, calm, and useful.
- Brand adjectives: precise, local, direct, quietly playful.
- Aesthetic essence: quiet utility with a blue gesture.
- Single-minded proposition: select visible text, copy clean text, keep the capture on your Mac.

## Shared design commitments

- Astro static output with no hydrated framework, external font, image request, analytics, or third-party script.
- System sans typography only. `Avenir Next` and `Helvetica Neue` lead the stack on macOS; the fallback remains sans-serif.
- Blue is the only chromatic family. No purple/indigo gradients, sepia tones, glass, or decorative glow.
- Layouts stay minimal but use one intentional compositional gesture per direction: a seam, rail, canvas, receipt, console, or before/after sheet.
- No eyebrow text, pointless dot/pill indicators, or cards with accent left borders.
- Real page text remains in semantic HTML. Decorative motion is CSS-only, causally tied to selection and clipboard output, and has a reduced-motion state.
- Primary action: `Download CopyLasso 0.3.0` with version and `macOS 14+ · Apple silicon + Intel` beside it.
- Secondary action: `View source on GitHub`.

## Content contract

- Hero: copy text from anywhere on the Mac's capturable screen.
- How it works: press `⇧⌘2`, select a region, and receive plain text on the clipboard.
- Features: on-device Apple Vision OCR, supported QR/barcode recognition, language selection, optional encrypted history, menu-bar operation, and configurable shortcut.
- Privacy: screenshots are never retained; capture and recognition stay local; no account, cloud OCR, analytics, or telemetry; history is optional and encrypted locally.
- Compatibility: macOS 14 or newer, Apple silicon or Intel, Screen Recording permission for region capture.
- Footer: Created by Bennett Hilberg; `me@bennetthilberg.com`; MIT source link.

## Six directions

1. **Crosshair Stage** — asymmetric hero split; a blue lasso crosses the seam and becomes the selection boundary.
2. **Three-Beat Rail** — the page follows Select, Recognize, Copy along one continuous vertical stroke.
3. **Desktop Canvas** — a full-width blue plane frames a restrained screen-selection surface.
4. **Privacy Receipt** — factual privacy rows and a blue receipt spine make boundaries the proof.
5. **Shortcut Console** — the shortcut and capture states form a compact Mac utility console.
6. **Copy Sheet** — a quiet before/after reading surface shows visible text becoming clipboard text.

## Token table

| Role | Token |
| --- | --- |
| Display and body type | `Avenir Next`, `Helvetica Neue`, `-apple-system`, `BlinkMacSystemFont`, sans-serif |
| Utility type | `SF Mono`, `Menlo`, monospace |
| Type ratio | 1.25, base 16px |
| Spacing unit | 4px; section spacing uses 16/24/40/64/96px relationships |
| Radii | 8px for controls; 14px for product surfaces |
| Edge approach | crisp borders; no border plus diffuse shadow on one element |
| Background | cool near-white and blue-tinted dark surfaces |
| Foreground | deep blue-black |
| Muted | desaturated blue-gray |
| Accent | clear medium blue |
| Accent foreground | cool white |
| Success | dark green with text label when used |
| Focus | high-contrast blue outline |

## Signature move

Every option uses one restrained blue lasso/selection gesture to make the invisible act of selecting pixels visible. It never replaces text, controls, or accessible state.

## Verification status

The slop and accessibility audit is complete after the six routes were integrated and rendered at 1440px desktop and 390px narrow widths. All six routes build as static Astro pages, report no horizontal overflow, and have one primary heading. Reduced-motion checks report no active animations on options 1 and 5. The post-load axe audit reports zero violations on all six routes; its remaining incomplete checks are limited to the fixed design-lab navigator overlapping full-page captures and decorative/pseudo-element contrast heuristics.
