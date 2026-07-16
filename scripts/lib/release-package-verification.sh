#!/bin/bash

set -euo pipefail

readonly COPYLASSO_RELEASE_VERSION="0.1.0"
readonly COPYLASSO_RELEASE_BUILD="1"
readonly COPYLASSO_RELEASE_DMG="CopyLasso-0.1.0.dmg"
readonly COPYLASSO_RELEASE_CHECKSUM="CopyLasso-0.1.0.dmg.sha256"
readonly COPYLASSO_RELEASE_DSYM="CopyLasso-0.1.0.dSYM.zip"
readonly COPYLASSO_RELEASE_DMG_IDENTIFIER="io.github.bennetthilberg.copylasso.dmg"

release_package_fail() {
    echo "$1" >&2
    exit 1
}

assert_release_artifact_names() {
    local dmg_name="$1"
    local checksum_name="$2"
    local dsym_name="$3"

    if [[ "$dmg_name" != "$COPYLASSO_RELEASE_DMG" ]] || \
        [[ "$checksum_name" != "$COPYLASSO_RELEASE_CHECKSUM" ]] || \
        [[ "$dsym_name" != "$COPYLASSO_RELEASE_DSYM" ]]; then
        release_package_fail "The release artifact names must be versioned exactly for CopyLasso 0.1.0."
    fi
}

assert_release_volume_layout() {
    local volume_root="$1"
    local actual_entries
    local expected_entries

    [[ -d "$volume_root" ]] || release_package_fail "The release volume root is missing."
    actual_entries="$({
        /usr/bin/find "$volume_root" -mindepth 1 -maxdepth 1 -print | \
            while IFS= read -r entry; do /usr/bin/basename "$entry"; done | \
            LC_ALL=C /usr/bin/sort
    })"
    expected_entries="$(printf '%s\n%s' Applications CopyLasso.app)"
    if [[ "$actual_entries" != "$expected_entries" ]]; then
        release_package_fail "The release volume must contain exactly CopyLasso.app and Applications."
    fi
    [[ -d "$volume_root/CopyLasso.app" && ! -L "$volume_root/CopyLasso.app" ]] || \
        release_package_fail "CopyLasso.app must be a real directory in the release volume."
    [[ -L "$volume_root/Applications" ]] || \
        release_package_fail "Applications must be a symbolic link."
    if [[ "$(/usr/bin/readlink "$volume_root/Applications")" != "/Applications" ]]; then
        release_package_fail "The Applications link must resolve to /Applications."
    fi
}

create_release_payload_manifest() {
    local application="$1"
    local output="$2"
    local canonical_parent
    local canonical_application

    [[ -d "$application" ]] || release_package_fail "The application for the payload manifest is missing."
    canonical_parent="$(cd "$(dirname "$application")" && /bin/pwd -P)"
    canonical_application="$canonical_parent/$(basename "$application")"

    : > "$output"
    while IFS= read -r candidate; do
        local relative_path
        local mode

        if [[ "$candidate" == "$canonical_application" ]]; then
            relative_path="."
        else
            relative_path="${candidate#"$canonical_application"/}"
        fi
        mode="$(/usr/bin/stat -f '%Lp' "$candidate")"
        if [[ -L "$candidate" ]]; then
            printf 'link\t%s\t%s\t%s\n' \
                "$mode" "$relative_path" "$(/usr/bin/readlink "$candidate")" >> "$output"
        elif [[ -d "$candidate" ]]; then
            printf 'directory\t%s\t%s\n' "$mode" "$relative_path" >> "$output"
        elif [[ -f "$candidate" ]]; then
            local size
            local digest
            size="$(/usr/bin/stat -f '%z' "$candidate")"
            digest="$(/usr/bin/shasum -a 256 "$candidate" | /usr/bin/awk '{print $1}')"
            printf 'file\t%s\t%s\t%s\t%s\n' \
                "$mode" "$size" "$digest" "$relative_path" >> "$output"
        else
            release_package_fail "The application payload contains an unsupported file type."
        fi
    done < <(/usr/bin/find "$canonical_application" -print | LC_ALL=C /usr/bin/sort)
}

assert_release_payload_manifests_match() {
    local expected_manifest="$1"
    local actual_manifest="$2"

    [[ -f "$expected_manifest" && -f "$actual_manifest" ]] || \
        release_package_fail "A release payload manifest is missing."
    if ! /usr/bin/cmp -s "$expected_manifest" "$actual_manifest"; then
        release_package_fail "The packaged payload differs from the qualified G26 application."
    fi
}

assert_release_checksum() {
    local image_path="$1"
    local checksum_path="$2"
    local expected_hash
    local expected_line
    local actual_line

    [[ -f "$image_path" ]] || release_package_fail "The release disk image is missing."
    [[ -f "$checksum_path" ]] || release_package_fail "The release checksum is missing."
    if [[ "$(basename "$image_path")" != "$COPYLASSO_RELEASE_DMG" ]]; then
        release_package_fail "The checksum target must be CopyLasso-0.1.0.dmg."
    fi
    expected_hash="$(/usr/bin/shasum -a 256 "$image_path" | /usr/bin/awk '{print $1}')"
    expected_line="$expected_hash  $COPYLASSO_RELEASE_DMG"
    actual_line="$(/bin/cat "$checksum_path")"
    if [[ "$actual_line" != *"  $COPYLASSO_RELEASE_DMG" ]]; then
        release_package_fail "The checksum record must name CopyLasso-0.1.0.dmg."
    fi
    if [[ "$actual_line" != "$expected_line" ]]; then
        release_package_fail "The release disk-image checksum does not match."
    fi
}

assert_release_dmg_signature() {
    local signature_record_path="$1"
    local required_team_identifier="$2"

    [[ -f "$signature_record_path" ]] || release_package_fail "The disk-image signature record is missing."
    /usr/bin/grep -Fxq "Identifier=$COPYLASSO_RELEASE_DMG_IDENTIFIER" "$signature_record_path" || \
        release_package_fail "The release disk-image identifier is incorrect."
    /usr/bin/grep -Fq 'Authority=Developer ID Application:' "$signature_record_path" || \
        release_package_fail "The disk image is not signed with Developer ID Application."
    /usr/bin/grep -Eq '^Timestamp=.+$' "$signature_record_path" || \
        release_package_fail "The disk-image signature is missing a secure timestamp."
    /usr/bin/grep -Fxq "TeamIdentifier=$required_team_identifier" "$signature_record_path" || \
        release_package_fail "The disk-image signature does not match the approved release team."
}

assert_release_dmg_gatekeeper() {
    local gatekeeper_record_path="$1"

    [[ -f "$gatekeeper_record_path" ]] || release_package_fail "The disk-image Gatekeeper record is missing."
    /usr/bin/grep -Eq ': accepted$' "$gatekeeper_record_path" || \
        release_package_fail "Gatekeeper did not accept the release disk image."
    /usr/bin/grep -Eq '^source=(Notarized )?Developer ID$' "$gatekeeper_record_path" || \
        release_package_fail "Gatekeeper did not identify the disk image as Developer ID software."
    if /usr/bin/grep -q '^origin=' "$gatekeeper_record_path" && \
        /usr/bin/grep '^origin=' "$gatekeeper_record_path" | \
            /usr/bin/grep -Fqv 'origin=Developer ID Application:'; then
        release_package_fail "Gatekeeper reported an unexpected origin for the disk image."
    fi
}

assert_release_dmg_imageinfo() {
    local imageinfo_record_path="$1"

    [[ -f "$imageinfo_record_path" ]] || \
        release_package_fail "The disk-image format record is missing."
    /usr/bin/grep -Eq '^[[:space:]]*Format:[[:space:]]+UDZO[[:space:]]*$' \
        "$imageinfo_record_path" || \
        release_package_fail "The release disk image must use read-only UDZO format."
}

assert_release_read_only_mount() {
    local disk_record_path="$1"

    [[ -f "$disk_record_path" ]] || \
        release_package_fail "The mounted-volume record is missing."
    /usr/bin/grep -Eq 'Media Read-Only:[[:space:]]+Yes' "$disk_record_path" || \
        release_package_fail "The release disk-image media is not read-only."
    /usr/bin/grep -Eq 'Volume Read-Only:[[:space:]]+Yes' "$disk_record_path" || \
        release_package_fail "The mounted release volume is not read-only."
}

assert_release_notary_records() {
    local submission_record_path="$1"
    local diagnostic_log_path="$2"
    local submission_status
    local log_status
    local submission_identifier
    local log_identifier
    local issues

    [[ -f "$submission_record_path" && -f "$diagnostic_log_path" ]] || \
        release_package_fail "The notarization submission record or diagnostic log is missing."
    submission_status="$(/usr/bin/plutil -extract status raw "$submission_record_path" 2>/dev/null || true)"
    log_status="$(/usr/bin/plutil -extract status raw "$diagnostic_log_path" 2>/dev/null || true)"
    if [[ "$submission_status" != "Accepted" ]] || [[ "$log_status" != "Accepted" ]]; then
        release_package_fail "The disk-image notarization submission was not accepted."
    fi
    submission_identifier="$(/usr/bin/plutil -extract id raw "$submission_record_path" 2>/dev/null || true)"
    log_identifier="$(/usr/bin/plutil -extract jobId raw "$diagnostic_log_path" 2>/dev/null || true)"
    if [[ -z "$submission_identifier" ]] || [[ "$submission_identifier" != "$log_identifier" ]]; then
        release_package_fail "The notarization submission and diagnostic log do not match."
    fi
    issues="$(/usr/bin/plutil -extract issues json -o - "$diagnostic_log_path" 2>/dev/null || true)"
    if [[ "$issues" != "[]" ]] && \
        ! /usr/bin/grep -Eq '"issues"[[:space:]]*:[[:space:]]*null([[:space:]]*[,}])' \
            "$diagnostic_log_path"; then
        release_package_fail "The accepted notarization diagnostic log contains issues."
    fi
}

normalized_release_uuids() {
    local uuid_record="$1"

    /usr/bin/awk '
        /^UUID:/ {
            architecture = $3
            gsub(/[()]/, "", architecture)
            print architecture " " toupper($2)
        }
    ' "$uuid_record" | LC_ALL=C /usr/bin/sort
}

assert_release_uuid_sets_match() {
    local application_record="$1"
    local dsym_record="$2"
    local application_uuids
    local dsym_uuids

    [[ -f "$application_record" && -f "$dsym_record" ]] || \
        release_package_fail "The application or dSYM UUID record is missing."
    application_uuids="$(normalized_release_uuids "$application_record")"
    dsym_uuids="$(normalized_release_uuids "$dsym_record")"
    if [[ "$(printf '%s\n' "$application_uuids" | /usr/bin/awk '{print $1}')" != \
        "$(printf '%s\n%s' arm64 x86_64)" ]]; then
        release_package_fail "The release UUID record must contain exactly arm64 and x86_64."
    fi
    if [[ "$application_uuids" != "$dsym_uuids" ]]; then
        release_package_fail "The dSYM UUIDs do not match the release application."
    fi
}

assert_release_evidence_is_portable() {
    local evidence_record_path="$1"

    [[ -f "$evidence_record_path" ]] || \
        release_package_fail "The release evidence record is missing."
    if /usr/bin/grep -Eq '^[^=]+=/.*$' "$evidence_record_path"; then
        release_package_fail "The release evidence must not contain local absolute paths."
    fi
}

assert_release_commit_matches() {
    local label="$1"
    local expected_commit="$2"
    local evidence_commit="$3"

    [[ "$expected_commit" =~ ^[0-9a-f]{40}$ ]] || \
        release_package_fail "The expected $label commit is invalid."
    [[ "$evidence_commit" =~ ^[0-9a-f]{40}$ ]] || \
        release_package_fail "The release evidence $label commit is invalid."
    [[ "$evidence_commit" == "$expected_commit" ]] || \
        release_package_fail "The release evidence $label commit does not match the expected commit."
}
