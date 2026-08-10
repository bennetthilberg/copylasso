#!/bin/bash

if [[ "${COPYLASSO_V02_PUBLICATION_VERIFICATION_LOADED:-}" == "1" ]]; then
    return 0
fi

readonly COPYLASSO_V02_PUBLICATION_VERIFICATION_LOADED=1
readonly copylasso_v02_publication_root="$(
    cd "$(dirname "${BASH_SOURCE[0]}")/../.." && /bin/pwd -P
)"
readonly COPYLASSO_V02_REPOSITORY="bennetthilberg/copylasso"
readonly COPYLASSO_V02_PUBLICATION_PROFILE="${COPYLASSO_V02_PUBLICATION_PROFILE:-v0.2.1}"
case "$COPYLASSO_V02_PUBLICATION_PROFILE" in
    v0.2.1)
        readonly COPYLASSO_RELEASE_VERSION="0.2.1"
        readonly COPYLASSO_RELEASE_BUILD="4"
        readonly COPYLASSO_RELEASE_DMG="CopyLasso-0.2.1.dmg"
        readonly COPYLASSO_RELEASE_CHECKSUM="CopyLasso-0.2.1.dmg.sha256"
        readonly COPYLASSO_RELEASE_DSYM="CopyLasso-0.2.1.dSYM.zip"
        readonly COPYLASSO_RELEASE_VERIFICATION="CopyLasso-0.2.1-verification.zip"
        readonly COPYLASSO_RELEASE_APPCAST="CopyLasso-0.2.1-appcast.xml"
        readonly COPYLASSO_V02_CANDIDATE_COMMIT="813de17c739097217aad55a5a35c04ea3c73d99f"
        readonly COPYLASSO_V02_CANDIDATE_RELEASE_ID="367523470"
        readonly COPYLASSO_V02_CANDIDATE_TAG="v0.2.1-rc.1"
        readonly COPYLASSO_V02_FINAL_TAG="v0.2.1"
        readonly COPYLASSO_V02_PREVIOUS_PUBLIC_TAG="v0.2.0"
        readonly COPYLASSO_V02_FINAL_TAG_MESSAGE="CopyLasso 0.2.1"
        readonly COPYLASSO_V02_RELEASE_NAME="CopyLasso 0.2.1"
        readonly COPYLASSO_V02_NOTES_SHA256="24dd1c6c235ba0e0d0bf433e07d6b1ddd5a8c2425fa368a4fa16926eb016b503"
        readonly COPYLASSO_V02_CANDIDATE_APPCAST_SHA256="ef48b25ed3527416ba2242cae4bf3975b3c61d21790e24e0b31669a1082bf779"
        readonly COPYLASSO_V02_DMG_SIZE="3737908"
        readonly COPYLASSO_V02_DMG_SHA256="05180caa3600bcd282246297a9172517136e43e55c6e8fa192b55ba44af4a017"
        readonly COPYLASSO_V02_CHECKSUM_SIZE="86"
        readonly COPYLASSO_V02_CHECKSUM_SHA256="b9a85f82686dce479cb41247fe9fc025ec8a0d099bbc08028c4239899359b1c9"
        readonly COPYLASSO_V02_DSYM_SIZE="6315506"
        readonly COPYLASSO_V02_DSYM_SHA256="0301eecaccb9fac76c1e25d2ae1db2edc99ff42febe55bfcf6f07ef4ffcbd368"
        readonly COPYLASSO_V02_VERIFICATION_SIZE="3771716"
        readonly COPYLASSO_V02_VERIFICATION_SHA256="689aad0296e90b9aab83e198eaef0524da907d1742fbeab8078bddc823a1b108"
        readonly COPYLASSO_V02_RELEASE_NOTES="scripts/fixtures/v0.2.1-published-release-notes.md"
        readonly COPYLASSO_V02_RELEASE_PACKAGE_PROFILE="v0.2.1"
        ;;
    v0.2.2)
        readonly COPYLASSO_RELEASE_VERSION="0.2.2"
        readonly COPYLASSO_RELEASE_BUILD="5"
        readonly COPYLASSO_RELEASE_DMG="CopyLasso-0.2.2.dmg"
        readonly COPYLASSO_RELEASE_CHECKSUM="CopyLasso-0.2.2.dmg.sha256"
        readonly COPYLASSO_RELEASE_DSYM="CopyLasso-0.2.2.dSYM.zip"
        readonly COPYLASSO_RELEASE_VERIFICATION="CopyLasso-0.2.2-verification.zip"
        readonly COPYLASSO_RELEASE_APPCAST="CopyLasso-0.2.2-appcast.xml"
        readonly COPYLASSO_V02_CANDIDATE_COMMIT="81016fe43ee617b5f251564b03904137a4447266"
        readonly COPYLASSO_V02_CANDIDATE_RELEASE_ID="367632598"
        readonly COPYLASSO_V02_CANDIDATE_TAG="v0.2.2-rc.1"
        readonly COPYLASSO_V02_FINAL_TAG="v0.2.2"
        readonly COPYLASSO_V02_PREVIOUS_PUBLIC_TAG="v0.2.1"
        readonly COPYLASSO_V02_FINAL_TAG_MESSAGE="CopyLasso 0.2.2"
        readonly COPYLASSO_V02_RELEASE_NAME="CopyLasso 0.2.2"
        readonly COPYLASSO_V02_NOTES_SHA256="df42f13d9ba08fba153b3d7d7d52f828cf9874ea52eec930f249ac7566115af7"
        readonly COPYLASSO_V02_CANDIDATE_APPCAST_SHA256="d929a6dc7bc70667af0072f684cfcdf6eea79b15f3614e6ed36c1f88f3d0c27b"
        readonly COPYLASSO_V02_DMG_SIZE="3735003"
        readonly COPYLASSO_V02_DMG_SHA256="9ac432f956418dd37e04de014867a7fc20d1daeecc80f6fe1db1e9c53b19de2a"
        readonly COPYLASSO_V02_CHECKSUM_SIZE="86"
        readonly COPYLASSO_V02_CHECKSUM_SHA256="346605180b76d4959736267158138018b869d62b552b089fefdbe7aafa3031ca"
        readonly COPYLASSO_V02_DSYM_SIZE="6315502"
        readonly COPYLASSO_V02_DSYM_SHA256="a797d0053209ab4d60a8c1d25cd9f384709c9282336c84c0d291e5c187811dd8"
        readonly COPYLASSO_V02_VERIFICATION_SIZE="3772127"
        readonly COPYLASSO_V02_VERIFICATION_SHA256="657be6e3fffb0439e82b865713269300bc1177eb49cca7d0c321be15e977991d"
        readonly COPYLASSO_V02_RELEASE_NOTES="scripts/fixtures/v0.2.2-published-release-notes.md"
        readonly COPYLASSO_V02_RELEASE_PACKAGE_PROFILE="v0.2.2"
        ;;
    *)
        echo "The v0.2 publication profile is invalid." >&2
        return 1 2>/dev/null || exit 1
        ;;
esac
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
        v02_publication_fail "G49 may operate only on the reviewed CopyLasso repository."
}

assert_v02_candidate_commit() {
    local commit="$1"

    [[ "$commit" == "$COPYLASSO_V02_CANDIDATE_COMMIT" ]] || \
        v02_publication_fail "G49 may publish only the approved G48 source commit."
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
        v02_publication_fail "The private G48 release readback is unavailable."
    /usr/bin/jq -e . "$record" >/dev/null 2>&1 || \
        v02_publication_fail "The private G48 release readback is invalid."
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
        v02_publication_fail "The private G48 release identity or state is invalid."

    expected_body="$(/bin/cat "$v02_release_notes_file")"
    actual_body="$(/usr/bin/jq -er '.body' "$record" 2>/dev/null || true)"
    [[ "$actual_body" == "$expected_body" ]] || \
        v02_publication_fail "The private G48 release notes differ from the approved source."

    expected_assets="$(printf '%s\n' \
        "$COPYLASSO_RELEASE_DMG" \
        "$COPYLASSO_RELEASE_CHECKSUM" \
        "$COPYLASSO_RELEASE_DSYM" \
        "$COPYLASSO_RELEASE_VERIFICATION" | LC_ALL=C /usr/bin/sort)"
    actual_assets="$(v02_release_asset_names "$record" 2>/dev/null || true)"
    [[ "$actual_assets" == "$expected_assets" ]] || \
        v02_publication_fail "The private G48 release has an unexpected asset set."

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
        v02_publication_fail "The downloaded G48 candidate directory is unavailable."
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
        v02_publication_fail "The downloaded G48 candidate has an unexpected file set."

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
        v02_publication_fail "The G48 candidate tag readback is unavailable."
    /usr/bin/jq -e \
        --arg ref "refs/tags/$COPYLASSO_V02_CANDIDATE_TAG" \
        --arg commit "$COPYLASSO_V02_CANDIDATE_COMMIT" '
        .ref == $ref
        and .object.type == "commit"
        and .object.sha == $commit
    ' "$record" >/dev/null 2>&1 || \
        v02_publication_fail "The G48 candidate tag no longer identifies the approved source commit."
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
        v02_publication_fail "CopyLasso v0.2.0 is no longer the latest public release."
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
        and (.verification.signature | type) == "string"
        and (.verification.signature | startswith("-----BEGIN SSH SIGNATURE-----\n"))
        and (.verification.signature | endswith("-----END SSH SIGNATURE-----\n"))
        and .message == ($message + "\n" + .verification.signature)
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
        v02_publication_fail "CopyLasso v0.2.1 is not GitHub's latest public release."
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

assert_v02_sparkle_signatures() {
    local appcast="$1"
    local archive="$2"
    local application="$3"
    local application_info="$application/Contents/Info.plist"
    local public_key
    local public_key_bytes
    local enclosure_signature

    [[ -f "$appcast" && ! -L "$appcast" && -s "$appcast" ]] || \
        v02_publication_fail "The signed Sparkle appcast is unavailable."
    [[ -f "$archive" && ! -L "$archive" && -s "$archive" ]] || \
        v02_publication_fail "The signed Sparkle enclosure is unavailable."
    [[ -d "$application" && ! -L "$application" &&
        -f "$application_info" && ! -L "$application_info" ]] || \
        v02_publication_fail "The qualified CopyLasso application is unavailable."
    [[ "$(/usr/bin/plutil -extract SURequireSignedFeed raw -o - \
        "$application_info" 2>/dev/null || true)" == "true" ]] || \
        v02_publication_fail "The qualified application does not require a signed feed."

    public_key="$(
        /usr/bin/plutil -extract SUPublicEDKey raw -o - \
            "$application_info" 2>/dev/null || true
    )"
    public_key_bytes="$(
        /usr/bin/printf '%s' "$public_key" |
            /usr/bin/base64 -D 2>/dev/null |
            /usr/bin/wc -c |
            /usr/bin/tr -d ' '
    )"
    [[ "$public_key_bytes" == "32" ]] || \
        v02_publication_fail "The qualified application has an invalid Sparkle public key."
    enclosure_signature="$(
        /usr/bin/xmllint --nonet --xpath \
            'string(//*[local-name()="enclosure"]/@*[local-name()="edSignature"])' \
            "$appcast" 2>/dev/null || true
    )"
    [[ -n "$enclosure_signature" ]] || \
        v02_publication_fail "The Sparkle enclosure signature is unavailable."

    if ! (
        set -euo pipefail
        local sparkle_verification_directory
        local verifier

        sparkle_verification_directory="$(/usr/bin/mktemp -d \
            "${TMPDIR:-/private/tmp}/copylasso-g49-sparkle-verification.XXXXXX")"
        trap '/bin/rm -rf "$sparkle_verification_directory"' EXIT
        verifier="$sparkle_verification_directory/verify-sparkle-signatures"
        /usr/bin/xcrun swiftc \
            "$copylasso_v02_publication_root/scripts/lib/verify-sparkle-signatures.swift" \
            -o "$verifier" \
            > "$sparkle_verification_directory/build.log" 2>&1
        "$verifier" \
            "$public_key" \
            "$appcast" \
            "$archive" \
            "$enclosure_signature"
    ); then
        v02_publication_fail \
            "Sparkle signature verification failed against the key shipped in CopyLasso."
    fi
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
