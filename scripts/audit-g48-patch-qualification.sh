#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly metadata="$repository_root/Configuration/ReleaseMetadata.xcconfig"
readonly notes="$repository_root/docs/release-notes/0.2.1.md"
readonly workflow="$repository_root/.github/workflows/release.yml"
readonly historical_publication_workflow="$repository_root/.github/workflows/prepare-publication.yml"
readonly entitlements="$repository_root/CopyLasso/CopyLasso.entitlements"
readonly package_resolved="$repository_root/CopyLasso.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"

fail() {
    echo "$1" >&2
    exit 1
}

require_text() {
    local relative_path="$1"
    local required_text="$2"

    /usr/bin/grep -Fq -- "$required_text" "$repository_root/$relative_path" || \
        fail "$relative_path is missing required G48 text: $required_text"
}

for required_file in \
    Configuration/ReleaseMetadata.xcconfig \
    CHANGELOG.md \
    README.md \
    PRIVACY.md \
    SECURITY.md \
    docs/release-notes/0.2.1.md \
    docs/v0.2.1-source-qualification.md \
    docs/v0.2-product-contract.md \
    docs/release-checklist.md \
    docs/release-workflow.md \
    docs/release-candidate-qualification.md \
    docs/secure-update-operations.md \
    docs/security-and-privacy-review.md \
    docs/testing.md \
    .github/workflows/release.yml \
    .github/workflows/prepare-publication.yml \
    scripts/lib/release-package-verification.sh \
    scripts/lib/v02-publication-verification.sh \
    scripts/verify-release-package.sh \
    scripts/verify-v02-candidate-package.sh; do
    [[ -s "$repository_root/$required_file" ]] || \
        fail "Required G48 qualification file is missing: $required_file"
done

/usr/bin/grep -Eq \
    '^COPYLASSO_RELEASE_VERSION[[:space:]]*=[[:space:]]*0\.2\.1[[:space:]]*$' \
    "$metadata" || fail "G48 must freeze CopyLasso at version 0.2.1."
/usr/bin/grep -Eq \
    '^COPYLASSO_RELEASE_BUILD[[:space:]]*=[[:space:]]*4[[:space:]]*$' \
    "$metadata" || fail "G48 must freeze CopyLasso at build 4."

require_text CHANGELOG.md '## 0.2.1 - Unreleased'
require_text README.md 'CopyLasso 0.2.0 is the latest public release.'
require_text README.md 'Current source is being qualified as CopyLasso 0.2.1 (4).'
require_text docs/v0.2-product-contract.md \
    'Candidate source is being qualified as 0.2.1 (4); public 0.2.0 (3) remains unchanged.'
require_text docs/release-notes/0.2.1.md '# CopyLasso 0.2.1'
require_text docs/release-notes/0.2.1.md 'No processing indicator is included.'
require_text docs/release-notes/0.2.1.md \
    'No recognition mode, permission, entitlement, dependency, or network path is added.'
require_text docs/release-notes/0.2.1.md 'direct screen-access confirmation'
require_text docs/release-notes/0.2.1.md 'one-millisecond pointer samples'
require_text docs/release-notes/0.2.1.md 'Control at mouse-up'
require_text docs/release-notes/0.2.1.md 'cross-display'
require_text docs/v0.2.1-source-qualification.md '# CopyLasso 0.2.1 Source Qualification'
require_text docs/manual-qa-and-performance.md \
    '[`v0.2.1-source-qualification.md`](v0.2.1-source-qualification.md)'

require_text .github/workflows/release.yml 'release_goal=G48'
require_text .github/workflows/release.yml 'release_subdirectory=g48'
require_text .github/workflows/release.yml \
    'release_tag="v${COPYLASSO_G28_VERSION}-g48.${GITHUB_RUN_ID}${GITHUB_RUN_ATTEMPT}"'
if /usr/bin/grep -Fq 'release_goal=G42' "$workflow" || \
    /usr/bin/grep -Fq 'release_subdirectory=g42' "$workflow"; then
    fail "The protected workflow still uses historical G42 execution paths."
fi
if [[ "$(/usr/bin/grep -Fc '${{ github.event.client_payload.' "$workflow")" != "1" ]]; then
    fail "candidate_number must remain the protected workflow's sole dispatch payload."
fi
if /usr/bin/grep -Eiq -- \
    'release (publish|edit.+--draft=false)|--clobber|make_latest=true|force=true' \
    "$workflow" "$repository_root/scripts/create-draft-release.sh"; then
    fail "G48 candidate tooling must remain draft-only and immutable."
fi

historical_feed_step="$(/usr/bin/sed -n \
    '/- name: Prepare feed-only deployment bundle/,/- name: Create verified private final draft/p' \
    "$historical_publication_workflow")"
[[ "$historical_feed_step" == *'source ./scripts/lib/v02-publication-verification.sh'* ]] || \
    fail "The historical G43 feed step must use pinned v0.2 publication metadata."
[[ "$historical_feed_step" != *'source ./scripts/lib/release-metadata.sh'* ]] || \
    fail "The historical G43 feed step must not use current G48 metadata."
require_text scripts/lib/v02-publication-verification.sh \
    'COPYLASSO_RELEASE_APPCAST="CopyLasso-0.2.0-appcast.xml"'
require_text scripts/lib/release-package-verification.sh \
    'COPYLASSO_RELEASE_PACKAGE_METADATA_PROFILE:-current'
require_text scripts/verify-release-package.sh '--pinned-v02-metadata'
require_text scripts/verify-v02-candidate-package.sh '--pinned-v02-metadata'

entitlements_json="$(/usr/bin/plutil -convert json -o - "$entitlements")" || \
    fail "CopyLasso entitlements are invalid."
if ! /usr/bin/jq -e '
    (keys | sort) == [
        "com.apple.security.app-sandbox",
        "com.apple.security.network.client",
        "com.apple.security.temporary-exception.mach-lookup.global-name"
    ] and
    .["com.apple.security.app-sandbox"] == true and
    .["com.apple.security.network.client"] == true and
    .["com.apple.security.temporary-exception.mach-lookup.global-name"] == [
        "$(PRODUCT_BUNDLE_IDENTIFIER)-spks",
        "$(PRODUCT_BUNDLE_IDENTIFIER)-spki"
    ]
    ' <<< "$entitlements_json" >/dev/null; then
    fail "G48 must preserve the reviewed updater-only sandbox entitlements."
fi
require_text CopyLasso.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved \
    '"version" : "3.0.1"'
require_text CopyLasso.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved \
    '"version" : "2.9.4"'

if git -C "$repository_root" grep -nE \
    'ProcessingIndicatorDesignLab|ProcessingFeedback|processing indicator' -- \
    CopyLasso CopyLassoTests CopyLassoUITests; then
    fail "Deferred G47 processing-indicator code must not ship in G48."
fi

for prerequisite_commit in \
    b93ed0c \
    aa011b5 \
    18f8f81 \
    8df5b97 \
    a1351f7; do
    git -C "$repository_root" merge-base --is-ancestor "$prerequisite_commit" HEAD || \
        fail "G48 is missing required reviewed ancestry: $prerequisite_commit"
done

require_text docs/v0.2-release-state.md '- Final tag: signed annotated `v0.2.0`'
require_text docs/v0.2-release-state.md '- Release commit: `43f1d0c676b08fb24b49fc628213fede90c4ed9d`'
require_text scripts/audit-v02-publication.sh 'COPYLASSO_V02_FINAL_TAG="v0.2.0"'
require_text scripts/lib/v02-publication-verification.sh \
    'COPYLASSO_RELEASE_VERSION="0.2.0"'
require_text scripts/lib/v02-publication-verification.sh \
    'COPYLASSO_RELEASE_DMG="CopyLasso-0.2.0.dmg"'
require_text scripts/audit-v02-release-state.sh 'expected_release_id="361797888"'

echo "CopyLasso G48 patch qualification audit passed."
