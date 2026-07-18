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
  (--tag v0.1.0-g28.<run> | --candidate-number <positive-integer>) \
  --run-dir /path/to/release-run \
  --readback /path/to/draft-release.json
TEXT
    exit 64
}

repository=""
commit=""
tag=""
candidate_number=""
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
        --candidate-number)
            [[ "$#" -ge 2 ]] || usage
            candidate_number="$2"
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
[[ -n "$repository" && -n "$commit" && -n "$run_directory" && -n "$readback" ]] || usage
if [[ -n "$tag" && -n "$candidate_number" ]] || \
    [[ -z "$tag" && -z "$candidate_number" ]]; then
    usage
fi

[[ "$repository" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || \
    protected_release_fail "The GitHub repository name is invalid."
assert_full_release_commit "$commit"
release_mode="rehearsal"
if [[ -n "$candidate_number" ]]; then
    assert_release_candidate_number "$candidate_number"
    tag="$(release_candidate_tag "$candidate_number")"
    release_mode="candidate"
else
    assert_release_draft_tag "$tag"
fi
readonly release_mode
readonly tag
readonly verification_bundle="$run_directory/$COPYLASSO_G28_VERIFICATION"
assert_release_workflow_assets "$run_directory" "$verification_bundle"
[[ -n "${GH_TOKEN:-}" ]] || protected_release_fail "The draft-release token is unavailable."

readonly gh_binary="${COPYLASSO_GH_BIN:-gh}"
readonly temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/copylasso-release-draft.XXXXXX")"
readonly creation_record="$temporary_directory/created.json"
readonly final_record="$temporary_directory/final.json"
readonly notes="$temporary_directory/notes.md"
readonly candidate_tag_record="$temporary_directory/tag.json"
readonly reviewed_candidate_notes="$repository_root/docs/release-notes/0.1.0.md"
release_identifier=""
candidate_tag_created="false"
draft_committed="false"

rollback_draft() {
    if [[ "$candidate_tag_created" == "true" && "$draft_committed" != "true" ]]; then
        "$gh_binary" api \
            --method DELETE \
            "repos/$repository/git/refs/tags/$tag" \
            >/dev/null 2>&1 || true
    fi
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
    if [[ "$release_mode" == "candidate" ]]; then
        protected_release_fail "A release already exists for the release-candidate tag."
    fi
    protected_release_fail "A release already exists for the G28 rehearsal tag."
fi

if [[ "$release_mode" == "candidate" ]]; then
    if "$gh_binary" api "repos/$repository/git/ref/tags/$tag" >/dev/null 2>&1; then
        protected_release_fail "A tag already exists for the release candidate."
    fi
    [[ -f "$reviewed_candidate_notes" ]] || \
        protected_release_fail "The reviewed release-candidate notes are missing."
    /bin/cp "$reviewed_candidate_notes" "$notes"
    release_name="CopyLasso 0.1.0 release candidate $candidate_number"
else
    printf '%s\n\n%s\n\n%s\n' \
        'Protected G28 workflow rehearsal for CopyLasso 0.1.0.' \
        "Exact source commit: $commit" \
        'Draft only. Do not publish; G29 and G30 remain separate release gates.' \
        > "$notes"
    release_name="CopyLasso 0.1.0 protected workflow rehearsal"
fi
readonly release_name

if ! "$gh_binary" api \
    --method POST \
    "repos/$repository/releases" \
    -f "tag_name=$tag" \
    -f "target_commitish=$commit" \
    -f "name=$release_name" \
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
    if [[ "$release_mode" == "candidate" ]]; then
        protected_release_fail "The release-candidate transaction could not upload its complete asset set."
    fi
    protected_release_fail "The complete protected draft asset set could not be uploaded."
fi

if ! "$gh_binary" api "repos/$repository/releases/$release_identifier" > "$final_record"; then
    protected_release_fail "The protected draft release could not be read back."
fi
if [[ "$release_mode" == "candidate" ]]; then
    assert_release_candidate_record \
        "$final_record" \
        "$commit" \
        "$candidate_number" \
        "$run_directory" \
        "$reviewed_candidate_notes"
    if ! "$gh_binary" api \
        --method POST \
        "repos/$repository/git/refs" \
        -f "ref=refs/tags/$tag" \
        -f "sha=$commit" \
        >/dev/null; then
        protected_release_fail "The release-candidate transaction could not create its immutable tag."
    fi
    candidate_tag_created="true"
    if ! "$gh_binary" api \
        "repos/$repository/git/ref/tags/$tag" > "$candidate_tag_record"; then
        protected_release_fail "The release-candidate transaction could not read back its tag."
    fi
    assert_release_candidate_tag_record "$candidate_tag_record" "$commit" "$tag"
    if ! "$gh_binary" api "repos/$repository/releases/$release_identifier" > "$final_record"; then
        protected_release_fail "The release-candidate transaction could not complete final readback."
    fi
    assert_release_candidate_record \
        "$final_record" \
        "$commit" \
        "$candidate_number" \
        "$run_directory" \
        "$reviewed_candidate_notes"
else
    assert_release_draft_record "$final_record" "$commit" "$tag"
fi

/bin/mkdir -p "$(dirname "$readback")"
/bin/cp "$final_record" "$readback"
draft_committed="true"
rollback_draft
trap - EXIT

echo "Protected GitHub draft release created and verified."
