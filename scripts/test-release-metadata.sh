#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly metadata="$repository_root/Configuration/ReleaseMetadata.xcconfig"
readonly metadata_library="$repository_root/scripts/lib/release-metadata.sh"

fail() {
    echo "$1" >&2
    exit 1
}

[[ -r "$metadata" ]] || fail "Release metadata source is missing."
[[ -r "$metadata_library" ]] || fail "Release metadata library is missing."

# shellcheck source=scripts/lib/release-metadata.sh
source "$metadata_library"

[[ "$COPYLASSO_RELEASE_VERSION" == "0.1.1" ]] || \
    fail "The maintenance release must use version 0.1.1."
[[ "$COPYLASSO_RELEASE_BUILD" == "2" ]] || \
    fail "The maintenance release must use build 2."
[[ "$COPYLASSO_RELEASE_TAG" == "v0.1.1" ]] || \
    fail "The maintenance release tag must be v0.1.1."
[[ "$COPYLASSO_RELEASE_DMG" == "CopyLasso-0.1.1.dmg" ]] || \
    fail "The maintenance release DMG name is incorrect."
[[ "$COPYLASSO_RELEASE_CHECKSUM" == "CopyLasso-0.1.1.dmg.sha256" ]] || \
    fail "The maintenance release checksum name is incorrect."
[[ "$COPYLASSO_RELEASE_DSYM" == "CopyLasso-0.1.1.dSYM.zip" ]] || \
    fail "The maintenance release dSYM name is incorrect."
[[ "$COPYLASSO_RELEASE_VERIFICATION" == "CopyLasso-0.1.1-verification.zip" ]] || \
    fail "The maintenance release verification-bundle name is incorrect."
[[ "$COPYLASSO_RELEASE_APPCAST" == "CopyLasso-0.1.1-appcast.xml" ]] || \
    fail "The authenticated draft appcast name is incorrect."

/usr/bin/grep -Fq '#include "ReleaseMetadata.xcconfig"' \
    "$repository_root/Configuration/Shared.xcconfig" || \
    fail "Shared Xcode configuration must include release metadata."
/usr/bin/grep -Fq 'MARKETING_VERSION = $(COPYLASSO_RELEASE_VERSION)' \
    "$metadata" || fail "Release metadata must drive MARKETING_VERSION."
/usr/bin/grep -Fq 'CURRENT_PROJECT_VERSION = $(COPYLASSO_RELEASE_BUILD)' \
    "$metadata" || fail "Release metadata must drive CURRENT_PROJECT_VERSION."

if /usr/bin/grep -Eq \
    '^[[:space:]]+(MARKETING_VERSION|CURRENT_PROJECT_VERSION)[[:space:]]*=' \
    "$repository_root/CopyLasso.xcodeproj/project.pbxproj"; then
    fail "Target build settings must not override the shared release metadata."
fi

[[ -r "$repository_root/docs/release-notes/0.1.1.md" ]] || \
    fail "Reviewed 0.1.1 release notes are missing."
/usr/bin/grep -Fq '## 0.1.1 - 2026-07-21' "$repository_root/CHANGELOG.md" || \
    fail "The changelog must date the published 0.1.1 hotfix entry."
/usr/bin/grep -Fq 'Settings now appears immediately' \
    "$repository_root/docs/release-notes/0.1.1.md" || \
    fail "The 0.1.1 notes must describe the Settings presentation fix."
/usr/bin/grep -Fq '| Build number | `2` |' \
    "$repository_root/docs/architecture/build-configuration.md" || \
    fail "The public build-configuration reference must identify build 2."

(
    # shellcheck source=scripts/lib/developer-id-verification.sh
    source "$repository_root/scripts/lib/developer-id-verification.sh"
    [[ "$COPYLASSO_RELEASE_VERSION" == "0.1.1" && \
        "$COPYLASSO_RELEASE_BUILD" == "2" ]]
) || fail "Developer ID verification must use the shared release metadata."

(
    # shellcheck source=scripts/lib/release-package-verification.sh
    source "$repository_root/scripts/lib/release-package-verification.sh"
    [[ "$COPYLASSO_RELEASE_VERSION" == "0.1.1" && \
        "$COPYLASSO_RELEASE_BUILD" == "2" && \
        "$COPYLASSO_RELEASE_DMG" == "CopyLasso-0.1.1.dmg" ]]
) || fail "Release-package verification must use the shared release metadata."

(
    # shellcheck source=scripts/lib/release-workflow-verification.sh
    source "$repository_root/scripts/lib/release-workflow-verification.sh"
    [[ "$(release_candidate_tag 1)" == "v0.1.1-rc.1" ]]
) || fail "The protected workflow must derive candidates from shared release metadata."

echo "CopyLasso release metadata contract passed."
