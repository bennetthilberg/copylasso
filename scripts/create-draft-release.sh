#!/bin/bash

set -euo pipefail
umask 077

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/release-workflow-verification.sh
source "$repository_root/scripts/lib/release-workflow-verification.sh"

usage() {
    cat >&2 <<'TEXT'
Usage: create-draft-release.sh \
  --repository owner/repository \
  --commit <40-character-commit> \
  --tag v0.1.0-g28.<run> \
  --run-dir /path/to/release-run \
  --readback /path/to/draft-release.json
TEXT
    exit 64
}

repository=""
commit=""
tag=""
run_directory=""
readback=""
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --repository)
            [[ "$#" -ge 2 ]] || usage
            repository="$2"
            shift 2
            ;;
        --commit)
            [[ "$#" -ge 2 ]] || usage
            commit="$2"
            shift 2
            ;;
        --tag)
            [[ "$#" -ge 2 ]] || usage
            tag="$2"
            shift 2
            ;;
        --run-dir)
            [[ "$#" -ge 2 ]] || usage
            run_directory="$2"
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
[[ -n "$repository" && -n "$commit" && -n "$tag" && \
    -n "$run_directory" && -n "$readback" ]] || usage

[[ "$repository" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || \
    protected_release_fail "The GitHub repository name is invalid."
assert_full_release_commit "$commit"
assert_release_draft_tag "$tag"
readonly verification_bundle="$run_directory/$COPYLASSO_G28_VERIFICATION"
assert_release_workflow_assets "$run_directory" "$verification_bundle"
[[ -n "${GH_TOKEN:-}" ]] || protected_release_fail "The draft-release token is unavailable."

readonly gh_binary="${COPYLASSO_GH_BIN:-gh}"
readonly temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/copylasso-g28-draft.XXXXXX")"
readonly creation_record="$temporary_directory/created.json"
readonly final_record="$temporary_directory/final.json"
readonly notes="$temporary_directory/notes.md"
release_identifier=""
draft_committed="false"

rollback_draft() {
    if [[ -n "$release_identifier" && "$draft_committed" != "true" ]]; then
        "$gh_binary" api \
            --method DELETE \
            "repos/$repository/releases/$release_identifier" \
            >/dev/null 2>&1 || true
    fi
    /bin/rm -rf "$temporary_directory"
}
trap rollback_draft EXIT

if "$gh_binary" api "repos/$repository/releases/tags/$tag" >/dev/null 2>&1; then
    protected_release_fail "A release already exists for the G28 rehearsal tag."
fi

printf '%s\n\n%s\n\n%s\n' \
    'Protected G28 workflow rehearsal for CopyLasso 0.1.0.' \
    "Exact source commit: $commit" \
    'Draft only. Do not publish; G29 and G30 remain separate release gates.' \
    > "$notes"

if ! "$gh_binary" api \
    --method POST \
    "repos/$repository/releases" \
    -f "tag_name=$tag" \
    -f "target_commitish=$commit" \
    -f "name=CopyLasso 0.1.0 protected workflow rehearsal" \
    -F draft=true \
    -F prerelease=true \
    -f make_latest=false \
    -F "body=@$notes" \
    > "$creation_record"; then
    protected_release_fail "The protected draft release could not be created."
fi
release_identifier="$(/usr/bin/plutil -extract id raw -o - "$creation_record" 2>/dev/null || true)"
[[ "$release_identifier" =~ ^[0-9]+$ ]] || \
    protected_release_fail "The protected draft release has no valid identifier."

if ! "$gh_binary" release upload "$tag" \
    "$run_directory/$COPYLASSO_G28_DMG" \
    "$run_directory/$COPYLASSO_G28_CHECKSUM" \
    "$run_directory/$COPYLASSO_G28_DSYM" \
    "$verification_bundle" \
    --repo "$repository"; then
    protected_release_fail "The complete protected draft asset set could not be uploaded."
fi

if ! "$gh_binary" api "repos/$repository/releases/$release_identifier" > "$final_record"; then
    protected_release_fail "The protected draft release could not be read back."
fi
assert_release_draft_record "$final_record" "$commit" "$tag"

/bin/mkdir -p "$(dirname "$readback")"
/bin/cp "$final_record" "$readback"
draft_committed="true"
rollback_draft
trap - EXIT

echo "Protected GitHub draft release created and verified."
