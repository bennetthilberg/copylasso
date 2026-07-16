#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/release-package-verification.sh
source "$repository_root/scripts/lib/release-package-verification.sh"

usage() {
    echo "Usage: $0 /path/to/first-run /path/to/second-run" >&2
    exit 64
}

[[ "$#" == 2 ]] || usage
readonly first_run="$1"
readonly second_run="$2"

for run in "$first_run" "$second_run"; do
    [[ -d "$run" ]] || release_package_fail "A release-package run directory is missing."
    [[ -f "$run/payload-manifest.txt" ]] || \
        release_package_fail "A release-package payload manifest is missing."
    [[ -f "$run/release-evidence.txt" ]] || \
        release_package_fail "A release-package evidence record is missing."
    for artifact in \
        "$run/$COPYLASSO_RELEASE_DMG" \
        "$run/$COPYLASSO_RELEASE_CHECKSUM" \
        "$run/$COPYLASSO_RELEASE_DSYM"; do
        [[ -f "$artifact" ]] || \
            release_package_fail "A release-package artifact is missing: $(basename "$artifact")"
    done
    assert_release_artifact_names \
        "$(basename "$run/$COPYLASSO_RELEASE_DMG")" \
        "$(basename "$run/$COPYLASSO_RELEASE_CHECKSUM")" \
        "$(basename "$run/$COPYLASSO_RELEASE_DSYM")"
    assert_release_checksum \
        "$run/$COPYLASSO_RELEASE_DMG" \
        "$run/$COPYLASSO_RELEASE_CHECKSUM"
done

assert_release_payload_manifests_match \
    "$first_run/payload-manifest.txt" \
    "$second_run/payload-manifest.txt"

for key in \
    version \
    build \
    payload_commit \
    packaging_commit \
    dmg_identifier \
    dmg_filename \
    app_manifest_sha256 \
    dsym_uuid_manifest_sha256; do
    first_value="$(/usr/bin/sed -n "s/^${key}=//p" "$first_run/release-evidence.txt")"
    second_value="$(/usr/bin/sed -n "s/^${key}=//p" "$second_run/release-evidence.txt")"
    if [[ -z "$first_value" ]] || [[ "$first_value" != "$second_value" ]]; then
        release_package_fail "Release-package runs differ in normalized evidence: $key."
    fi
done

echo "Release-package runs are functionally equivalent."
