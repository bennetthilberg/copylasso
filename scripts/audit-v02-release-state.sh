#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly release_state="$repository_root/docs/v0.2-release-state.md"
readonly expected_release_commit="813de17c739097217aad55a5a35c04ea3c73d99f"
readonly expected_release_date="2026-08-09"
readonly expected_published_at="2026-08-09T19:59:13Z"
readonly expected_release_id="367570430"
readonly expected_dmg_sha256="05180caa3600bcd282246297a9172517136e43e55c6e8fa192b55ba44af4a017"
readonly expected_checksum_sha256="b9a85f82686dce479cb41247fe9fc025ec8a0d099bbc08028c4239899359b1c9"
readonly expected_appcast_sha256="c721b9396682c05082e019bdfa1297bc320f9883aabac2fd20c647f228aa8454"
readonly expected_feed_deployment="e768eb55-98d7-4d44-9603-65e3972fd66d"

fail() {
    echo "$1" >&2
    exit 1
}

require_text() {
    local file="$1"
    local expected="$2"

    /usr/bin/grep -Fq -- "$expected" "$file" || \
        fail "G49 release-state text is missing from ${file#$repository_root/}: $expected"
}

for required_file in \
    README.md \
    CHANGELOG.md \
    PRIVACY.md \
    SECURITY.md \
    CONTRIBUTING.md \
    docs/v0.2-product-contract.md \
    docs/v0.2.1-source-qualification.md \
    docs/security-and-privacy-review.md \
    docs/secure-update-operations.md \
    docs/release-checklist.md \
    docs/v0.2-release-state.md; do
    [[ -r "$repository_root/$required_file" ]] || \
        fail "Required G49 release-state file is missing: $required_file"
done

require_text "$repository_root/README.md" 'CopyLasso 0.2.1 is the latest public release.'
require_text "$repository_root/README.md" \
    'https://github.com/bennetthilberg/copylasso/releases/tag/v0.2.1'
require_text "$repository_root/README.md" \
    'https://github.com/bennetthilberg/copylasso/releases/download/v0.2.1/CopyLasso-0.2.1.dmg'
require_text "$repository_root/README.md" \
    'https://github.com/bennetthilberg/copylasso/releases/download/v0.2.1/CopyLasso-0.2.1.dmg.sha256'
require_text "$repository_root/CHANGELOG.md" '## Unreleased'
require_text "$repository_root/CHANGELOG.md" "## 0.2.1 - $expected_release_date"
require_text "$repository_root/CHANGELOG.md" \
    'Update offers now render authenticated release notes in a bounded, scrollable native panel'
require_text "$repository_root/PRIVACY.md" '**Status:** Public 0.2.1 (4).'
require_text "$repository_root/SECURITY.md" 'CopyLasso 0.2.1 is the latest public release.'
require_text "$repository_root/SECURITY.md" '| 0.2.x | Yes |'
require_text "$repository_root/SECURITY.md" '| 0.1.x | No |'
require_text "$repository_root/CONTRIBUTING.md" 'CopyLasso 0.2.1 is publicly released.'
require_text "$repository_root/docs/v0.2-product-contract.md" \
    '**Implementation status:** Released as 0.2.1 (4) on August 9, 2026.'
require_text "$repository_root/docs/v0.2.1-source-qualification.md" \
    '**Status:** Completed and published unchanged as 0.2.1 (4)'
require_text "$repository_root/docs/security-and-privacy-review.md" \
    'This review describes the public CopyLasso 0.2.1 boundary.'
require_text "$repository_root/docs/secure-update-operations.md" \
    'CopyLasso 0.2.1 is the current public updater-enabled release.'
require_text "$repository_root/docs/secure-update-operations.md" \
    '## 0.1.x Bootstrap and Current Public Release'
require_text "$repository_root/docs/secure-update-operations.md" \
    'CopyLasso 0.2.1, the current updater-enabled release, from the GitHub release page'
require_text "$repository_root/docs/release-checklist.md" \
    '- [x] Phase 1: merge the green G49 publication-control PR before dispatching the protected preparation workflow.'
require_text "$repository_root/docs/release-checklist.md" \
    '- [x] Phase 2: reverify the immutable candidate without rebuilding, create the private two-asset final draft and final-URL appcast, then publish the signed final tag, exact DMG and checksum, and authenticated feed through the approved transaction.'
require_text "$repository_root/docs/release-checklist.md" \
    '- [x] Phase 2: complete unauthenticated public-download, updater, installation, source-archive, feed, and immutable-tag verification.'
require_text "$repository_root/docs/release-checklist.md" \
    '- [x] Phase 3: date and close the public release state in a separate green ready PR without changing release bytes, tags, feed, or application code.'

for release_record in \
    'Release: [`v0.2.1`](https://github.com/bennetthilberg/copylasso/releases/tag/v0.2.1)' \
    "Release ID: \`$expected_release_id\`" \
    "Release commit: \`$expected_release_commit\`" \
    "Published: \`$expected_published_at\`" \
    'Final tag object: `eec528b9daf3026aa1e8c4e10acab41b91e37bc3`' \
    "DMG SHA-256: \`$expected_dmg_sha256\`" \
    "Checksum asset SHA-256: \`$expected_checksum_sha256\`" \
    "Appcast SHA-256: \`$expected_appcast_sha256\`" \
    "Production feed deployment: \`$expected_feed_deployment\`" \
    'The installed public application reports `0.2.1 (4)`' \
    'The exact public `0.2.0 (3)` application updated through the production feed to' \
    'byte-identical public `0.2.1 (4)` after separate download and'; do
    require_text "$release_state" "$release_record"
done

# Retain the immutable first v0.2 release evidence as history.
for historical_record in \
    'Release: [`v0.2.0`](https://github.com/bennetthilberg/copylasso/releases/tag/v0.2.0)' \
    'Release ID: `361797888`' \
    'Release commit: `43f1d0c676b08fb24b49fc628213fede90c4ed9d`' \
    'Release state: public, non-prerelease, and superseded by v0.2.1' \
    'Appcast SHA-256: `a6be6c899e31e5913d5be315f209884100f709bd0e13d7490da8f07c9ed08ace`'; do
    require_text "$release_state" "$historical_record"
done

unreleased_section="$(/usr/bin/awk '
    /^## Unreleased$/ { capture = 1; next }
    /^## / && capture { exit }
    capture { print }
' "$repository_root/CHANGELOG.md")"
[[ -z "${unreleased_section//[[:space:]]/}" ]] || \
    fail "The current Unreleased section must remain empty after v0.2.1 publication."
patch_section="$(/usr/bin/awk '
    /^## 0\.2\.1 - 2026-08-09$/ { capture = 1; next }
    /^## / && capture { exit }
    capture { print }
' "$repository_root/CHANGELOG.md")"
[[ "$patch_section" == *'### Fixed'* ]] || \
    fail "The dated 0.2.1 entry must retain the qualified patch fixes."
[[ "$patch_section" == *'bounded, scrollable native panel'* ]] || \
    fail "The public 0.2.1 entry must retain the authenticated Markdown presentation fix."

readonly current_public_files=(
    README.md
    PRIVACY.md
    SECURITY.md
    CONTRIBUTING.md
    docs/v0.2-product-contract.md
    docs/security-and-privacy-review.md
    docs/v0.2.1-source-qualification.md
)
for prohibited_phrase in \
    'CopyLasso 0.2.0 is the latest public release' \
    'Public 0.2.0 remains the latest' \
    'public 0.2.0 (3) remains unchanged' \
    'patch is not yet a public download' \
    'candidate 0.2.1 (4)' \
    'Candidate source is being qualified as 0.2.1 (4)' \
    'source for maintenance release 0.2.1 is qualified privately'; do
    if /usr/bin/grep -Fni -- "$prohibited_phrase" \
        "${current_public_files[@]/#/$repository_root/}"; then
        fail "Current public documentation retains stale v0.2.1 candidate text: $prohibited_phrase"
    fi
done

if /usr/bin/grep -Fq -- \
    'CopyLasso 0.2.0, the first updater-enabled release, from the GitHub release page' \
    "$repository_root/docs/secure-update-operations.md"; then
    fail "The secure-update bootstrap must not direct users to superseded 0.2.0."
fi

prohibited_publication_pattern='release upload|release edit.+--draft=false|make_latest=true|'
prohibited_publication_pattern+='git push.+v0\.2\.1|git tag.+v0\.2\.1'
if /usr/bin/grep -nE "$prohibited_publication_pattern" \
    "$repository_root/scripts/audit-v02-release-state.sh" | \
    /usr/bin/grep -v 'prohibited_publication_pattern'; then
    fail "G49 release-state verification must not add a publication or tag-mutation path."
fi

echo "CopyLasso v0.2.1 release-state audit passed."
