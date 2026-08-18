# CopyLasso website design system

## Context

- Artifact type: technical product landing page.
- Audience: Mac users who need text from pixels, including privacy-conscious open-source users.
- Primary action: download CopyLasso 0.3.0. Secondary action: inspect the source on GitHub.
- Adjectives: clear, quiet, precise, human.
- Visual translations: clear means one dominant headline and one primary action; quiet means cool near-whites and crisp edges; precise means a literal selection animation; human means direct copy and a street-corner example.
- Aesthetic essence: calm, useful, assured.
- Single-minded proposition: select anything visible and get clean clipboard text.
- References: the before-and-after clarity of design option 8, the three-step rhythm of options 5 and 6, and the visual feature specimens and quiet close of option 10.
- Mode: light only. Density: airy with compact proof regions.
- Constraints: static Astro output, no hydration, no external fonts, no remote assets, no analytics, no third-party scripts, no serif or monospace type.

## Aesthetic

- Direction: cool editorial utility.
- Defining trait: large sections alternate between centered product promise and left-aligned evidence.
- Signature move: the sunny street-corner crop, where one crosshair-led blue selection bridges a street sign and storefront before resolving to one natural clipboard phrase.
- Forbidden: eyebrow text, leading-zero section numbers, pointless dot or pill indicators, sepia, dark theme, accent-left-border cards, glass, gradients, tiny decorative metadata, or diffuse shadows.

## Typography

- Display: `Avenir Next`, local macOS face, with `Helvetica Neue` and the platform sans stack as fallbacks.
- Body: `Avenir Next`, local macOS face, with `Helvetica Neue` and the platform sans stack as fallbacks.
- Typeface downloads are intentionally avoided to protect the load-time requirement. The local Avenir lead keeps the face more specific than a generic `system-ui` declaration.
- Scale: approximately 1.25 from a 16px base. Hero 51 to 120px at 0.92 line height; section heading 36 to 76px at 0.98; component heading 22px at 1.2; body 16 to 22px at 1.55 to 1.6.
- Weights: 400 body, 500 supporting display, 550 primary headings, 600 actions and compact headings.
- Measure: body copy is capped around 43rem. Only short hero and closing copy is centered.
- No text role uses a monospace family. Shortcut and code specimens inherit the sans stack.

## Color

- Strategy: one clear cyan-blue family over cool white and blue-gray neutrals. Color explains selection and action rather than decorating every section.
- Distribution: 70 neutral, 25 blue-tinted surfaces, 5 saturated action blue.
- Palette, role to OKLCH and fallback:
  - background: `oklch(98.3% 0.008 245)` | `#f7faff`
  - surface: `oklch(94.8% 0.018 245)` | `#edf3fa`
  - foreground: `oklch(19% 0.035 250)` | `#152235`
  - supporting: `oklch(37% 0.04 250)` | `#46586d`
  - muted: `oklch(50% 0.035 250)` | `#697b90`
  - border: `oklch(73% 0.045 250)` | `#a6b8ca`
  - accent: `oklch(48% 0.18 255)` | `#0069d2`
  - accent foreground: `oklch(98% 0.008 245)` | `#f7faff`
  - deep blue: `oklch(29% 0.12 255)` | `#163d70`

## Spacing, radius, and edge

- Spacing base: 4px. Working scale: 4, 8, 12, 16, 24, 32, 48, 64, 80, 112, 144.
- Radius: 8px controls and visual interiors; 14px for the single hero demo surface.
- Edge approach: defined borders only. No border is paired with a wide diffuse shadow.
- Tight within groups, generous between narrative sections.

## Layout and composition

- Grid: bounded 74rem editorial grid with fluid gutters.
- Scanning: centered Z-pattern hero, then left-aligned F-pattern evidence sections.
- Signature layout move: the wide hero statement and actions lead directly into an asymmetric 1.45-to-0.75 before/after demo.
- Feature specimens share one continuous ruled field rather than three floating cards.
- Responsive: mobile-first reading order. At 52rem, the demo, workflow, trust, and feature specimens stack. At 38rem, hero actions become Download then View source.

## Components and states

- Buttons: primary filled blue; secondary outlined; tertiary underlined text. Hover uses a 2px lift only on hover-capable devices. Active state retains shape and contrast.
- Focus: global 3px high-contrast blue outline with 4px offset.
- Targets: principal actions are at least 58px tall; navigation targets are at least 44px tall.
- Surfaces: use spacing and a single divider before adding enclosure. No nested cards.
- Empty, loading, and error states do not apply to this static front-end prototype. Download wiring remains intentionally deferred.

## Motion

- Duration: 160ms for interaction feedback. The explanatory capture loop is seven seconds with a long static read state.
- Easing: `cubic-bezier(0.23, 1, 0.32, 1)` for draws and reveals; linear only for opacity timing.
- The selection rectangle grows from its starting corner while a fixed-size crosshair travels with the drag endpoint. The loop leaves a long static read state.
- Reduced motion shows the completed selection and clipboard result without movement.

## Iconography

- Custom 24px outline icons with 1.8 to 2px rounded strokes.
- The download control uses a literal arrow-to-baseline icon. The copied state uses one matching check.

## Imagery and illustration

- Mode: one purpose-generated photorealistic street image with a lightweight SVG interface overlay.
- The source image is locally served as a 1440px WebP and lazy-loaded below the primary hero actions; it adds no client JavaScript or remote request.
- The visible sunny-day scene places the `7th Street` sign above the `STARBUCKS COFFEE` fascia so the selection can capture `7th Street` and `STARBUCKS` while clearly leaving `COFFEE` outside its right edge.
- The SVG overlay uses a lightly tinted rectangle and an outlined crosshair, echoing a native screen-region drag rather than adding ornamental animation.
- Avoid unrelated decorative imagery, glossy device frames, gradients, or text overlays that compete with the source text being demonstrated.

## Accessibility

- Semantic heading order, native links, a skip link, and descriptive hidden text accompany the decorative demo.
- Meaning is not color-only: selection has a frame shape, and success has both a check and text.
- Keyboard focus is visible and source order matches reading order.
- Reduced motion is explicit. The page must reflow without horizontal document scrolling at 320px and 200 percent zoom.

## Tokens

The source of truth is the global token block in `src/styles/global.css`; the page consumes those tokens and adds only page-local layout values. Adapter: plain scoped Astro CSS.

## Slop audit

- Date: 2026-08-17.
- Result: pass after rendered desktop, 390px, and 320px review.
- Corrections: darkened the primary blue to pass AA button-text contrast, removed the inherited design-lab minimum width that caused 320px overflow, and tightened the stacked demo result.
- Craft and accessibility gate: one named signature move, no prohibited card/eyebrow/pill/gradient treatment, visible keyboard focus, semantic headings, no document overflow, and an explicit reduced-motion final state.
- Intentional exception: one local sans family leads both display and body roles because zero font requests and fast first render outrank a decorative pairing.

## Changelog

- 2026-08-17: warmed the demonstration photo, strengthened the capture crosshair, added the GitHub mark, removed the fixed shortcut from public copy, and replaced the illustrative QR pattern with a working `copylasso.com` code.
- 2026-08-17: replaced the synthetic street scene with a purpose-generated photograph and rebuilt the capture loop as a crosshair-led region drag that deliberately excludes `COFFEE`.
- 2026-08-17: committed the selected landing-page direction from the ten-option lab, including the street-corner proof, centered hero actions, three-step workflow, continuous feature field, and simple close.
