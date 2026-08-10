#!/bin/bash

set -euo pipefail
umask 077

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
# shellcheck source=scripts/lib/v02-publication-verification.sh
source "$repository_root/scripts/lib/v02-publication-verification.sh"
# shellcheck source=scripts/lib/v02-publication-transaction.sh
source "$repository_root/scripts/lib/v02-publication-transaction.sh"

usage() {
    cat >&2 <<'TEXT'
Usage: create-v02-publication-draft.sh \
  --repository bennetthilberg/copylasso \
  --candidate-dir /path/to/downloaded/G48/assets \
  --readback /path/to/final-draft.json
TEXT
    exit 64
}

repository=""
candidate_directory=""
readback=""
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --repository)
            [[ "$#" -ge 2 ]] || usage
            repository="$2"
            shift 2
            ;;
        --candidate-dir)
            [[ "$#" -ge 2 ]] || usage
            candidate_directory="$2"
            shift 2
            ;;
        --readback)
            [[ "$#" -ge 2 ]] || usage
            readback="$2"
            shift 2
            ;;
        *) usage ;;
    esac
done
[[ -n "$repository" && -n "$candidate_directory" && -n "$readback" ]] || usage

assert_v02_repository "$repository"
assert_v02_candidate_files "$candidate_directory"
readonly release_notes="$repository_root/$COPYLASSO_V02_RELEASE_NOTES"
assert_v02_release_notes "$release_notes"
[[ -n "${GH_TOKEN:-}" ]] || \
    v02_publication_fail "The protected publication-draft token is unavailable."
[[ ! -e "$readback" && ! -L "$readback" ]] || \
    v02_publication_fail "The final publication-draft readback already exists."
readonly readback_parent="$(/usr/bin/dirname "$readback")"
[[ -d "$readback_parent" && ! -L "$readback_parent" ]] || \
    v02_publication_fail "The final publication-draft readback parent is unavailable."

readonly gh_binary="${COPYLASSO_GH_BIN:-gh}"
create_v02_publication_draft_transaction \
    "$repository" \
    "$candidate_directory" \
    "$release_notes" \
    "$readback" \
    "$gh_binary" \
    assert_v02_publication_draft_record

echo "Private final $COPYLASSO_RELEASE_VERSION publication draft created and verified."
