#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly verifier="$repository_root/scripts/lib/v02-publication-verification.sh"
readonly package_verifier="$repository_root/scripts/lib/release-package-verification.sh"
readonly notes="$repository_root/scripts/fixtures/v0.2.2-published-release-notes.md"
readonly reader_notes="$repository_root/docs/release-notes/0.2.2.md"
readonly workflow="$repository_root/.github/workflows/prepare-v022-publication.yml"
readonly publication_audit="$repository_root/scripts/audit-g50-publication.sh"

fail() {
    echo "$1" >&2
    exit 1
}

for required in \
    "$verifier" \
    "$package_verifier" \
    "$notes" \
    "$reader_notes" \
    "$workflow" \
    "$publication_audit"; do
    [[ -s "$required" ]] || fail "The G50 publication fixture is missing: $required"
done

if /usr/bin/grep -Eq \
    '^readonly verifier=' "$publication_audit"; then
    fail "The G50 audit must not shadow the Sparkle signature verifier binding."
fi

v021_profile="$(COPYLASSO_V02_PUBLICATION_PROFILE=v0.2.1 /bin/bash -c '
    source "$1"
    printf "%s|%s|%s|%s|%s" \
        "$COPYLASSO_RELEASE_VERSION" \
        "$COPYLASSO_RELEASE_BUILD" \
        "$COPYLASSO_V02_CANDIDATE_TAG" \
        "$COPYLASSO_V02_FINAL_TAG" \
        "$COPYLASSO_V02_PREVIOUS_PUBLIC_TAG"
' _ "$verifier")"
[[ "$v021_profile" == '0.2.1|4|v0.2.1-rc.1|v0.2.1|v0.2.0' ]] || \
    fail "The historical v0.2.1 publication profile changed."

v022_profile="$(COPYLASSO_V02_PUBLICATION_PROFILE=v0.2.2 /bin/bash -c '
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
[[ "$v022_profile" == \
    '0.2.2|5|v0.2.2-rc.1|v0.2.2|v0.2.1|367632598|81016fe43ee617b5f251564b03904137a4447266' ]] || \
    fail "The approved v0.2.2 publication profile is not exact."

if COPYLASSO_V02_PUBLICATION_PROFILE=unreviewed /bin/bash -c \
    'source "$1"' _ "$verifier" >/dev/null 2>&1; then
    fail "An unreviewed publication profile was accepted."
fi

v022_package_profile="$(COPYLASSO_RELEASE_PACKAGE_METADATA_PROFILE=v0.2.2 \
    /bin/bash -c '
        source "$1"
        printf "%s|%s|%s|%s|%s" \
            "$COPYLASSO_RELEASE_VERSION" \
            "$COPYLASSO_RELEASE_BUILD" \
            "$COPYLASSO_RELEASE_DMG" \
            "$COPYLASSO_RELEASE_DSYM" \
            "$COPYLASSO_RELEASE_APPCAST"
    ' _ "$package_verifier")"
[[ "$v022_package_profile" == \
    '0.2.2|5|CopyLasso-0.2.2.dmg|CopyLasso-0.2.2.dSYM.zip|CopyLasso-0.2.2-appcast.xml' ]] || \
    fail "The immutable v0.2.2 package profile is not exact."

/usr/bin/cmp -s "$notes" "$reader_notes" || \
    fail "The approved v0.2.2 publication notes differ from the candidate notes."
[[ "$(/usr/bin/shasum -a 256 "$notes" | /usr/bin/awk '{print $1}')" == \
    'df42f13d9ba08fba153b3d7d7d52f828cf9874ea52eec930f249ac7566115af7' ]] || \
    fail "The approved v0.2.2 notes digest changed."

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
        fail "The protected G50 preparation workflow contains a publication path: $prohibited"
    fi
done

echo "CopyLasso G50 publication-control tests passed."
