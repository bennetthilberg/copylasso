#!/bin/bash

if [[ "${COPYLASSO_V02_PUBLICATION_TRANSACTION_LOADED:-}" == "1" ]]; then
    return 0
fi

readonly COPYLASSO_V02_PUBLICATION_TRANSACTION_LOADED=1

create_v02_publication_draft_transaction() (
    set -euo pipefail

    local repository="$1"
    local candidate_directory="$2"
    local release_notes="$3"
    local readback="$4"
    local gh_binary="$5"
    local final_assertion="${6:-assert_v02_publication_draft_record}"
    local publication_transaction_directory
    local creation_record
    local release_listing
    local latest_release_record
    local final_release_lookup
    local final_tag_lookup
    local final_record
    local release_identifier=""
    local draft_committed="false"
    local existing_release_count
    local upload_succeeded

    publication_transaction_directory="$(/usr/bin/mktemp -d \
        "${TMPDIR:-/private/tmp}/copylasso-g43-draft.XXXXXX")"
    creation_record="$publication_transaction_directory/created.json"
    release_listing="$publication_transaction_directory/releases.json"
    latest_release_record="$publication_transaction_directory/latest-release.json"
    final_release_lookup="$publication_transaction_directory/final-release-lookup.txt"
    final_tag_lookup="$publication_transaction_directory/final-tag-lookup.txt"
    final_record="$publication_transaction_directory/final.json"
    COPYLASSO_G43_TRANSACTION_REPOSITORY="$repository"
    COPYLASSO_G43_TRANSACTION_GH_BINARY="$gh_binary"
    COPYLASSO_G43_TRANSACTION_DIRECTORY="$publication_transaction_directory"
    COPYLASSO_G43_TRANSACTION_RELEASE_IDENTIFIER=""
    COPYLASSO_G43_TRANSACTION_COMMITTED="false"
    COPYLASSO_G43_TRANSACTION_OWNS_DRAFT="false"

    cleanup_v02_publication_draft_transaction() {
        if [[ -n "$COPYLASSO_G43_TRANSACTION_RELEASE_IDENTIFIER" &&
            "$COPYLASSO_G43_TRANSACTION_COMMITTED" != "true" &&
            "$COPYLASSO_G43_TRANSACTION_OWNS_DRAFT" == "true" ]]; then
            local release_path
            release_path="repos/$COPYLASSO_G43_TRANSACTION_REPOSITORY/releases/$COPYLASSO_G43_TRANSACTION_RELEASE_IDENTIFIER"
            "$COPYLASSO_G43_TRANSACTION_GH_BINARY" api \
                --method DELETE \
                "$release_path" \
                >/dev/null 2>&1 || true
        fi
        /bin/rm -rf "$COPYLASSO_G43_TRANSACTION_DIRECTORY"
    }
    trap cleanup_v02_publication_draft_transaction EXIT

    read_all_v02_publication_releases() {
        if ! "$gh_binary" api \
            --paginate \
            --slurp \
            "repos/$repository/releases?per_page=100" > "$release_listing"; then
            v02_publication_fail "Existing releases could not be checked before G43 mutation."
        fi
        /usr/bin/jq -e '
            type == "array" and all(.[]; type == "array")
        ' "$release_listing" >/dev/null 2>&1 || \
            v02_publication_fail "The existing-release listing is invalid."
    }

    assert_v02_publication_resource_absent() {
        local endpoint="$1"
        local response="$2"
        local existing_message="$3"
        local lookup_message="$4"
        local status_line

        if "$gh_binary" api --include "$endpoint" > "$response" 2>/dev/null; then
            v02_publication_fail "$existing_message"
        fi
        status_line="$(/usr/bin/sed -n '1{s/\r$//;p;}' "$response")"
        [[ "$status_line" =~ ^HTTP/[0-9.]+[[:space:]]+404([[:space:]]|$) ]] || \
            v02_publication_fail "$lookup_message"
    }

    assert_v02_publication_resource_absent \
        "repos/$repository/releases/tags/$COPYLASSO_V02_FINAL_TAG" \
        "$final_release_lookup" \
        "A release already exists for the final v0.2 tag." \
        "The final v0.2 release could not be checked."
    if ! "$gh_binary" api \
        "repos/$repository/releases/latest" > "$latest_release_record"; then
        v02_publication_fail "The latest public release could not be checked."
    fi
    assert_v02_prepublication_latest_record "$latest_release_record"
    read_all_v02_publication_releases
    existing_release_count="$(/usr/bin/jq -er \
        --arg tag "$COPYLASSO_V02_FINAL_TAG" '
        [.[][] | select(.tag_name == $tag)] | length
    ' "$release_listing" 2>/dev/null)" || \
        v02_publication_fail "The existing-release listing is invalid."
    [[ "$existing_release_count" == "0" ]] || \
        v02_publication_fail "A release already exists for the final v0.2 tag."
    assert_v02_publication_resource_absent \
        "repos/$repository/git/ref/tags/$COPYLASSO_V02_FINAL_TAG" \
        "$final_tag_lookup" \
        "The final v0.2 tag already exists." \
        "The final v0.2 tag could not be checked."

    if ! "$gh_binary" api \
        --method POST \
        "repos/$repository/releases" \
        -f "tag_name=$COPYLASSO_V02_FINAL_TAG" \
        -f "target_commitish=$COPYLASSO_V02_CANDIDATE_COMMIT" \
        -f "name=$COPYLASSO_V02_RELEASE_NAME" \
        -F draft=true \
        -F prerelease=false \
        -f make_latest=false \
        -F "body=@$release_notes" \
        > "$creation_record"; then
        read_all_v02_publication_releases
        if ! /usr/bin/jq -er \
            --arg tag "$COPYLASSO_V02_FINAL_TAG" \
            --arg commit "$COPYLASSO_V02_CANDIDATE_COMMIT" \
            --arg name "$COPYLASSO_V02_RELEASE_NAME" \
            --rawfile body "$release_notes" '
            [.[][] | select(
                .tag_name == $tag
                and .target_commitish == $commit
                and .name == $name
                and .body == $body
                and .draft == true
                and .prerelease == false
                and .published_at == null
                and (.assets | length) == 0
            )]
            | if length == 1 then .[0] else error("ambiguous draft creation") end
        ' "$release_listing" > "$creation_record" 2>/dev/null; then
            v02_publication_fail \
                "The final v0.2 draft could not be created or identified through exact readback."
        fi
    else
        COPYLASSO_G43_TRANSACTION_OWNS_DRAFT="true"
    fi

    release_identifier="$(/usr/bin/jq -er '
        if (.id | type) == "number" and .id > 0 then .id else error("invalid id") end
    ' "$creation_record" 2>/dev/null)" || \
        v02_publication_fail "The final v0.2 draft has no valid identifier."
    COPYLASSO_G43_TRANSACTION_RELEASE_IDENTIFIER="$release_identifier"
    assert_v02_publication_release_identity \
        "$creation_record" "$release_notes" true false
    [[ "$(/usr/bin/jq -er '.assets | length' \
        "$creation_record" 2>/dev/null || true)" == "0" ]] || \
        v02_publication_fail "The newly created final v0.2 draft was not empty."

    upload_succeeded="true"
    if ! "$gh_binary" release upload "$COPYLASSO_V02_FINAL_TAG" \
        "$candidate_directory/$COPYLASSO_RELEASE_DMG" \
        "$candidate_directory/$COPYLASSO_RELEASE_CHECKSUM" \
        --repo "$repository"; then
        upload_succeeded="false"
    fi
    if ! "$gh_binary" api \
        "repos/$repository/releases/$release_identifier" > "$final_record"; then
        v02_publication_fail "The final v0.2 draft could not be read back."
    fi
    if ! "$final_assertion" "$final_record" "$release_notes"; then
        if [[ "$upload_succeeded" == "false" ]]; then
            v02_publication_fail \
                "The final v0.2 asset upload failed and exact readback did not prove completion."
        fi
        v02_publication_fail "The final v0.2 draft failed exact readback."
    fi

    /bin/cp "$final_record" "$readback"
    /bin/chmod 600 "$readback"
    draft_committed="true"
    COPYLASSO_G43_TRANSACTION_COMMITTED="$draft_committed"
    cleanup_v02_publication_draft_transaction
    trap - EXIT
)
