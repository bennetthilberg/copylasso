# Accessibility And Appearance

CopyLasso uses native SwiftUI and AppKit presentation while keeping every essential state understandable without relying on color, animation, or a visual icon alone.

## Semantic Contract

- The template-rendered menu-bar symbol exposes a changing text label plus stable help. Success, no-text, and failure states are announced in words.
- Menu commands, onboarding actions, Settings controls, links, and permission-recovery actions use native controls with accessible names. The third-party shortcut recorder receives an explicit `Capture Text keyboard shortcut` label and actionable help in both onboarding and Settings.
- The native success-sound toggle exposes its on/off value, a complete label, and help that states the sound follows a successful clipboard write.
- Settings keeps concise visible labels while retaining complete accessibility
  help for the shortcut recorder, success-sound toggle, and update controls.
- Launch at Login exposes its native on/off value plus a full textual status and issue description. Symbols and foreground colors only reinforce that copy.
- The recovery panel reads title, neutral authorization status, manual path, retry result, and three explicitly named actions in visual order. Each action has help describing its effect.
- Feedback is one combined accessibility element with bounded success, no-text, or user-safe failure copy. The selection overlay remains one labeled group with Escape help. v0.1 does not promise a VoiceOver-driven replacement for the visual drag gesture.

Native tab traversal, default/cancel actions, `Command-,`, and `Command-W` provide keyboard operation. CopyLasso adds no custom focus loop that could conflict with Full Keyboard Access.

Sound is supplementary feedback only. CopyLasso continues to expose success through the visual HUD and menu-bar accessibility label, so muted output, unavailable audio, a disabled preference, and Deaf or hard-of-hearing use never remove the only indication of an outcome.

## Appearance Policy

`SystemAccessibilityAppearanceProvider` reads Increased Contrast, Differentiate Without Color, Reduce Transparency, and Reduce Motion directly from `NSWorkspace` whenever a selection session creates its surfaces and before every feedback presentation. Re-reading before presentation means the reusable feedback host follows a setting changed between HUD appearances.

The selection rectangle uses one neutral-gray dashed outline with a subtle two-point corner radius instead of stacked black-and-white strokes. The radius affects only the visible outline; selected and captured geometry remains the exact square rectangle. Standard mode keeps the proven 18% initiating-display dim with a one-point outline; Increased Contrast uses a 28% dim and a modestly stronger 1.5-point outline. The six-point dash and four-point gap pattern advances by one complete pattern every 0.6 seconds with a linear timing function, so it moves steadily without pulsing or easing. Other displays remain clear, and the dashed geometry keeps selection meaning independent of hue.

The feedback HUD uses regular material in the standard appearance. With Reduce Transparency enabled, an explicit appearance decision replaces that material with an opaque semantic window-background color while retaining the rounded HUD shape and separator. Native controls continue to inherit system light, dark, and contrast behavior. CopyLasso's selection, recovery, and feedback panels use no app-defined window animation. Reduce Motion also leaves the selection outline dashed but freezes its phase; no essential state depends on motion. The idle status item uses CopyLasso's original vector template symbol, while temporary workflow feedback uses system success, no-text, and failure symbols.

## Dynamic Layout

Onboarding, Settings, About, and recovery views use minimum/ideal dimensions rather than exact fixed heights so their native containers can grow. Explanatory text uses multiline layout. The feedback host measures the rendered SwiftUI view immediately before every presentation, retains a 104-point minimum, and expands vertically for wrapped or enlarged text instead of clipping it.

Feedback remains mouse-transparent and transient. Its complete bounded message is also available as a single accessibility label, so presentation does not require focus or interaction.

## Verification Boundary

Unit tests cover both selection line weights, animated and Reduce Motion-static dash behavior, linear phase timing, drag-path synchronization, cleanup, both feedback-background decisions, reusable-host refresh from the current appearance, every live `NSWorkspace` accessibility flag, fixed accessibility copy, sound-toggle state and help, motion-free panel configuration, and real hosted feedback expansion. Signed UI coverage checks compound-control labels, native keyboard completion/closure, the compact menu grouping and Settings copy, light/dark launches, recovery actions, and overlay semantics.

The physical checklist in [Testing](../testing.md) remains necessary for VoiceOver speech/order, Accessibility Inspector hierarchy, Full Keyboard Access traversal, maximum text size, system Increased Contrast, Reduce Transparency, Differentiate Without Color, Reduce Motion, and actual light/dark rendering. An unavailable graphical session is recorded as pending rather than treated as a pass.
