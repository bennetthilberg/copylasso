#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly release_state="$repository_root/docs/v0.2-release-state.md"
readonly expected_release_commit="81016fe43ee617b5f251564b03904137a4447266"
readonly expected_release_date="2026-08-10"
readonly previous_release_date="2026-08-09"
readonly expected_published_at="2026-08-10T15:48:33Z"
readonly expected_release_id="368002551"
readonly expected_final_tag_object="703af8f58a5c5587c70d9811ecdefd211cebfbfa"
readonly expected_dmg_sha256="9ac432f956418dd37e04de014867a7fc20d1daeecc80f6fe1db1e9c53b19de2a"
readonly expected_checksum_sha256="346605180b76d4959736267158138018b869d62b552b089fefdbe7aafa3031ca"
readonly expected_appcast_sha256="ad10db1486d4874701905ad3be2acc05f5025377328107a0aeabe552a9500cd6"
readonly expected_feed_deployment="83b459a7-bd14-47d4-8420-81d5320a4c86"

fail() {
    echo "$1" >&2
    exit 1
}

require_text() {
    local file="$1"
    local expected="$2"

    /usr/bin/grep -Fq -- "$expected" "$file" || \
        fail "G50 release-state text is missing from ${file#$repository_root/}: $expected"
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
        fail "Required G50 release-state file is missing: $required_file"
done

require_text "$repository_root/README.md" 'CopyLasso 0.2.2 is the latest public release.'
require_text "$repository_root/README.md" \
    'https://github.com/bennetthilberg/copylasso/releases/tag/v0.2.2'
require_text "$repository_root/README.md" \
    'https://github.com/bennetthilberg/copylasso/releases/download/v0.2.2/CopyLasso-0.2.2.dmg'
require_text "$repository_root/README.md" \
    'https://github.com/bennetthilberg/copylasso/releases/download/v0.2.2/CopyLasso-0.2.2.dmg.sha256'
require_text "$repository_root/CHANGELOG.md" '## Unreleased'
require_text "$repository_root/CHANGELOG.md" "## 0.2.2 - $expected_release_date"
require_text "$repository_root/CHANGELOG.md" "## 0.2.1 - $previous_release_date"
require_text "$repository_root/CHANGELOG.md" \
    'Update offers now render authenticated release notes in a bounded, scrollable native panel'
require_text "$repository_root/PRIVACY.md" \
    '**Status:** Public 0.2.2 (5).'
require_text "$repository_root/SECURITY.md" 'CopyLasso 0.2.2 is the latest public release.'
require_text "$repository_root/SECURITY.md" '| 0.2.x | Yes |'
require_text "$repository_root/SECURITY.md" '| 0.1.x | No |'
require_text "$repository_root/CONTRIBUTING.md" 'CopyLasso 0.2.2 is publicly released.'
require_text "$repository_root/docs/v0.2-product-contract.md" \
    '**Implementation status:** Released as 0.2.2 (5) on August 10, 2026.'
require_text "$repository_root/docs/v0.2.1-source-qualification.md" \
    '**Status:** Completed and published unchanged as 0.2.1 (4)'
require_text "$repository_root/docs/security-and-privacy-review.md" \
    'This review describes the public CopyLasso 0.2.2 boundary.'
require_text "$repository_root/docs/secure-update-operations.md" \
    'CopyLasso 0.2.2 is the current public updater-enabled release.'
require_text "$repository_root/docs/secure-update-operations.md" \
    '## 0.1.x Bootstrap and Current Public Release'
require_text "$repository_root/docs/secure-update-operations.md" \
    'CopyLasso 0.2.2, the current updater-enabled release, from the GitHub release page'
require_text "$repository_root/docs/release-checklist.md" \
    '- [x] Phase 3: merge the green, input-free protected preparation controls, then'
require_text "$repository_root/docs/release-checklist.md" \
    '- [x] Phase 3: publish only the exact approved candidate through a verified'
require_text "$repository_root/docs/release-checklist.md" \
    '- [x] Phase 3: close release-state documentation in a separate green pull'

for release_record in \
    'Release: [`v0.2.2`](https://github.com/bennetthilberg/copylasso/releases/tag/v0.2.2)' \
    "Release ID: \`$expected_release_id\`" \
    "Release commit: \`$expected_release_commit\`" \
    "Published: \`$expected_published_at\`" \
    "Final tag object: \`$expected_final_tag_object\`" \
    "DMG SHA-256: \`$expected_dmg_sha256\`" \
    "Checksum asset SHA-256: \`$expected_checksum_sha256\`" \
    "Appcast SHA-256: \`$expected_appcast_sha256\`" \
    "Production feed deployment: \`$expected_feed_deployment\`" \
    'The installed public application reports `0.2.2 (5)`' \
    'The exact public `0.2.1 (4)` application updated through the production feed to' \
    'byte-identical public `0.2.2 (5)` after separate download and'; do
    require_text "$release_state" "$release_record"
done

# Retain the immutable maintenance release evidence as history.
for historical_record in \
    'Release: [`v0.2.1`](https://github.com/bennetthilberg/copylasso/releases/tag/v0.2.1)' \
    'Release ID: `367570430`' \
    'Release commit: `813de17c739097217aad55a5a35c04ea3c73d99f`' \
    'Release state: public, non-prerelease, and superseded by v0.2.2' \
    'Appcast SHA-256: `c721b9396682c05082e019bdfa1297bc320f9883aabac2fd20c647f228aa8454`'; do
    require_text "$release_state" "$historical_record"
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
    fail "The current Unreleased section must remain empty after v0.2.2 publication."
security_hotfix_section="$(/usr/bin/awk '
    /^## 0\.2\.2 - 2026-08-10$/ { capture = 1; next }
    /^## / && capture { exit }
    capture { print }
' "$repository_root/CHANGELOG.md")"
[[ "$security_hotfix_section" == *'### Security'* && \
    "$security_hotfix_section" == *'GHSA-gmj2-gq3j-vqmj'* ]] || \
    fail "The dated 0.2.2 section must retain the Sparkle security hotfix."
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
    'source for maintenance release 0.2.1 is qualified privately' \
    'candidate 0.2.2 (5)' \
    'Candidate source `0.2.2 (5)`' \
    'Current source is being qualified as security-only candidate `0.2.2 (5)`'; do
    if /usr/bin/grep -Fni -- "$prohibited_phrase" \
        "${current_public_files[@]/#/$repository_root/}"; then
        fail "Current public documentation retains stale candidate text: $prohibited_phrase"
    fi
done

if /usr/bin/grep -Fq -- \
    'CopyLasso 0.2.0, the first updater-enabled release, from the GitHub release page' \
    "$repository_root/docs/secure-update-operations.md"; then
    fail "The secure-update bootstrap must not direct users to superseded 0.2.0."
fi

prohibited_publication_pattern='release upload|release edit.+--draft=false|make_latest=true|'
prohibited_publication_pattern+='git push.+v0\.2\.2|git tag.+v0\.2\.2'
if /usr/bin/grep -nE "$prohibited_publication_pattern" \
    "$repository_root/scripts/audit-v02-release-state.sh" | \
    /usr/bin/grep -v 'prohibited_publication_pattern'; then
    fail "G50 release-state verification must not add a publication or tag-mutation path."
fi

echo "CopyLasso v0.2.2 release-state audit passed."
