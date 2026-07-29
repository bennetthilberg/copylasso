#!/bin/bash

if [[ "${COPYLASSO_V02_PUBLICATION_VERIFICATION_LOADED:-}" == "1" ]]; then
    return 0
fi

readonly COPYLASSO_V02_PUBLICATION_VERIFICATION_LOADED=1
readonly copylasso_v02_publication_root="$(
    cd "$(dirname "${BASH_SOURCE[0]}")/../.." && /bin/pwd -P
)"
# shellcheck source=scripts/lib/release-metadata.sh
source "$copylasso_v02_publication_root/scripts/lib/release-metadata.sh"

readonly COPYLASSO_V02_REPOSITORY="bennetthilberg/copylasso"
readonly COPYLASSO_V02_CANDIDATE_COMMIT="43f1d0c676b08fb24b49fc628213fede90c4ed9d"
readonly COPYLASSO_V02_CANDIDATE_RELEASE_ID="361203156"
readonly COPYLASSO_V02_CANDIDATE_TAG="v0.2.0-rc.1"
readonly COPYLASSO_V02_FINAL_TAG="v0.2.0"
readonly COPYLASSO_V02_PREVIOUS_PUBLIC_TAG="v0.1.1"
readonly COPYLASSO_V02_FINAL_TAG_MESSAGE="CopyLasso 0.2.0"
readonly COPYLASSO_V02_RELEASE_NAME="CopyLasso 0.2.0"
readonly COPYLASSO_V02_NOTES_SHA256="0b40f9524389b684124189ce743109429af97baf124e28bf1d12313eba26d807"
readonly COPYLASSO_V02_CANDIDATE_APPCAST_SHA256="a80260d6cd501ffee65ec41cbe1a232b9de662a9b41b4d78a0cd9b361bfe9fe6"
readonly COPYLASSO_V02_DMG_SIZE="3665931"
readonly COPYLASSO_V02_DMG_SHA256="697cb008cf294b32500e2ad84e5777a51fe8b88916856c5a8e9f1ec4eb74ba19"
readonly COPYLASSO_V02_CHECKSUM_SIZE="86"
readonly COPYLASSO_V02_CHECKSUM_SHA256="6dfd44d92f6af1c14d765bc6c827ed3e9a0edd5ffe289c3e74ac6e1dd0c834b0"
readonly COPYLASSO_V02_DSYM_SIZE="6094121"
readonly COPYLASSO_V02_DSYM_SHA256="b644da8776f857c1f42a95f903b315b7dde418000d173b48829c5ee346bc4754"
readonly COPYLASSO_V02_VERIFICATION_SIZE="3708469"
readonly COPYLASSO_V02_VERIFICATION_SHA256="e4d424bdd9675b00ffa647bccdc3f3bc47b43b4d041535c0898f79cf79e3a073"
readonly COPYLASSO_V02_PUBLIC_APPCAST_NAME="appcast.xml"
readonly COPYLASSO_V02_FEED_HOST="updates.copylasso.com"
readonly COPYLASSO_V02_FEED_URL="https://$COPYLASSO_V02_FEED_HOST/$COPYLASSO_V02_PUBLIC_APPCAST_NAME"
readonly COPYLASSO_V02_DOWNLOAD_URL="https://github.com/$COPYLASSO_V02_REPOSITORY/releases/download/$COPYLASSO_V02_FINAL_TAG/$COPYLASSO_RELEASE_DMG"

v02_publication_fail() {
    echo "$1" >&2
    exit 1
}

assert_v02_repository() {
    local repository="$1"

    [[ "$repository" == "$COPYLASSO_V02_REPOSITORY" ]] || \
        v02_publication_fail "G43 may operate only on the reviewed CopyLasso repository."
}

assert_v02_candidate_commit() {
    local commit="$1"

    [[ "$commit" == "$COPYLASSO_V02_CANDIDATE_COMMIT" ]] || \
        v02_publication_fail "G43 may publish only the approved G42 source commit."
}

assert_v02_final_tag() {
    local tag="$1"

    [[ "$tag" == "$COPYLASSO_V02_FINAL_TAG" ]] || \
        v02_publication_fail "The final v0.2 release tag is invalid."
}

assert_v02_release_notes() {
    local v02_release_notes_file="$1"
    local digest

    [[ -f "$v02_release_notes_file" && ! -L "$v02_release_notes_file" &&
        -s "$v02_release_notes_file" ]] || \
        v02_publication_fail "The approved v0.2 release notes are unavailable."
    digest="$(/usr/bin/shasum -a 256 "$v02_release_notes_file" | \
        /usr/bin/awk '{print $1}')"
    [[ "$digest" == "$COPYLASSO_V02_NOTES_SHA256" ]] || \
        v02_publication_fail "The v0.2 release notes differ from the approved candidate."
}

assert_v02_exact_file() {
    local file="$1"
    local expected_size="$2"
    local expected_digest="$3"
    local description="$4"
    local actual_size
    local actual_digest

    [[ -f "$file" && ! -L "$file" ]] || \
        v02_publication_fail "$description is unavailable."
    actual_size="$(/usr/bin/stat -f '%z' "$file")"
    [[ "$actual_size" == "$expected_size" ]] || \
        v02_publication_fail "$description has the wrong size."
    actual_digest="$(/usr/bin/shasum -a 256 "$file" | /usr/bin/awk '{print $1}')"
    [[ "$actual_digest" == "$expected_digest" ]] || \
        v02_publication_fail "$description has the wrong SHA-256 digest."
}

v02_release_asset_names() {
    local record="$1"

    /usr/bin/jq -er '.assets | map(.name) | sort | .[]' "$record" 2>/dev/null
}

assert_v02_asset_record() {
    local record="$1"
    local name="$2"
    local expected_size="$3"
    local expected_digest="$4"

    /usr/bin/jq -e \
        --arg name "$name" \
        --argjson size "$expected_size" \
        --arg digest "sha256:$expected_digest" '
        [.assets[] | select(.name == $name)] as $matches
        | ($matches | length) == 1
        and $matches[0].size == $size
        and $matches[0].digest == $digest
        and (($matches[0].state // "uploaded") == "uploaded")
    ' "$record" >/dev/null 2>&1 || \
        v02_publication_fail "The GitHub asset record for $name differs from the approved bytes."
}

assert_v02_candidate_release_record() {
    local record="$1"
    local v02_release_notes_file="$2"
    local expected_assets
    local actual_assets
    local expected_body
    local actual_body

    [[ -f "$record" && ! -L "$record" ]] || \
        v02_publication_fail "The private G42 release readback is unavailable."
    /usr/bin/jq -e . "$record" >/dev/null 2>&1 || \
        v02_publication_fail "The private G42 release readback is invalid."
    assert_v02_release_notes "$v02_release_notes_file"

    /usr/bin/jq -e \
        --argjson id "$COPYLASSO_V02_CANDIDATE_RELEASE_ID" \
        --arg tag "$COPYLASSO_V02_CANDIDATE_TAG" \
        --arg commit "$COPYLASSO_V02_CANDIDATE_COMMIT" '
        .id == $id
        and .draft == true
        and .prerelease == true
        and .published_at == null
        and .tag_name == $tag
        and .target_commitish == $commit
    ' "$record" >/dev/null 2>&1 || \
        v02_publication_fail "The private G42 release identity or state is invalid."

    expected_body="$(/bin/cat "$v02_release_notes_file")"
    actual_body="$(/usr/bin/jq -er '.body' "$record" 2>/dev/null || true)"
    [[ "$actual_body" == "$expected_body" ]] || \
        v02_publication_fail "The private G42 release notes differ from the approved source."

    expected_assets="$(printf '%s\n' \
        "$COPYLASSO_RELEASE_DMG" \
        "$COPYLASSO_RELEASE_CHECKSUM" \
        "$COPYLASSO_RELEASE_DSYM" \
        "$COPYLASSO_RELEASE_VERIFICATION" | LC_ALL=C /usr/bin/sort)"
    actual_assets="$(v02_release_asset_names "$record" 2>/dev/null || true)"
    [[ "$actual_assets" == "$expected_assets" ]] || \
        v02_publication_fail "The private G42 release has an unexpected asset set."

    assert_v02_asset_record \
        "$record" "$COPYLASSO_RELEASE_DMG" \
        "$COPYLASSO_V02_DMG_SIZE" "$COPYLASSO_V02_DMG_SHA256"
    assert_v02_asset_record \
        "$record" "$COPYLASSO_RELEASE_CHECKSUM" \
        "$COPYLASSO_V02_CHECKSUM_SIZE" "$COPYLASSO_V02_CHECKSUM_SHA256"
    assert_v02_asset_record \
        "$record" "$COPYLASSO_RELEASE_DSYM" \
        "$COPYLASSO_V02_DSYM_SIZE" "$COPYLASSO_V02_DSYM_SHA256"
    assert_v02_asset_record \
        "$record" "$COPYLASSO_RELEASE_VERIFICATION" \
        "$COPYLASSO_V02_VERIFICATION_SIZE" "$COPYLASSO_V02_VERIFICATION_SHA256"
}

assert_v02_candidate_files() {
    local directory="$1"
    local expected_names
    local actual_names
    local expected_checksum
    local actual_checksum

    [[ -d "$directory" && ! -L "$directory" ]] || \
        v02_publication_fail "The downloaded G42 candidate directory is unavailable."
    expected_names="$(printf '%s\n' \
        "$COPYLASSO_RELEASE_DMG" \
        "$COPYLASSO_RELEASE_CHECKSUM" \
        "$COPYLASSO_RELEASE_DSYM" \
        "$COPYLASSO_RELEASE_VERIFICATION" | LC_ALL=C /usr/bin/sort)"
    actual_names="$({
        /usr/bin/find "$directory" -mindepth 1 -maxdepth 1 -print |
            while IFS= read -r file; do
                [[ -f "$file" && ! -L "$file" ]] || \
                    v02_publication_fail "The downloaded candidate contains an unsupported entry."
                /usr/bin/basename "$file"
            done | LC_ALL=C /usr/bin/sort
    })"
    [[ "$actual_names" == "$expected_names" ]] || \
        v02_publication_fail "The downloaded G42 candidate has an unexpected file set."

    assert_v02_exact_file \
        "$directory/$COPYLASSO_RELEASE_DMG" \
        "$COPYLASSO_V02_DMG_SIZE" "$COPYLASSO_V02_DMG_SHA256" \
        "The approved v0.2 disk image"
    assert_v02_exact_file \
        "$directory/$COPYLASSO_RELEASE_CHECKSUM" \
        "$COPYLASSO_V02_CHECKSUM_SIZE" "$COPYLASSO_V02_CHECKSUM_SHA256" \
        "The approved v0.2 checksum"
    assert_v02_exact_file \
        "$directory/$COPYLASSO_RELEASE_DSYM" \
        "$COPYLASSO_V02_DSYM_SIZE" "$COPYLASSO_V02_DSYM_SHA256" \
        "The restricted v0.2 dSYM"
    assert_v02_exact_file \
        "$directory/$COPYLASSO_RELEASE_VERIFICATION" \
        "$COPYLASSO_V02_VERIFICATION_SIZE" "$COPYLASSO_V02_VERIFICATION_SHA256" \
        "The restricted v0.2 verification bundle"

    expected_checksum="$COPYLASSO_V02_DMG_SHA256  $COPYLASSO_RELEASE_DMG"
    actual_checksum="$(/bin/cat "$directory/$COPYLASSO_RELEASE_CHECKSUM")"
    [[ "$actual_checksum" == "$expected_checksum" ]] || \
        v02_publication_fail "The approved checksum does not name the approved disk image."
}

assert_v02_public_assets() {
    local directory="$1"

    [[ -d "$directory" && ! -L "$directory" ]] || \
        v02_publication_fail "The v0.2 publication asset directory is unavailable."
    assert_v02_exact_file \
        "$directory/$COPYLASSO_RELEASE_DMG" \
        "$COPYLASSO_V02_DMG_SIZE" "$COPYLASSO_V02_DMG_SHA256" \
        "The approved public v0.2 disk image"
    assert_v02_exact_file \
        "$directory/$COPYLASSO_RELEASE_CHECKSUM" \
        "$COPYLASSO_V02_CHECKSUM_SIZE" "$COPYLASSO_V02_CHECKSUM_SHA256" \
        "The approved public v0.2 checksum"
}

assert_v02_publication_release_identity() {
    local record="$1"
    local v02_release_notes_file="$2"
    local expected_draft="$3"
    local expected_published="$4"
    local expected_body
    local actual_body

    [[ -f "$record" && ! -L "$record" ]] || \
        v02_publication_fail "The final v0.2 GitHub release readback is unavailable."
    /usr/bin/jq -e . "$record" >/dev/null 2>&1 || \
        v02_publication_fail "The final v0.2 GitHub release readback is invalid."
    assert_v02_release_notes "$v02_release_notes_file"

    /usr/bin/jq -e \
        --arg tag "$COPYLASSO_V02_FINAL_TAG" \
        --arg commit "$COPYLASSO_V02_CANDIDATE_COMMIT" \
        --arg name "$COPYLASSO_V02_RELEASE_NAME" \
        --argjson draft "$expected_draft" \
        --argjson published "$expected_published" '
        (.id | type) == "number"
        and .id > 0
        and .draft == $draft
        and .prerelease == false
        and .tag_name == $tag
        and .target_commitish == $commit
        and .name == $name
        and (
            if $published
            then (.published_at | type) == "string" and (.published_at | length) > 0
            else .published_at == null
            end
        )
    ' "$record" >/dev/null 2>&1 || \
        v02_publication_fail "The final v0.2 GitHub release identity or state is invalid."

    expected_body="$(/bin/cat "$v02_release_notes_file")"
    actual_body="$(/usr/bin/jq -er '.body' "$record" 2>/dev/null || true)"
    [[ "$actual_body" == "$expected_body" ]] || \
        v02_publication_fail "The final v0.2 GitHub release notes differ from the approved source."
}

assert_v02_publication_release_record() {
    local record="$1"
    local v02_release_notes_file="$2"
    local expected_draft="$3"
    local expected_published="$4"
    local expected_assets
    local actual_assets

    assert_v02_publication_release_identity \
        "$record" "$v02_release_notes_file" "$expected_draft" "$expected_published"

    expected_assets="$(printf '%s\n' \
        "$COPYLASSO_RELEASE_DMG" \
        "$COPYLASSO_RELEASE_CHECKSUM" | LC_ALL=C /usr/bin/sort)"
    actual_assets="$(v02_release_asset_names "$record" 2>/dev/null || true)"
    [[ "$actual_assets" == "$expected_assets" ]] || \
        v02_publication_fail "The final v0.2 GitHub release must contain exactly two uploaded assets."
    assert_v02_asset_record \
        "$record" "$COPYLASSO_RELEASE_DMG" \
        "$COPYLASSO_V02_DMG_SIZE" "$COPYLASSO_V02_DMG_SHA256"
    assert_v02_asset_record \
        "$record" "$COPYLASSO_RELEASE_CHECKSUM" \
        "$COPYLASSO_V02_CHECKSUM_SIZE" "$COPYLASSO_V02_CHECKSUM_SHA256"
}

assert_v02_publication_draft_record() {
    assert_v02_publication_release_record "$1" "$2" true false
}

assert_v02_public_release_record() {
    assert_v02_publication_release_record "$1" "$2" false true
}

assert_v02_candidate_tag_record() {
    local record="$1"

    [[ -f "$record" && ! -L "$record" ]] || \
        v02_publication_fail "The G42 candidate tag readback is unavailable."
    /usr/bin/jq -e \
        --arg ref "refs/tags/$COPYLASSO_V02_CANDIDATE_TAG" \
        --arg commit "$COPYLASSO_V02_CANDIDATE_COMMIT" '
        .ref == $ref
        and .object.type == "commit"
        and .object.sha == $commit
    ' "$record" >/dev/null 2>&1 || \
        v02_publication_fail "The G42 candidate tag no longer identifies the approved source commit."
}

assert_v02_prepublication_latest_record() {
    local record="$1"

    [[ -f "$record" && ! -L "$record" ]] || \
        v02_publication_fail "The latest public release readback is unavailable."
    /usr/bin/jq -e \
        --arg tag "$COPYLASSO_V02_PREVIOUS_PUBLIC_TAG" '
        .tag_name == $tag
        and .draft == false
        and .prerelease == false
        and (.published_at | type) == "string"
        and (.published_at | length) > 0
    ' "$record" >/dev/null 2>&1 || \
        v02_publication_fail "CopyLasso v0.1.1 is no longer the latest public release."
}

assert_v02_final_tag_ref_record() {
    local record="$1"

    [[ -f "$record" && ! -L "$record" ]] || \
        v02_publication_fail "The final v0.2 tag ref readback is unavailable."
    /usr/bin/jq -e \
        --arg ref "refs/tags/$COPYLASSO_V02_FINAL_TAG" '
        .ref == $ref
        and .object.type == "tag"
        and (.object.sha | test("^[0-9a-f]{40}$"))
    ' "$record" >/dev/null 2>&1 || \
        v02_publication_fail "The final v0.2 tag is not an annotated tag."
}

assert_v02_final_tag_object_record() {
    local record="$1"

    [[ -f "$record" && ! -L "$record" ]] || \
        v02_publication_fail "The final v0.2 annotated-tag readback is unavailable."
    /usr/bin/jq -e \
        --arg tag "$COPYLASSO_V02_FINAL_TAG" \
        --arg message "$COPYLASSO_V02_FINAL_TAG_MESSAGE" \
        --arg commit "$COPYLASSO_V02_CANDIDATE_COMMIT" '
        .tag == $tag
        and .message == $message
        and .object.type == "commit"
        and .object.sha == $commit
        and .verification.verified == true
        and .verification.reason == "valid"
    ' "$record" >/dev/null 2>&1 || \
        v02_publication_fail "The final v0.2 tag is not the reviewed GitHub-verified signed tag."
}

assert_v02_latest_release_record() {
    local release_record="$1"
    local latest_record="$2"
    local release_id
    local latest_id

    release_id="$(/usr/bin/jq -er '.id' "$release_record" 2>/dev/null || true)"
    latest_id="$(/usr/bin/jq -er '.id' "$latest_record" 2>/dev/null || true)"
    [[ "$release_id" =~ ^[1-9][0-9]*$ && "$latest_id" == "$release_id" ]] || \
        v02_publication_fail "CopyLasso v0.2.0 is not GitHub's latest public release."
}

assert_v02_appcast_contract() {
    local appcast="$1"
    local v02_release_notes_file="$2"
    local expected_notes
    local actual_notes
    local enclosure_xpath='//*[local-name()="enclosure"]'

    [[ -f "$appcast" && ! -L "$appcast" && -s "$appcast" ]] || \
        v02_publication_fail "The authenticated public appcast is unavailable."
    assert_v02_release_notes "$v02_release_notes_file"
    /usr/bin/xmllint --nonet --noout "$appcast" 2>/dev/null || \
        v02_publication_fail "The authenticated public appcast is not well-formed XML."
    [[ "$(/usr/bin/xmllint --nonet --xpath \
        'string(count(//*[local-name()="item"]))' "$appcast" 2>/dev/null)" == "1" ]] || \
        v02_publication_fail "The authenticated public appcast must contain exactly one update."
    [[ "$(/usr/bin/xmllint --nonet --xpath \
        'string(//*[local-name()="version"])' "$appcast" 2>/dev/null)" == \
        "$COPYLASSO_RELEASE_BUILD" ]] || \
        v02_publication_fail "The authenticated public appcast has the wrong build."
    [[ "$(/usr/bin/xmllint --nonet --xpath \
        'string(//*[local-name()="shortVersionString"])' "$appcast" 2>/dev/null)" == \
        "$COPYLASSO_RELEASE_VERSION" ]] || \
        v02_publication_fail "The authenticated public appcast has the wrong version."
    [[ "$(/usr/bin/xmllint --nonet --xpath \
        "string($enclosure_xpath/@url)" "$appcast" 2>/dev/null)" == \
        "$COPYLASSO_V02_DOWNLOAD_URL" ]] || \
        v02_publication_fail "The authenticated public appcast has the wrong enclosure URL."
    [[ "$(/usr/bin/xmllint --nonet --xpath \
        "string($enclosure_xpath/@length)" "$appcast" 2>/dev/null)" == \
        "$COPYLASSO_V02_DMG_SIZE" ]] || \
        v02_publication_fail "The authenticated public appcast has the wrong enclosure length."
    [[ -n "$(/usr/bin/xmllint --nonet --xpath \
        "string($enclosure_xpath/@*[local-name()=\"edSignature\"])" \
        "$appcast" 2>/dev/null)" ]] || \
        v02_publication_fail "The authenticated public appcast has no enclosure signature."
    [[ "$(/usr/bin/xmllint --nonet --xpath \
        'string(//*[local-name()="description"]/@*[local-name()="format"])' \
        "$appcast" 2>/dev/null)" == "plain-text" ]] || \
        v02_publication_fail "The authenticated public appcast must embed plain-text notes."
    [[ "$(/usr/bin/xmllint --nonet --xpath \
        'string(count(//*[local-name()="releaseNotesLink" or local-name()="fullReleaseNotesLink"]))' \
        "$appcast" 2>/dev/null)" == "0" ]] || \
        v02_publication_fail "The authenticated public appcast must not load external notes."
    if /usr/bin/grep -Fq -- "$COPYLASSO_V02_CANDIDATE_TAG" "$appcast"; then
        v02_publication_fail "The public appcast still references the private release candidate."
    fi

    expected_notes="$(/bin/cat "$v02_release_notes_file")"
    actual_notes="$(/usr/bin/xmllint --nonet --xpath \
        'string(//*[local-name()="description"])' "$appcast" 2>/dev/null || true)"
    [[ "$actual_notes" == "$expected_notes" ]] || \
        v02_publication_fail "The authenticated public appcast notes differ from the approved source."
}

assert_v02_feed_bundle() {
    local directory="$1"
    local expected_names
    local actual_names
    local expected_headers
    local actual_headers

    [[ -d "$directory" && ! -L "$directory" ]] || \
        v02_publication_fail "The updater feed deployment directory is unavailable."
    expected_names="$(printf '%s\n' '_headers' "$COPYLASSO_V02_PUBLIC_APPCAST_NAME" | \
        LC_ALL=C /usr/bin/sort)"
    actual_names="$({
        /usr/bin/find "$directory" -mindepth 1 -maxdepth 1 -print |
            while IFS= read -r file; do
                [[ -f "$file" && ! -L "$file" ]] || \
                    v02_publication_fail "The updater feed bundle contains an unsupported entry."
                /usr/bin/basename "$file"
            done | LC_ALL=C /usr/bin/sort
    })"
    [[ "$actual_names" == "$expected_names" ]] || \
        v02_publication_fail "The updater feed bundle must contain only appcast.xml and _headers."
    [[ -s "$directory/$COPYLASSO_V02_PUBLIC_APPCAST_NAME" ]] || \
        v02_publication_fail "The updater feed bundle has no appcast."

    expected_headers="$(printf '%s\n' \
        '/appcast.xml' \
        '  Cache-Control: public, max-age=300, must-revalidate, no-transform' \
        '  Content-Type: application/xml; charset=utf-8' \
        '  X-Content-Type-Options: nosniff')"
    actual_headers="$(/bin/cat "$directory/_headers")"
    [[ "$actual_headers" == "$expected_headers" ]] || \
        v02_publication_fail "The updater feed headers differ from the reviewed cache and MIME policy."
}
