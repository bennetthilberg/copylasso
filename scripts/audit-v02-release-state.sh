#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly release_state="$repository_root/docs/v0.2-release-state.md"
readonly expected_release_commit="43f1d0c676b08fb24b49fc628213fede90c4ed9d"
readonly expected_release_date="2026-07-29"
readonly expected_release_id="361797888"
readonly expected_dmg_sha256="697cb008cf294b32500e2ad84e5777a51fe8b88916856c5a8e9f1ec4eb74ba19"
readonly expected_checksum_sha256="6dfd44d92f6af1c14d765bc6c827ed3e9a0edd5ffe289c3e74ac6e1dd0c834b0"
readonly expected_appcast_sha256="a6be6c899e31e5913d5be315f209884100f709bd0e13d7490da8f07c9ed08ace"

fail() {
    echo "$1" >&2
    exit 1
}

require_text() {
    local file="$1"
    local expected="$2"

    /usr/bin/grep -Fq -- "$expected" "$file" || \
        fail "G44 release-state text is missing from ${file#$repository_root/}: $expected"
}

for required_file in \
    README.md \
    CHANGELOG.md \
    PRIVACY.md \
    SECURITY.md \
    CONTRIBUTING.md \
    docs/v0.2-product-contract.md \
    docs/security-and-privacy-review.md \
    docs/secure-update-operations.md \
    docs/release-checklist.md \
    docs/v0.2-release-state.md; do
    [[ -r "$repository_root/$required_file" ]] || \
        fail "Required G44 release-state file is missing: $required_file"
done

require_text "$repository_root/README.md" 'CopyLasso 0.2.0 is the latest public release.'
require_text "$repository_root/README.md" \
    'https://github.com/bennetthilberg/copylasso/releases/tag/v0.2.0'
require_text "$repository_root/README.md" \
    'https://github.com/bennetthilberg/copylasso/releases/download/v0.2.0/CopyLasso-0.2.0.dmg'
require_text "$repository_root/README.md" \
    'https://github.com/bennetthilberg/copylasso/releases/download/v0.2.0/CopyLasso-0.2.0.dmg.sha256'
require_text "$repository_root/CHANGELOG.md" '## Unreleased'
require_text "$repository_root/CHANGELOG.md" \
    'Update offers now render authenticated release notes in a bounded, scrollable native panel'
require_text "$repository_root/CHANGELOG.md" "## 0.2.0 - $expected_release_date"
require_text "$repository_root/PRIVACY.md" \
    '**Status:** Approved privacy contract for public CopyLasso 0.2.0.'
require_text "$repository_root/SECURITY.md" '| 0.2.x | Yes |'
require_text "$repository_root/SECURITY.md" '| 0.1.x | No |'
require_text "$repository_root/CONTRIBUTING.md" 'CopyLasso 0.2.0 is publicly released.'
require_text "$repository_root/docs/v0.2-product-contract.md" \
    '**Implementation status:** Released as 0.2.0 (3) on July 29, 2026.'
require_text "$repository_root/docs/security-and-privacy-review.md" \
    'This review describes the public CopyLasso 0.2.0 boundary.'
require_text "$repository_root/docs/secure-update-operations.md" \
    'CopyLasso 0.2.0 is the first public updater-enabled release.'
require_text "$repository_root/docs/release-checklist.md" \
    '## G44 - Close the v0.2 Release State'
require_text "$repository_root/docs/release-checklist.md" \
    '- [x] Date the changelog from the actual publication timestamp and update release-state documentation without changing immutable release bytes.'

for release_record in \
    "Release ID: \`$expected_release_id\`" \
    "Release commit: \`$expected_release_commit\`" \
    "Published: \`2026-07-29T14:43:30Z\`" \
    "DMG SHA-256: \`$expected_dmg_sha256\`" \
    "Checksum asset SHA-256: \`$expected_checksum_sha256\`" \
    "Appcast SHA-256: \`$expected_appcast_sha256\`" \
    'Issue [#36](https://github.com/bennetthilberg/copylasso/issues/36) closed after public updater verification.' \
    'Issue [#38](https://github.com/bennetthilberg/copylasso/issues/38) closed after public code-recognition verification.' \
    'Issue [#49](https://github.com/bennetthilberg/copylasso/issues/49) remains open because v0.2.0 contains no LaTeX recognizer.' \
    'then showed one enabled, branded CopyLasso entry and left every unrelated'; do
    require_text "$release_state" "$release_record"
done

unreleased_section="$(/usr/bin/awk '
    /^## Unreleased$/ { capture = 1; next }
    /^## / && capture { exit }
    capture { print }
' "$repository_root/CHANGELOG.md")"
[[ "$unreleased_section" == *'### Fixed'* ]] || \
    fail "The Unreleased section must retain the post-v0.2 G43A fix."
[[ "$unreleased_section" == *'bounded, scrollable native panel'* ]] || \
    fail "The G43A fix must remain under Unreleased instead of being folded into v0.2.0."

readonly current_public_files=(
    README.md
    PRIVACY.md
    SECURITY.md
    CONTRIBUTING.md
    docs/v0.2-product-contract.md
    docs/security-and-privacy-review.md
)
for prohibited_phrase in \
    'CopyLasso 0.1.1 is the latest public release' \
    'not publicly released' \
    'No public v0.2 update feed or updater-enabled release exists yet' \
    'public 0.1.1 artifact remains the current release' \
    'no public v0.2 feed or public artifact'; do
    if /usr/bin/grep -Fni -- "$prohibited_phrase" \
        "${current_public_files[@]/#/$repository_root/}"; then
        fail "Current public documentation retains stale prerelease text: $prohibited_phrase"
    fi
done

prohibited_publication_pattern='release upload|release edit.+--draft=false|make_latest=true|'
prohibited_publication_pattern+='git push.+v0\.2\.0|git tag.+v0\.2\.0'
if /usr/bin/grep -nE "$prohibited_publication_pattern" \
    "$repository_root/scripts/audit-v02-release-state.sh" | \
    /usr/bin/grep -v 'prohibited_publication_pattern'; then
    fail "G44 release-state verification must not add a publication or tag-mutation path."
fi

echo "CopyLasso v0.2 release-state audit passed."
