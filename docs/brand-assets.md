# CopyLasso Brand Assets

## Original Design

The CopyLasso mark was created specifically for this project on July 14, 2026. It is not stock artwork, is not derived from another product's icon, and does not imply affiliation with another organization. The project-authored source is distributed under CopyLasso's MIT license.

The mark combines an open lasso loop, four small cardinal gaps that give the loop a crosshair rhythm, a short lower-right rope tail, and three horizontal text strokes. It contains no letters or wordmark and remains recognizable without color.

## App Icon

`CopyLasso/AppIcon.icon` is the shipping layered Icon Composer document. Its three vector layers are retained in `BrandAssets/AppIconLayers` and embedded into the document:

- Blue background: a diagonal gradient from deep blue `#0B3A82` to clear blue `#3B82F6`.
- Lasso frame: warm white `#F8FAFC`, formed from four curved quadrants with rounded caps and a lower-right rope tail.
- Text strokes: three warm-white rounded bars of decreasing length.

Icon Composer supplies the platform mask, depth treatment, and distinct Default, Dark, and Mono renditions. The final mark layers keep Liquid Glass effects disabled so their source geometry and contrast remain crisp. Xcode compiles the document into the standard macOS icon representations and the app's asset catalog.

## Menu-Bar Symbol

`MenuBarLasso` is an original 18-by-18-point SVG template symbol derived from the same four-gap lasso, lower-right rope tail, and text strokes as the application mark. The asset catalog preserves its vector representation and renders it as a black-and-transparent template so macOS supplies the correct menu-bar color in light, dark, and increased-contrast appearances. Temporary workflow feedback continues to use familiar system status symbols.

## Success Sound

`CopyLasso/Resources/CopyLassoSuccess.wav` is original project-authored confirmation audio introduced on July 23, 2026 for G37 and refined through maintainer audition on July 27, 2026 for G40A. It contains no recording, sample, Apple system sound, or third-party audio. The maintainer selected the seventeenth of eighteen project-authored candidates: a warm two-step lift with a restrained futuristic halo.

The checked-in `scripts/generate-success-sound.swift` source constructs the sound deterministically from seeded filtered texture, two damped struck-tone voices, a short harmonic accent, subtle room reflections, and soft limiting. The asset is mono 16-bit PCM WAV at 44.1 kHz, contains 8,291 frames, and lasts 0.188005 seconds. Its SHA-256 is `e98be6b3eef44bffa5f5759ee83e99efd1ab3dfb820054a3d910be9b54cd2299`. Native arm64 and Rosetta x86_64 generation produce identical bytes. Canonical CI regenerates the file, requires byte equality and the reviewed format, and compares the exact source bytes with the Debug and Universal 2 Release resources. The generator and audio are distributed under CopyLasso's MIT license. Playback uses AppKit's public asynchronous `NSSound` file interface; CopyLasso does not copy or invoke the private macOS screenshot sound.

## Exact-Name Review

The final pre-artifact exact-name review was repeated on July 14, 2026:

- GitHub repository search returned only `bennetthilberg/copylasso`, the current project.
- Homebrew's formula and cask APIs returned no exact `copylasso` token or display-name match.
- Apple's U.S. Mac software search API returned no exact `CopyLasso` application-name match.
- A general exact-name web search returned no separate macOS application using the name.

Sources checked: GitHub repository search, `formulae.brew.sh/api/formula.json`, `formulae.brew.sh/api/cask.json`, `itunes.apple.com/search` with the U.S. `macSoftware` entity, and general web results for the exact name.

Search results can change and are not a trademark opinion or legal clearance. The review only records the sources and exact-match results observed on that date.
