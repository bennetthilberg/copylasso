#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/release-package-verification.sh
source "$repository_root/scripts/lib/release-package-verification.sh"

usage() {
    echo "Usage: $0 --payload-app /path/to/CopyLasso.app /path/to/release-run" >&2
    exit 64
}

payload_app=""
if [[ "${1:-}" == "--payload-app" ]]; then
    [[ "$#" == 3 ]] || usage
    payload_app="$2"
    shift 2
fi
[[ "$#" == 1 && -n "$payload_app" ]] || usage

readonly run_candidate="$1"
[[ -d "$run_candidate" ]] || release_package_fail "The release-package run directory is missing."
readonly run_parent="$(cd "$(dirname "$run_candidate")" && /bin/pwd -P)"
readonly run_directory="$run_parent/$(basename "$run_candidate")"
[[ -d "$payload_app" ]] || release_package_fail "The qualified G26 payload application is missing."
readonly payload_parent="$(cd "$(dirname "$payload_app")" && /bin/pwd -P)"
readonly qualified_payload="$payload_parent/$(basename "$payload_app")"
readonly expected_team_identifier="${COPYLASSO_EXPECTED_TEAM_ID:-}"
if [[ ! "$expected_team_identifier" =~ ^[A-Z0-9]{10}$ ]]; then
    release_package_fail \
        "COPYLASSO_EXPECTED_TEAM_ID must provide the approved release team outside the repository."
fi

readonly dmg="$run_directory/$COPYLASSO_RELEASE_DMG"
readonly checksum="$run_directory/$COPYLASSO_RELEASE_CHECKSUM"
readonly dsym_zip="$run_directory/$COPYLASSO_RELEASE_DSYM"
readonly submission_record="$run_directory/notary-submission.json"
readonly diagnostic_log="$run_directory/notary-log.json"
readonly evidence_record="$run_directory/release-evidence.txt"
readonly expected_payload_manifest="$run_directory/payload-manifest.txt"

for required_file in \
    "$dmg" \
    "$checksum" \
    "$dsym_zip" \
    "$submission_record" \
    "$diagnostic_log" \
    "$evidence_record" \
    "$expected_payload_manifest"; do
    [[ -f "$required_file" ]] || \
        release_package_fail "A required release-package artifact is missing: $(basename "$required_file")"
done

assert_release_artifact_names \
    "$(basename "$dmg")" \
    "$(basename "$checksum")" \
    "$(basename "$dsym_zip")"
assert_release_checksum "$dmg" "$checksum"
assert_release_notary_records "$submission_record" "$diagnostic_log"

readonly temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/copylasso-release-verify.XXXXXX")"
readonly mount_point="$temporary_directory/mount"
mounted="false"
cleanup() {
    if [[ "$mounted" == "true" ]]; then
        /usr/bin/hdiutil detach "$mount_point" >/dev/null 2>&1 || true
    fi
    /bin/rm -rf "$temporary_directory"
}
trap cleanup EXIT

if ! "$repository_root/scripts/verify-developer-id-app.sh" --post-notarization \
    "$qualified_payload" > "$temporary_directory/payload-verification.txt"; then
    release_package_fail "The qualified G26 payload no longer passes final Developer ID verification."
fi

if ! /usr/bin/codesign --verify --strict --verbose=2 "$dmg" \
    > "$temporary_directory/dmg-codesign-verification.txt" 2>&1; then
    release_package_fail "The release disk-image signature is invalid."
fi
if ! /usr/bin/codesign --display --verbose=4 "$dmg" \
    > /dev/null 2> "$temporary_directory/dmg-signature.txt"; then
    release_package_fail "The release disk-image signature cannot be inspected."
fi
assert_release_dmg_signature \
    "$temporary_directory/dmg-signature.txt" \
    "$expected_team_identifier"

if ! xcrun stapler validate "$dmg" > "$temporary_directory/dmg-stapler.txt" 2>&1; then
    release_package_fail "The release disk image has no valid stapled notarization ticket."
fi
if ! /usr/sbin/spctl --assess --type open --context context:primary-signature \
    --verbose=4 "$dmg" > "$temporary_directory/dmg-gatekeeper.txt" 2>&1; then
    release_package_fail "Gatekeeper assessment failed for the release disk image."
fi
assert_release_dmg_gatekeeper "$temporary_directory/dmg-gatekeeper.txt"

if ! /usr/bin/hdiutil imageinfo "$dmg" > "$temporary_directory/dmg-imageinfo.txt" 2>&1; then
    release_package_fail "The release disk image cannot be inspected."
fi
assert_release_dmg_imageinfo "$temporary_directory/dmg-imageinfo.txt"

/bin/mkdir "$mount_point"
if ! /usr/bin/hdiutil attach -readonly -nobrowse -mountpoint "$mount_point" "$dmg" \
    > "$temporary_directory/dmg-attach.txt" 2>&1; then
    release_package_fail "The release disk image could not be mounted read-only."
fi
mounted="true"
if ! /usr/sbin/diskutil info "$mount_point" > "$temporary_directory/dmg-diskutil.txt" 2>&1; then
    release_package_fail "The mounted release volume could not be inspected."
fi
assert_release_read_only_mount "$temporary_directory/dmg-diskutil.txt"

assert_release_volume_layout "$mount_point"
readonly mounted_application="$mount_point/CopyLasso.app"
if ! "$repository_root/scripts/verify-developer-id-app.sh" --post-notarization \
    "$mounted_application" > "$temporary_directory/mounted-app-verification.txt"; then
    release_package_fail "The application inside the disk image failed final verification."
fi

create_release_payload_manifest "$qualified_payload" "$temporary_directory/source-payload.manifest"
create_release_payload_manifest "$mounted_application" "$temporary_directory/mounted-payload.manifest"
assert_release_payload_manifests_match \
    "$temporary_directory/source-payload.manifest" \
    "$expected_payload_manifest"
assert_release_payload_manifests_match \
    "$temporary_directory/source-payload.manifest" \
    "$temporary_directory/mounted-payload.manifest"

/usr/bin/hdiutil detach "$mount_point" > "$temporary_directory/dmg-detach.txt"
mounted="false"

/bin/mkdir "$temporary_directory/dsym"
if ! /usr/bin/ditto -x -k "$dsym_zip" "$temporary_directory/dsym"; then
    release_package_fail "The release dSYM archive could not be expanded."
fi
readonly dsym="$temporary_directory/dsym/CopyLasso.app.dSYM"
[[ -d "$dsym" ]] || release_package_fail "The release dSYM archive has an unexpected layout."
if [[ "$(/usr/bin/find "$temporary_directory/dsym" -mindepth 1 -maxdepth 1 -print | /usr/bin/wc -l | /usr/bin/tr -d ' ')" != "1" ]]; then
    release_package_fail "The release dSYM archive must contain only CopyLasso.app.dSYM."
fi
readonly executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' \
    "$qualified_payload/Contents/Info.plist")"
/usr/bin/dwarfdump --uuid "$qualified_payload/Contents/MacOS/$executable_name" \
    > "$temporary_directory/application-uuids.txt"
/usr/bin/dwarfdump --uuid "$dsym" > "$temporary_directory/dsym-uuids.txt"
assert_release_uuid_sets_match \
    "$temporary_directory/application-uuids.txt" \
    "$temporary_directory/dsym-uuids.txt"

evidence_value() {
    local key="$1"
    /usr/bin/sed -n "s/^${key}=//p" "$evidence_record"
}

readonly actual_dmg_hash="$(/usr/bin/shasum -a 256 "$dmg" | /usr/bin/awk '{print $1}')"
readonly actual_dmg_size="$(/usr/bin/stat -f '%z' "$dmg")"
readonly actual_manifest_hash="$(/usr/bin/shasum -a 256 "$expected_payload_manifest" | /usr/bin/awk '{print $1}')"
normalized_release_uuids "$temporary_directory/dsym-uuids.txt" \
    > "$temporary_directory/normalized-dsym-uuids.txt"
readonly actual_dsym_uuid_hash="$(/usr/bin/shasum -a 256 \
    "$temporary_directory/normalized-dsym-uuids.txt" | /usr/bin/awk '{print $1}')"
readonly actual_submission_identifier="$(/usr/bin/plutil -extract id raw "$submission_record")"

[[ "$(evidence_value version)" == "$COPYLASSO_RELEASE_VERSION" ]] || \
    release_package_fail "The release evidence records the wrong version."
[[ "$(evidence_value build)" == "$COPYLASSO_RELEASE_BUILD" ]] || \
    release_package_fail "The release evidence records the wrong build."
[[ "$(evidence_value dmg_identifier)" == "$COPYLASSO_RELEASE_DMG_IDENTIFIER" ]] || \
    release_package_fail "The release evidence records the wrong disk-image identifier."
[[ "$(evidence_value dmg_filename)" == "$COPYLASSO_RELEASE_DMG" ]] || \
    release_package_fail "The release evidence records the wrong disk-image filename."
[[ "$(evidence_value dmg_sha256)" == "$actual_dmg_hash" ]] || \
    release_package_fail "The release evidence records the wrong disk-image checksum."
[[ "$(evidence_value dmg_size_bytes)" == "$actual_dmg_size" ]] || \
    release_package_fail "The release evidence records the wrong disk-image size."
[[ "$(evidence_value app_manifest_sha256)" == "$actual_manifest_hash" ]] || \
    release_package_fail "The release evidence records the wrong application manifest."
[[ "$(evidence_value dsym_uuid_manifest_sha256)" == "$actual_dsym_uuid_hash" ]] || \
    release_package_fail "The release evidence records the wrong dSYM UUID manifest."
[[ "$(evidence_value notary_submission_id)" == "$actual_submission_identifier" ]] || \
    release_package_fail "The release evidence records the wrong notarization submission."
[[ "$(evidence_value payload_commit)" =~ ^[0-9a-f]{40}$ ]] || \
    release_package_fail "The release evidence has no exact payload commit."
[[ "$(evidence_value packaging_commit)" =~ ^[0-9a-f]{40}$ ]] || \
    release_package_fail "The release evidence has no exact packaging commit."
if /usr/bin/grep -Eq '=(/Users/|/private/|/tmp/)' "$evidence_record"; then
    release_package_fail "The release evidence must not contain local absolute paths."
fi

echo "CopyLasso release-package verification passed."
