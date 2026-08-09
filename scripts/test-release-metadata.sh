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

[[ "$COPYLASSO_RELEASE_VERSION" == "0.2.1" ]] || \
    fail "The G48 candidate source must use version 0.2.1."
[[ "$COPYLASSO_RELEASE_BUILD" == "4" ]] || \
    fail "The G48 candidate source must use build 4."
[[ "$COPYLASSO_RELEASE_TAG" == "v0.2.1" ]] || \
    fail "The G48 release tag must derive as v0.2.1."
[[ "$COPYLASSO_RELEASE_DMG" == "CopyLasso-0.2.1.dmg" ]] || \
    fail "The G48 release DMG name is incorrect."
[[ "$COPYLASSO_RELEASE_CHECKSUM" == "CopyLasso-0.2.1.dmg.sha256" ]] || \
    fail "The G48 release checksum name is incorrect."
[[ "$COPYLASSO_RELEASE_DSYM" == "CopyLasso-0.2.1.dSYM.zip" ]] || \
    fail "The G48 release dSYM name is incorrect."
[[ "$COPYLASSO_RELEASE_VERIFICATION" == "CopyLasso-0.2.1-verification.zip" ]] || \
    fail "The G48 release verification-bundle name is incorrect."
[[ "$COPYLASSO_RELEASE_APPCAST" == "CopyLasso-0.2.1-appcast.xml" ]] || \
    fail "The G48 authenticated draft appcast name is incorrect."

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

[[ -r "$repository_root/docs/release-notes/0.2.0.md" ]] || \
    fail "Reviewed 0.2.0 release notes are missing."
[[ -r "$repository_root/docs/release-notes/0.2.1.md" ]] || \
    fail "Reviewed 0.2.1 release notes are missing."
/usr/bin/grep -Fq '## 0.2.0 - 2026-07-29' "$repository_root/CHANGELOG.md" || \
    fail "The changelog must date the public v0.2 release from its publication timestamp."
/usr/bin/grep -Fq '## 0.1.1 - 2026-07-21' "$repository_root/CHANGELOG.md" || \
    fail "The changelog must date the published 0.1.1 hotfix entry."
/usr/bin/grep -Fq 'User-controlled secure updates' \
    "$repository_root/docs/release-notes/0.2.0.md" || \
    fail "The 0.2.0 notes must describe the updater."
/usr/bin/grep -Fq '| Build number | `4` |' \
    "$repository_root/docs/architecture/build-configuration.md" || \
    fail "The build-configuration reference must identify build 4."

(
    # shellcheck source=scripts/lib/developer-id-verification.sh
    source "$repository_root/scripts/lib/developer-id-verification.sh"
    [[ "$COPYLASSO_RELEASE_VERSION" == "0.2.1" && \
        "$COPYLASSO_RELEASE_BUILD" == "4" ]]
) || fail "Developer ID verification must use the shared release metadata."

(
    # shellcheck source=scripts/lib/release-package-verification.sh
    source "$repository_root/scripts/lib/release-package-verification.sh"
    [[ "$COPYLASSO_RELEASE_VERSION" == "0.2.1" && \
        "$COPYLASSO_RELEASE_BUILD" == "4" && \
        "$COPYLASSO_RELEASE_DMG" == "CopyLasso-0.2.1.dmg" ]]
) || fail "Release-package verification must use the shared release metadata."

(
    # shellcheck source=scripts/lib/release-workflow-verification.sh
    source "$repository_root/scripts/lib/release-workflow-verification.sh"
    [[ "$(release_candidate_tag 1)" == "v0.2.1-rc.1" ]]
) || fail "The protected workflow must derive candidates from shared release metadata."

echo "CopyLasso release metadata contract passed."
