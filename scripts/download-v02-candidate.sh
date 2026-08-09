#!/bin/bash

set -euo pipefail
umask 077

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
# shellcheck source=scripts/lib/v02-publication-verification.sh
source "$repository_root/scripts/lib/v02-publication-verification.sh"

usage() {
    cat >&2 <<'TEXT'
Usage: download-v02-candidate.sh \
  --repository bennetthilberg/copylasso \
  --output-dir /path/to/empty-destination \
  --readback /path/to/candidate-release.json \
  --tag-readback /path/to/candidate-tag.json
TEXT
    exit 64
}

repository=""
output_directory=""
readback=""
tag_readback=""
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --repository)
            [[ "$#" -ge 2 ]] || usage
            repository="$2"
            shift 2
            ;;
        --output-dir)
            [[ "$#" -ge 2 ]] || usage
            output_directory="$2"
            shift 2
            ;;
        --readback)
            [[ "$#" -ge 2 ]] || usage
            readback="$2"
            shift 2
            ;;
        --tag-readback)
            [[ "$#" -ge 2 ]] || usage
            tag_readback="$2"
            shift 2
            ;;
        *) usage ;;
    esac
done
[[ -n "$repository" && -n "$output_directory" && -n "$readback" &&
    -n "$tag_readback" ]] || usage

assert_v02_repository "$repository"
[[ -n "${GH_TOKEN:-}" ]] || \
    v02_publication_fail "The authenticated candidate-download token is unavailable."
[[ ! -e "$output_directory" && ! -L "$output_directory" ]] || \
    v02_publication_fail "The candidate download destination already exists."
[[ ! -e "$readback" && ! -L "$readback" ]] || \
    v02_publication_fail "The candidate release readback already exists."
[[ ! -e "$tag_readback" && ! -L "$tag_readback" ]] || \
    v02_publication_fail "The candidate tag readback already exists."
readonly output_parent="$(/usr/bin/dirname "$output_directory")"
readonly readback_parent="$(/usr/bin/dirname "$readback")"
readonly tag_readback_parent="$(/usr/bin/dirname "$tag_readback")"
[[ -d "$output_parent" && ! -L "$output_parent" ]] || \
    v02_publication_fail "The candidate download parent is unavailable."
[[ -d "$readback_parent" && ! -L "$readback_parent" ]] || \
    v02_publication_fail "The candidate readback parent is unavailable."
[[ -d "$tag_readback_parent" && ! -L "$tag_readback_parent" ]] || \
    v02_publication_fail "The candidate tag readback parent is unavailable."

readonly gh_binary="${COPYLASSO_GH_BIN:-gh}"
readonly temporary_directory="$(/usr/bin/mktemp -d \
    "$output_parent/.copylasso-v02-candidate.XXXXXX")"
readonly staging_directory="$temporary_directory/assets"
readonly release_record="$temporary_directory/candidate-release.json"
readonly tag_record="$temporary_directory/candidate-tag.json"
committed="false"
cleanup() {
    if [[ "$committed" != "true" ]]; then
        /bin/rm -rf "$output_directory"
        /bin/rm -f "$readback"
        /bin/rm -f "$tag_readback"
    fi
    /bin/rm -rf "$temporary_directory"
}
trap cleanup EXIT

/bin/mkdir "$staging_directory"
if ! "$gh_binary" api \
    "repos/$repository/releases/$COPYLASSO_V02_CANDIDATE_RELEASE_ID" \
    > "$release_record"; then
    v02_publication_fail "The approved private G48 release could not be read."
fi
assert_v02_candidate_release_record \
    "$release_record" \
    "$repository_root/docs/release-notes/$COPYLASSO_RELEASE_VERSION.md"
if ! "$gh_binary" api \
    "repos/$repository/git/ref/tags/$COPYLASSO_V02_CANDIDATE_TAG" \
    > "$tag_record"; then
    v02_publication_fail "The approved G48 candidate tag could not be read."
fi
assert_v02_candidate_tag_record "$tag_record"

for asset_name in \
    "$COPYLASSO_RELEASE_DMG" \
    "$COPYLASSO_RELEASE_CHECKSUM" \
    "$COPYLASSO_RELEASE_DSYM" \
    "$COPYLASSO_RELEASE_VERIFICATION"; do
    asset_identifier="$(/usr/bin/jq -er --arg name "$asset_name" '
        [.assets[] | select(.name == $name) | .id]
        | if length == 1 and (.[0] | type) == "number" and .[0] > 0
          then .[0]
          else error("invalid asset identifier")
          end
    ' "$release_record" 2>/dev/null)" || \
        v02_publication_fail "The approved asset identifier for $asset_name is invalid."
    if ! "$gh_binary" api \
        -H "Accept: application/octet-stream" \
        "repos/$repository/releases/assets/$asset_identifier" \
        > "$staging_directory/$asset_name"; then
        v02_publication_fail "The approved private asset could not be downloaded: $asset_name"
    fi
done
assert_v02_candidate_files "$staging_directory"

/bin/mv "$staging_directory" "$output_directory"
/bin/cp "$release_record" "$readback"
/bin/cp "$tag_record" "$tag_readback"
/bin/chmod 600 "$readback"
/bin/chmod 600 "$tag_readback"
committed="true"
cleanup
trap - EXIT

echo "Approved G48 candidate downloaded and verified."
