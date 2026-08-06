#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"

fail() {
    echo "$1" >&2
    exit 1
}

require_text() {
    local relative_path="$1"
    local required_text="$2"

    /usr/bin/grep -Fq -- "$required_text" "$repository_root/$relative_path" || \
        fail "$relative_path is missing required G46 text: $required_text"
}

if git -C "$repository_root" grep -nE \
    'Check for Updates(\.\.\.|…)' -- ':!roadmap.md'; then
    fail 'Check for Updates must not retain a trailing ellipsis.'
fi

for source in \
    CopyLasso/SharedUI/MenuBarMenuView.swift \
    CopyLasso/SharedUI/SettingsView.swift; do
    require_text "$source" 'Button("Check for Updates")'
done
require_text CopyLassoUITests/CopyLassoUITests.swift '"Check for Updates",'
require_text README.md '**Check for Updates** in Settings or the menu checks immediately;'

privacy_words="$(/usr/bin/wc -w < "$repository_root/PRIVACY.md" | /usr/bin/tr -d ' ')"
[[ "$privacy_words" -le 700 ]] || \
    fail "PRIVACY.md must remain concise (700 words maximum; found $privacy_words)."
for privacy_boundary in \
    'Update requests send no screen pixels' \
    'Success sound playback receives no captured pixels, recognized content, or clipboard text.' \
    'Code payloads are recognized locally' \
    'manually install public CopyLasso 0.2.0 once'; do
    require_text PRIVACY.md "$privacy_boundary"
done

require_text CopyLasso/SharedUI/AboutView.swift \
    'static let iconTitleSpacing: CGFloat = 18'
require_text CopyLasso/SharedUI/AboutView.swift \
    'VStack(spacing: AboutLayout.iconTitleSpacing)'

for release_note_contract in \
    CopyLasso/Models/SecureUpdateReleaseNotesPresentation.swift \
    CopyLasso/SharedUI/SecureUpdatePresentation.swift \
    CopyLassoTests/Update/SecureUpdateReleaseNotesPresentationTests.swift; do
    [[ -s "$repository_root/$release_note_contract" ]] || \
        fail "The authenticated Markdown release-note correction is missing: $release_note_contract"
done
require_text CHANGELOG.md \
    'Update offers now render authenticated release notes in a bounded, scrollable native panel'
require_text README.md \
    'the app shows the authenticated version, rendered release notes, and exact download size before any download;'

if /usr/bin/grep -R -nE \
    'CGDisplayHideCursor|CGDisplayShowCursor|CGAssociateMouseAndMouseCursorPosition|CGWarpMouseCursorPosition|setHiddenUntilMouseMoves|NSCursor\(image:|addSubview.+cursor' \
    "$repository_root/CopyLasso"; then
    fail 'G46 must use the public system crosshair and cursor rectangles without hiding, warping, or drawing a surrogate cursor.'
fi
require_text CopyLasso/Services/AppKitRegionSelectionService.swift \
    'static let cursorStabilizationDelays: [Duration] = ['
for cursor_stabilization_delay in 16 50 100 160; do
    require_text CopyLasso/Services/AppKitRegionSelectionService.swift \
        ".milliseconds($cursor_stabilization_delay)"
done
require_text CopyLasso/Services/AppKitRegionSelectionService.swift \
    'func setCrosshair()'

echo 'CopyLasso G46 product patch audit passed.'
