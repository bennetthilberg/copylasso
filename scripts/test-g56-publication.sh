#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly verifier="$repository_root/scripts/lib/v02-publication-verification.sh"
readonly package_verifier="$repository_root/scripts/lib/release-package-verification.sh"
readonly notes="$repository_root/docs/release-notes/0.3.0.md"
readonly workflow="$repository_root/.github/workflows/prepare-v030-publication.yml"
readonly publication_audit="$repository_root/scripts/audit-g56-publication.sh"

fail() {
    echo "$1" >&2
    exit 1
}

for required in \
    "$verifier" \
    "$package_verifier" \
    "$notes" \
    "$workflow" \
    "$publication_audit"; do
    [[ -s "$required" ]] || fail "The G56 publication fixture is missing: $required"
done

v030_profile="$(COPYLASSO_V02_PUBLICATION_PROFILE=v0.3.0 /bin/bash -c '
    source "$1"
    printf "%s|%s|%s|%s|%s|%s|%s" \
        "$COPYLASSO_RELEASE_VERSION" \
        "$COPYLASSO_RELEASE_BUILD" \
        "$COPYLASSO_V02_CANDIDATE_TAG" \
        "$COPYLASSO_V02_FINAL_TAG" \
        "$COPYLASSO_V02_PREVIOUS_PUBLIC_TAG" \
        "$COPYLASSO_V02_CANDIDATE_RELEASE_ID" \
        "$COPYLASSO_V02_CANDIDATE_COMMIT"
' _ "$verifier")"
[[ "$v030_profile" == \
    '0.3.0|6|v0.3.0-rc.1|v0.3.0|v0.2.2|370037259|c99bec65be187c02b920b6519152ba935ec44253' ]] || \
    fail "The approved v0.3.0 publication profile is not exact."

v030_package_profile="$(COPYLASSO_RELEASE_PACKAGE_METADATA_PROFILE=v0.3.0 \
    /bin/bash -c '
        source "$1"
        printf "%s|%s|%s|%s|%s" \
            "$COPYLASSO_RELEASE_VERSION" \
            "$COPYLASSO_RELEASE_BUILD" \
            "$COPYLASSO_RELEASE_DMG" \
            "$COPYLASSO_RELEASE_DSYM" \
            "$COPYLASSO_RELEASE_APPCAST"
    ' _ "$package_verifier")"
[[ "$v030_package_profile" == \
    '0.3.0|6|CopyLasso-0.3.0.dmg|CopyLasso-0.3.0.dSYM.zip|CopyLasso-0.3.0-appcast.xml' ]] || \
    fail "The immutable v0.3.0 package profile is not exact."

[[ "$(/usr/bin/shasum -a 256 "$notes" | /usr/bin/awk '{print $1}')" == \
    'a8aa4e68c60cb001cadbdbeaf99966a331280eaff1acfc0becc28922f1dd28d0' ]] || \
    fail "The approved v0.3.0 notes digest changed."

for prohibited in \
    '${{ github.event.client_payload.' \
    'release publish' \
    'make_latest=true' \
    '--clobber' \
    'git push' \
    'git tag' \
    'wrangler' \
    'pages deploy'; do
    if /usr/bin/grep -Fq -- "$prohibited" "$workflow"; then
        fail "The protected G56 preparation workflow contains a publication path: $prohibited"
    fi
done

echo "CopyLasso G56 publication-control tests passed."
