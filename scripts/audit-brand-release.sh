#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly built_app="${COPYLASSO_BRAND_APP:-}"
readonly active_developer_directory="${DEVELOPER_DIR:-$(/usr/bin/xcode-select -p)}"
readonly xcode_contents_directory="$(cd "$active_developer_directory/.." && /bin/pwd -P)"
readonly icon_tool="$xcode_contents_directory/Applications/Icon Composer.app/Contents/Executables/ictool"
readonly icon_document="$repository_root/CopyLasso/AppIcon.icon"
readonly menu_image_set="$repository_root/CopyLasso/Assets.xcassets/MenuBarLasso.imageset"
readonly audit_output_candidate="${COPYLASSO_BRAND_AUDIT_OUTPUT:-$repository_root/.build/brand-release-audit}"

fail() {
    echo "$1" >&2
    exit 1
}

require_file() {
    [[ -f "$1" ]] || fail "Required brand or release file is missing: ${1#"$repository_root/"}"
}

require_text() {
    local file="$1"
    local text="$2"
    /usr/bin/grep -Fq "$text" "$file" || \
        fail "Required text is missing from ${file#"$repository_root/"}: $text"
}

cd "$repository_root"

readonly audit_output_parent="$(/usr/bin/dirname "$audit_output_candidate")"
readonly audit_output_name="$(/usr/bin/basename "$audit_output_candidate")"
audit_output_parent_canonical="$({
    cd "$audit_output_parent" 2>/dev/null && /bin/pwd -P
})" || fail "Brand audit output parent must already exist."
readonly audit_output_parent_canonical
readonly audit_output="$audit_output_parent_canonical/$audit_output_name"

case "$audit_output" in
    "$repository_root"/.build/*) ;;
    *) fail "Brand audit output must remain under the repository .build directory." ;;
esac

require_file "$icon_document/icon.json"
require_file "$icon_document/Assets/background-default.svg"
require_file "$icon_document/Assets/lasso.svg"
require_file "$icon_document/Assets/text-strokes.svg"
require_file "$menu_image_set/Contents.json"
require_file "$menu_image_set/MenuBarLasso.svg"
require_file "$repository_root/docs/brand-assets.md"
require_file "$repository_root/docs/developer-id-signing.md"
require_file "$repository_root/docs/release-checklist.md"
require_file "$repository_root/docs/clean-install-testing.md"
require_file "$repository_root/docs/release-candidate-qualification.md"
require_file "$repository_root/docs/release-notes/0.1.0.md"

if [[ -e CopyLasso/Assets.xcassets/AppIcon.appiconset ]]; then
    fail "The empty development AppIcon catalog must not coexist with AppIcon.icon."
fi

for layer in background-default.svg lasso.svg text-strokes.svg; do
    require_file "$repository_root/BrandAssets/AppIconLayers/$layer"
    /usr/bin/cmp -s \
        "$repository_root/BrandAssets/AppIconLayers/$layer" \
        "$icon_document/Assets/$layer" || \
        fail "The retained $layer source does not match the Icon Composer document."
done

/usr/bin/xmllint --noout \
    BrandAssets/AppIconLayers/*.svg \
    "$menu_image_set/MenuBarLasso.svg"

if ! /usr/bin/jq -e '
    .groups | length == 1
    and .[0].name == "CopyLasso Mark"
    and (.[0].layers | map(.name) == ["Text Strokes", "Lasso Frame", "Blue Background"])
    and (.[0].layers[0].glass == false)
    and (.[0].layers[0].fill == "none")
    and (.[0].layers[1].glass == false)
    and (.[0].layers[1]["fill-specializations"] | map(.value) == ["none", "none"])
' "$icon_document/icon.json" >/dev/null; then
    fail "AppIcon.icon does not retain the reviewed three-layer vector contract."
fi

if ! /usr/bin/jq -e '
    .properties["preserves-vector-representation"] == true
    and .properties["template-rendering-intent"] == "template"
    and .images[0].filename == "MenuBarLasso.svg"
' "$menu_image_set/Contents.json" >/dev/null; then
    fail "MenuBarLasso must remain a preserved vector template asset."
fi

require_text BrandAssets/AppIconLayers/background-default.svg '#0B3A82'
require_text BrandAssets/AppIconLayers/background-default.svg '#3B82F6'
if /usr/bin/grep -Eq '#312E81|#6366F1|id="indigo"' \
    BrandAssets/AppIconLayers/background-default.svg; then
    fail "The retired purple-indigo app-icon gradient remains in the brand source."
fi
require_text BrandAssets/AppIconLayers/lasso.svg '#F8FAFC'
require_text BrandAssets/AppIconLayers/text-strokes.svg '#F8FAFC'

if [[ "$(/usr/bin/grep -c 'data-role="lasso-quadrant"' BrandAssets/AppIconLayers/lasso.svg)" != 4 ]] || \
    [[ "$(/usr/bin/grep -c 'data-role="lasso-tail"' BrandAssets/AppIconLayers/lasso.svg)" != 1 ]]; then
    fail "The app-icon lasso must retain four cardinal gaps and one lower-right rope tail."
fi

if [[ "$(/usr/bin/grep -c 'data-role="lasso-quadrant"' "$menu_image_set/MenuBarLasso.svg")" != 4 ]] || \
    [[ "$(/usr/bin/grep -c 'data-role="lasso-tail"' "$menu_image_set/MenuBarLasso.svg")" != 1 ]]; then
    fail "The menu-bar lasso must retain four cardinal gaps and one lower-right rope tail."
fi

if /usr/bin/grep -R -n -F 'viewfinder' CopyLasso; then
    fail "The development viewfinder placeholder remains in the application target."
fi

require_text CopyLasso/SharedUI/MenuBarLabelView.swift 'Image("MenuBarLasso")'
require_text CopyLasso/SharedUI/MenuBarLabelView.swift '.renderingMode(.template)'
require_text CopyLasso/SharedUI/AboutView.swift \
    'DeferredApplicationIconView(source: applicationIconSource)'
require_text CopyLasso/SharedUI/AboutView.swift 'NSApp.applicationIconImage'
if /usr/bin/grep -Fq 'NSApp.applicationIconImage' CopyLasso/App/CopyLassoApp.swift; then
    fail "The About scene must defer loading the application icon until its view is presented."
fi
require_text CopyLasso/Models/AboutMetadata.swift 'Created by Bennett Hilberg'
require_text CopyLasso/Models/AboutMetadata.swift 'https://github.com/bennetthilberg/copylasso'
require_text CopyLasso/Models/AboutMetadata.swift 'KeyboardShortcuts 3.0.1'
require_text CopyLasso/App/CopyLassoApp.swift 'CopyLassoApplicationCommands()'
require_text CopyLasso/App/CopyLassoApp.swift 'CommandGroup(replacing: .appInfo)'

if /usr/bin/grep -R -n -F 'All rights reserved' \
    CopyLasso CopyLasso.xcodeproj/project.pbxproj; then
    fail "The application must not claim all rights reserved for MIT-licensed CopyLasso."
fi

if [[ "$(/usr/bin/grep -c \
    'INFOPLIST_KEY_NSHumanReadableCopyright = "Created by Bennett Hilberg. Open source under the MIT License.";' \
    CopyLasso.xcodeproj/project.pbxproj)" != 2 ]]; then
    fail "Every application configuration must embed the open-source creator description."
fi

if [[ "$(/usr/bin/grep -c 'MARKETING_VERSION = 0.1.0;' CopyLasso.xcodeproj/project.pbxproj)" != 6 ]] || \
    [[ "$(/usr/bin/grep -c 'CURRENT_PROJECT_VERSION = 1;' CopyLasso.xcodeproj/project.pbxproj)" != 6 ]] || \
    [[ "$(/usr/bin/grep -c 'PRODUCT_BUNDLE_IDENTIFIER = io.github.bennetthilberg.copylasso;' CopyLasso.xcodeproj/project.pbxproj)" != 1 ]]; then
    fail "Version 0.1.0, build 1, and the production bundle identifier must remain final."
fi

for text in \
    '## Requirements' \
    '## Installation Preview' \
    '## Use CopyLasso' \
    '## Permission and Recovery' \
    '## Privacy' \
    '## Known Limitations' \
    '## Build from Source' \
    '## Contributing' \
    '## Complete Uninstall' \
    'io.github.bennetthilberg.copylasso' \
    'tccutil reset ScreenCapture io.github.bennetthilberg.copylasso'; do
    require_text README.md "$text"
done

require_text CHANGELOG.md '## 0.1.0 - Unreleased'
require_text CHANGELOG.md 'pasteboard clear-success followed by text-write rejection'
require_text docs/release-checklist.md '## G26 - Developer ID Signing And Notarization'
require_text docs/release-checklist.md '## G27 - Reproducible Release Package'
require_text docs/release-checklist.md '## G28 - Protected Release Workflow'
require_text docs/release-checklist.md '## G29 - Clean Installation Test Environment'
require_text docs/release-checklist.md '[`clean-install-testing.md`](clean-install-testing.md)'
require_text docs/release-checklist.md '## G30 - Release Candidate Qualification'
require_text docs/release-checklist.md 'disposable local macOS user account'
require_text docs/release-checklist.md 'candidate_number'
require_text docs/release-checklist.md '## G31 - Final Tag And Publication'
require_text docs/release-workflow.md '## G30 Protected Candidate Handoff'
require_text docs/release-workflow.md 'In the post-merge protected run'
require_text docs/release-workflow.md 'The G28 rehearsal draft and its assets cannot serve as G30 evidence.'
require_text docs/clean-install-testing.md 'v0.1.0-g28.295914448081'
require_text docs/clean-install-testing.md '0b38f85acd7507cbacfacb820d534ac60907c8d12bec08c3b7f41f6cf1d1952f'
require_text docs/clean-install-testing.md 'io.github.bennetthilberg.copylasso'
require_text docs/clean-install-testing.md 'COPYLASSO_CANDIDATE_DMG'
require_text docs/clean-install-testing.md 'COPYLASSO_CANDIDATE_SHA256'
require_text docs/clean-install-testing.md 'candidate_checksum="${candidate_dmg}.sha256"'
require_text docs/clean-install-testing.md "'^[0-9a-f]{64}$'"
require_text docs/clean-install-testing.md 'printf '\''%s  %s\n'\'' "$candidate_sha256" "$candidate_dmg"'
require_text docs/clean-install-testing.md 'xattr -p com.apple.quarantine "$candidate_dmg"'
require_text docs/clean-install-testing.md '/usr/bin/shasum -a 256 -c -'
require_text docs/clean-install-testing.md 'tccutil reset ScreenCapture io.github.bennetthilberg.copylasso'
require_text docs/clean-install-testing.md 'never boot it for testing'
require_text docs/clean-install-testing.md 'download the DMG normally'
require_text docs/clean-install-testing.md 'shared folder'
require_text docs/clean-install-testing.md 'Do not remove quarantine, disable'
require_text docs/clean-install-testing.md 'Reopen windows when'
require_text docs/clean-install-testing.md 'vm_interface=bridge100'
require_text docs/clean-install-testing.md '/usr/bin/python3 -m http.server "$vm_port"'
require_text docs/clean-install-testing.md '## G29 Partial Rehearsal Record'
require_text docs/clean-install-testing.md 'accepted evidence gaps'
require_text docs/v0.1-product-contract.md 'Before download, that account must have no CopyLasso application, production'
require_text docs/v0.1-product-contract.md 'preferences, production container, login item, or Screen Recording approval.'
require_text docs/v0.1-product-contract.md '**Implementation status:** Release-candidate qualification'
require_text docs/v0.1-product-contract.md 'clipboard may change'
require_text docs/release-candidate-qualification.md '## Exact Candidate Smoke Matrix'
require_text docs/release-candidate-qualification.md 'Do not resume VirtualBuddy'
require_text docs/release-notes/0.1.0.md 'CopyLasso 0.1.0'
require_text docs/release-notes/0.1.0.md 'Locking the Mac during an active drag'
require_text docs/brand-assets.md 'The final pre-artifact exact-name review was repeated on July 14, 2026'
require_text THIRD_PARTY_NOTICES.md 'KeyboardShortcuts 3.0.1'
require_text THIRD_PARTY_NOTICES.md 'License: MIT'

reusable_download_section="$(/usr/bin/awk '
    /^## Duplicate, Download, And Verify$/ { include = 1 }
    /^## Full Clean-Install Run$/ { include = 0 }
    include { print }
' docs/clean-install-testing.md)"
if printf '%s\n' "$reusable_download_section" | \
    /usr/bin/grep -Eq '[0-9a-f]{64}|CopyLasso-[0-9][A-Za-z0-9._-]*\.dmg'; then
    fail "The reusable download procedure must not pin a historical candidate filename or digest."
fi

readonly public_copy=(
    README.md
    CHANGELOG.md
    PRIVACY.md
    CONTRIBUTING.md
    SECURITY.md
    docs/brand-assets.md
    docs/developer-id-signing.md
    docs/clean-install-testing.md
    docs/release-candidate-qualification.md
    docs/release-checklist.md
    docs/release-notes/0.1.0.md
    docs/v0.1-product-contract.md
)
readonly prohibited_public_pattern='TODO|example\.com|your organization|template organization|[Tt]ext[Ss]niper|[Oo][Cc][Rr][Aa][Cc][Yy]'
if /usr/bin/grep -nEi "$prohibited_public_pattern" "${public_copy[@]}"; then
    fail "Placeholder, retired-name, or proprietary-comparison copy remains public."
fi

[[ -x "$icon_tool" ]] || fail "Icon Composer's export verifier is unavailable."
rm -rf "$audit_output"
mkdir -p "$audit_output"
for rendition in Default Dark Mono; do
    "$icon_tool" "$icon_document" \
        --export-image \
        --output-file "$audit_output/$rendition.png" \
        --platform macOS \
        --rendition "$rendition" \
        --width 64 \
        --height 64 \
        --scale 1 >/dev/null
    if [[ "$(/usr/bin/sips -g pixelWidth "$audit_output/$rendition.png" 2>/dev/null | /usr/bin/awk '/pixelWidth/{print $2}')" != 64 ]] || \
        [[ "$(/usr/bin/sips -g pixelHeight "$audit_output/$rendition.png" 2>/dev/null | /usr/bin/awk '/pixelHeight/{print $2}')" != 64 ]]; then
        fail "Icon Composer could not render the $rendition appearance at 64 by 64 pixels."
    fi
done

[[ -n "$built_app" ]] || fail "COPYLASSO_BRAND_APP must identify the built application."
case "$built_app" in
    "$repository_root"/.build/*/CopyLasso.app) ;;
    *) fail "The brand audit app must remain under the repository .build directory." ;;
esac

readonly built_info="$built_app/Contents/Info.plist"
readonly built_resources="$built_app/Contents/Resources"
require_file "$built_info"
require_file "$built_resources/AppIcon.icns"
require_file "$built_resources/Assets.car"

if [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$built_info")" != 'AppIcon' ]] || \
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$built_info")" != 'AppIcon' ]] || \
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$built_info")" != '0.1.0' ]] || \
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$built_info")" != '1' ]]; then
    fail "The built app does not contain the final icon, version, and build metadata."
fi

/usr/bin/assetutil --info "$built_resources/Assets.car" > "$audit_output/assets.json"
for pixel_width in 32 64 128 256 512 1024; do
    if ! /usr/bin/jq -e --argjson width "$pixel_width" \
        'any(.[]; .Name == "AppIcon" and .PixelWidth == $width)' \
        "$audit_output/assets.json" >/dev/null; then
        fail "The built asset catalog is missing the $pixel_width-pixel AppIcon representation."
    fi
done

for appearance in NSAppearanceNameAqua NSAppearanceNameDarkAqua ISAppearanceTintable; do
    if ! /usr/bin/jq -e --arg appearance "$appearance" \
        'any(.[]; .Name == "AppIcon" and .Appearance == $appearance)' \
        "$audit_output/assets.json" >/dev/null; then
        fail "The built asset catalog is missing the $appearance AppIcon appearance."
    fi
done

for pixel_width in 18 36; do
    if ! /usr/bin/jq -e --argjson width "$pixel_width" \
        'any(.[]; .Name == "MenuBarLasso" and .PixelWidth == $width)' \
        "$audit_output/assets.json" >/dev/null; then
        fail "The built asset catalog is missing the $pixel_width-pixel MenuBarLasso representation."
    fi
done

/usr/bin/iconutil -c iconset \
    "$built_resources/AppIcon.icns" \
    -o "$audit_output/AppIcon.iconset"
require_file "$audit_output/AppIcon.iconset/icon_16x16.png"
require_file "$audit_output/AppIcon.iconset/icon_16x16@2x.png"
require_file "$audit_output/AppIcon.iconset/icon_128x128.png"
require_file "$audit_output/AppIcon.iconset/icon_128x128@2x.png"

echo "CopyLasso brand and release documentation audit passed."
