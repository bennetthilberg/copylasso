#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly metadata="$repository_root/Configuration/ReleaseMetadata.xcconfig"
readonly notes="$repository_root/docs/release-notes/0.2.1.md"
readonly workflow="$repository_root/.github/workflows/release.yml"
readonly publication_workflow="$repository_root/.github/workflows/prepare-publication.yml"
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
    docs/release-packaging.md \
    docs/secure-update-operations.md \
    docs/security-and-privacy-review.md \
    docs/testing.md \
    .github/workflows/release.yml \
    .github/workflows/prepare-publication.yml \
    scripts/lib/release-package-verification.sh \
    scripts/lib/v020-release-package-metadata.sh \
    scripts/lib/v02-publication-verification.sh \
    scripts/audit-g49-publication.sh \
    scripts/verify-release-package.sh \
    scripts/verify-v02-candidate-package.sh; do
    [[ -s "$repository_root/$required_file" ]] || \
        fail "Required G48 qualification file is missing: $required_file"
done

require_text CHANGELOG.md '## 0.2.1 - 2026-08-09'
require_text README.md 'CopyLasso 0.2.2 is the latest public release.'
require_text README.md 'CopyLasso-0.2.2.dmg.sha256'
require_text docs/v0.2-product-contract.md \
    '**Implementation status:** Released as 0.2.2 (5) on August 10, 2026.'
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
require_text docs/architecture/overview.md \
    '| G46 | Concise product copy, focus-preserving native system selector, transient geometry handoff to ScreenCaptureKit, and cursor-readiness product polish |'
[[ "$(/usr/bin/grep -Fc '| G46 |' "$repository_root/docs/architecture/overview.md")" == "1" ]] || \
    fail "Architecture goal ownership must contain exactly one canonical G46 row."
g44_line="$(/usr/bin/grep -nF '| G44 |' "$repository_root/docs/architecture/overview.md" | /usr/bin/cut -d: -f1)"
g45_line="$(/usr/bin/grep -nF '| G45 |' "$repository_root/docs/architecture/overview.md" | /usr/bin/cut -d: -f1)"
g46_line="$(/usr/bin/grep -nF '| G46 |' "$repository_root/docs/architecture/overview.md" | /usr/bin/cut -d: -f1)"
g48_line="$(/usr/bin/grep -nF '| G48 |' "$repository_root/docs/architecture/overview.md" | /usr/bin/cut -d: -f1)"
[[ "$g44_line" -lt "$g45_line" && "$g45_line" -lt "$g46_line" && \
    "$g46_line" -lt "$g48_line" ]] || \
    fail "Architecture goal ownership must retain chronological G44-G48 ordering."
require_text docs/release-packaging.md '## G48 exact-head qualification package'
require_text docs/release-packaging.md 'version `0.2.1`, build `4`'
require_text docs/release-packaging.md 'CopyLasso-0.2.1.dmg'
require_text docs/testing.md 'binds current public documentation to v0.2.2'
require_text docs/testing.md 'G49 and G50 Phase 3 likewise'

require_text .github/workflows/release.yml 'release_goal=G55'
require_text .github/workflows/release.yml 'release_subdirectory=g55'
require_text .github/workflows/release.yml \
    'release_tag="v${COPYLASSO_G28_VERSION}-g55.${GITHUB_RUN_ID}${GITHUB_RUN_ATTEMPT}"'
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
    fail "Protected candidate tooling must remain draft-only and immutable."
fi

publication_feed_step="$(/usr/bin/sed -n \
    '/- name: Prepare feed-only deployment bundle/,/- name: Create verified private final draft/p' \
    "$publication_workflow")"
[[ "$publication_feed_step" == *'source ./scripts/lib/v02-publication-verification.sh'* ]] || \
    fail "The G49 feed step must use pinned v0.2.1 publication metadata."
[[ "$publication_feed_step" != *'source ./scripts/lib/release-metadata.sh'* ]] || \
    fail "The G49 feed step must not use mutable current release metadata."
require_text scripts/lib/v02-publication-verification.sh \
    'COPYLASSO_RELEASE_APPCAST="CopyLasso-0.2.1-appcast.xml"'
require_text scripts/lib/v020-release-package-metadata.sh \
    'COPYLASSO_RELEASE_APPCAST="CopyLasso-0.2.0-appcast.xml"'
require_text scripts/lib/release-package-verification.sh \
    'COPYLASSO_RELEASE_PACKAGE_METADATA_PROFILE:-current'
require_text scripts/verify-release-package.sh '--pinned-v02-metadata'
if /usr/bin/grep -Fq -- '--pinned-v02-metadata' \
    "$repository_root/scripts/verify-v02-candidate-package.sh"; then
    fail "The candidate verifier must use current package metadata."
fi

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
    '"version" : "2.9.5"'

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
require_text scripts/audit-g49-publication.sh 'COPYLASSO_V02_FINAL_TAG="v0.2.1"'
require_text scripts/lib/v02-publication-verification.sh \
    'COPYLASSO_RELEASE_VERSION="0.2.1"'
require_text scripts/lib/v02-publication-verification.sh \
    'COPYLASSO_RELEASE_DMG="CopyLasso-0.2.1.dmg"'
require_text docs/v0.2-release-state.md '- Release ID: `367570430`'

echo "CopyLasso G48 patch qualification audit passed."
