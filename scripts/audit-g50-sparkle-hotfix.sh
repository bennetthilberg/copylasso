#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly historical_metadata="$repository_root/scripts/lib/v022-release-package-metadata.sh"
readonly project="$repository_root/CopyLasso.xcodeproj/project.pbxproj"
readonly package_resolved="$repository_root/CopyLasso.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
readonly workflow="$repository_root/.github/workflows/release.yml"
readonly entitlements="$repository_root/CopyLasso/CopyLasso.entitlements"

fail() {
    echo "$1" >&2
    exit 1
}

require_text() {
    local relative_path="$1"
    local required_text="$2"

    /usr/bin/grep -Fq -- "$required_text" "$repository_root/$relative_path" || \
        fail "$relative_path is missing required G50 text: $required_text"
}

for required_file in \
    scripts/lib/v022-release-package-metadata.sh \
    CHANGELOG.md \
    README.md \
    PRIVACY.md \
    SECURITY.md \
    THIRD_PARTY_NOTICES.md \
    docs/release-notes/0.2.2.md \
    docs/security-and-privacy-review.md \
    docs/secure-update-operations.md \
    docs/testing.md \
    CopyLasso/Resources/Sparkle-2.9.5-LICENSE.txt \
    scripts/fixtures/v0.2.1-published-release-notes.md \
    scripts/lib/v021-release-package-metadata.sh \
    scripts/download-v02-candidate.sh \
    scripts/verify-v02-candidate-package.sh \
    .github/workflows/release.yml; do
    [[ -s "$repository_root/$required_file" ]] || \
        fail "Required G50 hotfix file is missing: $required_file"
done

require_text scripts/lib/v022-release-package-metadata.sh \
    'COPYLASSO_RELEASE_VERSION="0.2.2"'
require_text scripts/lib/v022-release-package-metadata.sh \
    'COPYLASSO_RELEASE_BUILD="5"'

[[ "$(/usr/bin/grep -Fc 'version = 2.9.5;' "$project")" == "1" ]] || \
    fail "The shipping Sparkle package must be pinned exactly to 2.9.5."
[[ "$(/usr/bin/grep -Fc 'version = 2.9.4;' "$project")" == "0" ]] || \
    fail "The affected Sparkle 2.9.4 package must not remain in the shipping reference."

/usr/bin/plutil -convert json -o - "$package_resolved" | /usr/bin/jq -e '
    [.pins[] | select(.identity == "sparkle")] == [
      {
        "identity": "sparkle",
        "kind": "remoteSourceControl",
        "location": "https://github.com/sparkle-project/Sparkle",
        "state": {
          "revision": "79bc9e872948e47877e76f194cb0c8e0412b0b90",
          "version": "2.9.5"
        }
      }
    ]
' >/dev/null || fail "Sparkle must resolve exactly to reviewed 2.9.5 commit 79bc9e8."

[[ ! -e "$repository_root/CopyLasso/Resources/Sparkle-2.9.4-LICENSE.txt" ]] || \
    fail "The affected Sparkle 2.9.4 license resource must not remain in the app bundle."
require_text CopyLasso/Models/AboutMetadata.swift 'Sparkle-2.9.5-LICENSE'
require_text CopyLasso/Models/AboutMetadata.swift 'Sparkle 2.9.5'
require_text THIRD_PARTY_NOTICES.md '## Sparkle 2.9.5'
require_text THIRD_PARTY_NOTICES.md \
    '[`CopyLasso/Resources/Sparkle-2.9.5-LICENSE.txt`](CopyLasso/Resources/Sparkle-2.9.5-LICENSE.txt)'
[[ "$(/usr/bin/shasum -a 256 \
    "$repository_root/CopyLasso/Resources/Sparkle-2.9.5-LICENSE.txt" | \
    /usr/bin/awk '{print $1}')" == \
    '389a4e4e9a32f059775b13a06e25a591445ba229d2838d26dd3e7c0c45127cfe' ]] || \
    fail "The shipping Sparkle 2.9.5 license differs from the reviewed upstream bytes."
[[ "$(/usr/bin/shasum -a 256 \
    "$repository_root/scripts/fixtures/v0.2.1-published-release-notes.md" | \
    /usr/bin/awk '{print $1}')" == \
    '24dd1c6c235ba0e0d0bf433e07d6b1ddd5a8c2425fa368a4fa16926eb016b503' ]] || \
    fail "The immutable published v0.2.1 release-note fixture changed."

require_text CHANGELOG.md '## 0.2.2 - 2026-08-10'
require_text README.md 'CopyLasso 0.2.2 is the latest public release.'
require_text README.md \
    'https://github.com/bennetthilberg/copylasso/releases/tag/v0.2.2'
require_text docs/release-notes/0.2.2.md '# CopyLasso 0.2.2'
require_text docs/release-notes/0.2.2.md 'GHSA-gmj2-gq3j-vqmj'
require_text docs/release-notes/0.2.2.md 'full-package updates only'
require_text docs/release-notes/0.2.2.md \
    'CopyLasso 0.1.x users must install CopyLasso 0.2.2 manually once'
require_text docs/security-and-privacy-review.md \
    'GHSA-gmj2-gq3j-vqmj'
require_text docs/security-and-privacy-review.md \
    '79bc9e872948e47877e76f194cb0c8e0412b0b90'
require_text scripts/download-v02-candidate.sh \
    '$repository_root/$COPYLASSO_V02_RELEASE_NOTES'
require_text scripts/verify-v02-candidate-package.sh \
    '--release-metadata-profile "$COPYLASSO_V02_RELEASE_PACKAGE_PROFILE"'

require_text .github/workflows/release.yml 'release_goal=G55'
require_text .github/workflows/release.yml 'release_subdirectory=g55'
require_text .github/workflows/release.yml \
    'release_tag="v${COPYLASSO_G28_VERSION}-g55.${GITHUB_RUN_ID}${GITHUB_RUN_ATTEMPT}"'

readonly delta_generators=(
    scripts/build-private-update-fixture.sh
    scripts/generate-draft-appcast.sh
    scripts/generate-release-appcast.sh
)
if git -C "$repository_root" grep -nE -- \
    '--maximum-deltas[[:space:]]+([1-9][0-9]*|true|yes)' -- \
    "${delta_generators[@]}"; then
    fail "Tracked release tooling must not enable Sparkle delta generation."
fi
delta_option_count="$(git -C "$repository_root" grep -h -- \
    '--maximum-deltas' -- "${delta_generators[@]}" | /usr/bin/wc -l | /usr/bin/tr -d ' ')"
[[ "$delta_option_count" -gt 0 ]] || \
    fail "G50 must retain an explicit full-package-only update boundary."
if git -C "$repository_root" grep -h -- '--maximum-deltas' -- "${delta_generators[@]}" | \
    /usr/bin/grep -Ev -- '--maximum-deltas([=[:space:]]+)0([[:space:]\\]|$)' >/dev/null; then
    fail "Every tracked Sparkle delta option must remain fixed at zero."
fi

entitlement_keys="$(/usr/bin/plutil -convert json -o - "$entitlements" | \
    /usr/bin/jq -r 'keys[]' | LC_ALL=C /usr/bin/sort)"
expected_entitlement_keys="$(printf '%s\n' \
    'com.apple.security.app-sandbox' \
    'com.apple.security.network.client' \
    'com.apple.security.temporary-exception.mach-lookup.global-name' | LC_ALL=C /usr/bin/sort)"
[[ "$entitlement_keys" == "$expected_entitlement_keys" ]] || \
    fail "G50 must not change the reviewed application entitlement set."
/usr/bin/plutil -convert json -o - "$entitlements" | /usr/bin/jq -e '
    . == {
      "com.apple.security.app-sandbox": true,
      "com.apple.security.network.client": true,
      "com.apple.security.temporary-exception.mach-lookup.global-name": [
        "$(PRODUCT_BUNDLE_IDENTIFIER)-spks",
        "$(PRODUCT_BUNDLE_IDENTIFIER)-spki"
      ]
    }
' >/dev/null || fail "G50 must preserve the exact reviewed application entitlements."

echo "CopyLasso G50 Sparkle hotfix audit passed."
