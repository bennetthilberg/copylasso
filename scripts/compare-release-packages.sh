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
readonly temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/copylasso-release-compare.XXXXXX")"
trap 'rm -rf "$temporary_directory"' EXIT

comparison_run_number=0
for run in "$first_run" "$second_run"; do
    comparison_run_number=$((comparison_run_number + 1))
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

    dsym_directory="$temporary_directory/dsym-$comparison_run_number"
    /bin/mkdir "$dsym_directory"
    if ! /usr/bin/ditto -x -k "$run/$COPYLASSO_RELEASE_DSYM" "$dsym_directory" \
        > "$temporary_directory/dsym-$comparison_run_number-expand.log" 2>&1; then
        release_package_fail "The release dSYM archive could not be expanded."
    fi
    dsym="$dsym_directory/CopyLasso.app.dSYM"
    if [[ ! -d "$dsym" || -L "$dsym" ]]; then
        release_package_fail "The release dSYM archive has an unexpected layout."
    fi
    if [[ "$(/usr/bin/find "$dsym_directory" -mindepth 1 -maxdepth 1 -print | \
        /usr/bin/wc -l | /usr/bin/tr -d ' ')" != "1" ]]; then
        release_package_fail "The release dSYM archive must contain only CopyLasso.app.dSYM."
    fi
    if ! /usr/bin/dwarfdump --uuid "$dsym" \
        > "$temporary_directory/dsym-$comparison_run_number-uuids.txt"; then
        release_package_fail "The release dSYM archive UUIDs could not be inspected."
    fi
    normalized_release_uuids "$temporary_directory/dsym-$comparison_run_number-uuids.txt" \
        > "$temporary_directory/dsym-$comparison_run_number-normalized-uuids.txt"
    if [[ ! -s "$temporary_directory/dsym-$comparison_run_number-normalized-uuids.txt" ]]; then
        release_package_fail "The release dSYM archive contains no UUID records."
    fi
    actual_dsym_uuid_hash="$(/usr/bin/shasum -a 256 \
        "$temporary_directory/dsym-$comparison_run_number-normalized-uuids.txt" | \
        /usr/bin/awk '{print $1}')"
    recorded_dsym_uuid_hash="$(/usr/bin/sed -n 's/^dsym_uuid_manifest_sha256=//p' \
        "$run/release-evidence.txt")"
    if [[ -z "$recorded_dsym_uuid_hash" ]] || \
        [[ "$recorded_dsym_uuid_hash" != "$actual_dsym_uuid_hash" ]]; then
        release_package_fail "The release evidence records the wrong dSYM UUID manifest."
    fi
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
