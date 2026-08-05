#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly audit_script="$repository_root/scripts/audit-release-workflow.sh"
readonly source_verifier="$repository_root/scripts/verify-release-workflow-source.sh"
readonly credential_preparer="$repository_root/scripts/prepare-release-keychain.sh"
readonly credential_cleanup="$repository_root/scripts/cleanup-release-keychain.sh"
readonly candidate_builder="$repository_root/scripts/build-release-candidate.sh"
readonly draft_appcast_generator="$repository_root/scripts/generate-draft-appcast.sh"
readonly draft_creator="$repository_root/scripts/create-draft-release.sh"
readonly verifier_library="$repository_root/scripts/lib/release-workflow-verification.sh"
readonly workflow="$repository_root/.github/workflows/release.yml"
readonly documentation="$repository_root/docs/release-workflow.md"
readonly qualification_documentation="$repository_root/docs/release-candidate-qualification.md"
readonly release_notes="$repository_root/docs/release-notes/0.2.0.md"

fail() {
    echo "$1" >&2
    exit 1
}

for executable in \
    "$audit_script" \
    "$source_verifier" \
    "$credential_preparer" \
    "$credential_cleanup" \
    "$candidate_builder" \
    "$draft_appcast_generator" \
    "$draft_creator"; do
    [[ -x "$executable" ]] || \
        fail "Protected-release executable is missing: $(basename "$executable")"
done

for readable in \
    "$verifier_library" \
    "$workflow" \
    "$documentation" \
    "$qualification_documentation" \
    "$release_notes"; do
    [[ -r "$readable" ]] || \
        fail "Protected-release contract file is missing: $(basename "$readable")"
done

# shellcheck source=scripts/lib/release-workflow-verification.sh
source "$verifier_library"

expect_failure() {
    local expected_message="$1"
    shift
    local output

    if output="$("$@" 2>&1)"; then
        fail "Expected command to fail: $*"
    fi
    if [[ "$output" != *"$expected_message"* ]]; then
        fail "Expected failure containing '$expected_message', received '$output'."
    fi
}

readonly temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/copylasso-g28-tests.XXXXXX")"
trap 'rm -rf "$temporary_directory"' EXIT

assert_protected_release_ref "refs/heads/main"
expect_failure "only from protected main" \
    assert_protected_release_ref "refs/heads/feature"
expect_failure "only from protected main" \
    assert_protected_release_ref "refs/tags/v0.2.0-rc.1"

assert_release_workflow_trusted_dispatch "$workflow"

/usr/bin/sed \
    's/^  repository_dispatch:/  workflow_dispatch:/' \
    "$workflow" > "$temporary_directory/branch-selectable-dispatch.yml"
expect_failure "trusted default-branch repository dispatch event" \
    assert_release_workflow_trusted_dispatch \
    "$temporary_directory/branch-selectable-dispatch.yml"

/usr/bin/sed \
    's/\[copylasso_protected_release\]/[unreviewed_release_event]/' \
    "$workflow" > "$temporary_directory/wrong-dispatch-type.yml"
expect_failure "trusted default-branch repository dispatch event" \
    assert_release_workflow_trusted_dispatch \
    "$temporary_directory/wrong-dispatch-type.yml"

readonly guarded_workflow="$temporary_directory/guarded-release.yml"
/bin/cp "$workflow" "$guarded_workflow"
assert_release_workflow_job_guard "$guarded_workflow" "quality-gate"
assert_release_workflow_job_guard "$guarded_workflow" "protected-release"

/usr/bin/awk '
    !removed && /^    if:.*refs\/heads\/main/ { removed = 1; next }
    { print }
' "$workflow" > "$temporary_directory/missing-quality-guard.yml"
printf '%s\n' \
    'decoy:' \
    '    if: ${{ github.ref == '\''refs/heads/main'\'' }}' \
    >> "$temporary_directory/missing-quality-guard.yml"
expect_failure "quality-gate must run only for refs/heads/main" \
    assert_release_workflow_job_guard \
    "$temporary_directory/missing-quality-guard.yml" \
    "quality-gate"

/usr/bin/awk '
    /^  protected-release:/ { protected_job = 1 }
    protected_job && /^    if:.*refs\/heads\/main/ { next }
    { print }
' "$workflow" > "$temporary_directory/missing-protected-guard.yml"
expect_failure "protected-release must run only for refs/heads/main" \
    assert_release_workflow_job_guard \
    "$temporary_directory/missing-protected-guard.yml" \
    "protected-release"

assert_full_release_commit "0123456789abcdef0123456789abcdef01234567"
expect_failure "full lowercase Git object identifier" \
    assert_full_release_commit "0123456789abcdef"
expect_failure "full lowercase Git object identifier" \
    assert_full_release_commit "0123456789ABCDEF0123456789ABCDEF01234567"

(
    export COPYLASSO_DEVELOPER_ID_P12_BASE64="QQ=="
    export COPYLASSO_DEVELOPER_ID_P12_PASSWORD="test-only"
    export COPYLASSO_NOTARY_KEY_BASE64="Qg=="
    export COPYLASSO_NOTARY_KEY_ID="ABCDEFGHIJ"
    export COPYLASSO_NOTARY_ISSUER_ID="00000000-0000-0000-0000-000000000000"
    export COPYLASSO_EXPECTED_TEAM_ID="0123456789"
    export COPYLASSO_RELEASE_KEYCHAIN_PASSWORD="test-only"
    assert_release_secret_contract
)
expect_failure "Developer ID certificate secret is missing" \
    assert_release_secret_contract

(
    export RUNNER_TEMP="$temporary_directory/runner"
    /bin/mkdir -p "$RUNNER_TEMP"
    assert_release_state_directory "$RUNNER_TEMP/state"
    expect_failure "under RUNNER_TEMP" \
        assert_release_state_directory "$temporary_directory/outside"
    expect_failure "parent traversal" \
        assert_release_state_directory "$RUNNER_TEMP/state/../escape"
)

readonly repository_fixture="$temporary_directory/repository"
/usr/bin/git init -q "$repository_fixture"
/usr/bin/git -C "$repository_fixture" config user.name "CopyLasso Tests"
/usr/bin/git -C "$repository_fixture" config user.email "tests@invalid.local"
printf 'protected source\n' > "$repository_fixture/source.txt"
/usr/bin/git -C "$repository_fixture" add source.txt
/usr/bin/git -C "$repository_fixture" commit -q -m "fixture"
readonly fixture_commit="$(/usr/bin/git -C "$repository_fixture" rev-parse HEAD)"
/usr/bin/git -C "$repository_fixture" update-ref refs/remotes/origin/main "$fixture_commit"
assert_release_source_state "$repository_fixture" "refs/heads/main" "$fixture_commit"
expect_failure "does not match the dispatched commit" \
    assert_release_source_state \
    "$repository_fixture" \
    "refs/heads/main" \
    "0123456789abcdef0123456789abcdef01234567"
printf 'dirty source\n' > "$repository_fixture/source.txt"
expect_failure "clean tracked checkout" \
    assert_release_source_state "$repository_fixture" "refs/heads/main" "$fixture_commit"
/usr/bin/git -C "$repository_fixture" restore source.txt
printf 'new protected main\n' > "$repository_fixture/main.txt"
/usr/bin/git -C "$repository_fixture" add main.txt
/usr/bin/git -C "$repository_fixture" commit -q -m "second fixture"
readonly second_fixture_commit="$(/usr/bin/git -C "$repository_fixture" rev-parse HEAD)"
/usr/bin/git -C "$repository_fixture" update-ref refs/remotes/origin/main "$second_fixture_commit"
/usr/bin/git -C "$repository_fixture" checkout -q --detach "$fixture_commit"
expect_failure "not the protected origin/main commit" \
    assert_release_source_state "$repository_fixture" "refs/heads/main" "$fixture_commit"

assert_release_draft_tag "v0.2.0-g42.12345"
expect_failure "draft tag name is invalid" \
    assert_release_draft_tag "v0.2.0-rc.1"

assert_release_candidate_number "1"
assert_release_candidate_number "42"
for invalid_candidate_number in "" 0 01 +1 -1 1.0 " 1" "1 " rc.1 arbitrary; do
    expect_failure "candidate number must be a positive canonical integer" \
        assert_release_candidate_number "$invalid_candidate_number"
done
[[ "$(release_candidate_tag "1")" == "v0.2.0-rc.1" ]] || \
    fail "Candidate 1 must derive the exact v0.2.0-rc.1 tag."
[[ "$(release_candidate_tag "42")" == "v0.2.0-rc.42" ]] || \
    fail "Candidate 42 must derive the exact v0.2.0-rc.42 tag."
assert_release_candidate_tag "v0.2.0-rc.1"
expect_failure "release-candidate tag name is invalid" \
    assert_release_candidate_tag "v0.2.0-g42.12345"
assert_authenticated_draft_tag "v0.2.0-rc.42"
assert_authenticated_draft_tag "v0.2.0-g42.12345"
expect_failure "authenticated update draft tag is invalid" \
    assert_authenticated_draft_tag "v0.2.0"
expect_failure "authenticated update draft tag is invalid" \
    assert_authenticated_draft_tag "v0.2.0-rc.01"

readonly valid_draft="$temporary_directory/valid-draft.json"
printf '%s\n' "{
  \"id\": 123,
  \"draft\": true,
  \"prerelease\": true,
  \"tag_name\": \"v0.2.0-g42.12345\",
  \"target_commitish\": \"0123456789abcdef0123456789abcdef01234567\",
  \"assets\": [
    {\"name\": \"CopyLasso-0.2.0.dmg\"},
    {\"name\": \"CopyLasso-0.2.0.dmg.sha256\"},
    {\"name\": \"CopyLasso-0.2.0.dSYM.zip\"},
    {\"name\": \"CopyLasso-0.2.0-verification.zip\"}
  ]
}" > "$valid_draft"
assert_release_draft_record \
    "$valid_draft" \
    "0123456789abcdef0123456789abcdef01234567" \
    "v0.2.0-g42.12345"

/usr/bin/sed 's/\"draft\": true/\"draft\": false/' \
    "$valid_draft" > "$temporary_directory/published.json"
expect_failure "not a draft" \
    assert_release_draft_record \
    "$temporary_directory/published.json" \
    "0123456789abcdef0123456789abcdef01234567" \
    "v0.2.0-g42.12345"
/usr/bin/sed '/CopyLasso-0.2.0.dSYM.zip/d' \
    "$valid_draft" > "$temporary_directory/missing-asset.json"
expect_failure "incomplete or unexpected asset set" \
    assert_release_draft_record \
    "$temporary_directory/missing-asset.json" \
    "0123456789abcdef0123456789abcdef01234567" \
    "v0.2.0-g42.12345"

printf 'Fixed content-free release diagnostic.\n' > "$temporary_directory/safe.log"
assert_release_log_is_public_safe "$temporary_directory/safe.log"
printf '%s%s\n' '-----BEGIN PRIVATE' ' KEY-----' > "$temporary_directory/private.log"
expect_failure "credential or account material" \
    assert_release_log_is_public_safe "$temporary_directory/private.log"

readonly release_run="$temporary_directory/release-run"
/bin/mkdir "$release_run"
for asset in \
    CopyLasso-0.2.0.dmg \
    CopyLasso-0.2.0.dmg.sha256 \
    CopyLasso-0.2.0.dSYM.zip \
    CopyLasso-0.2.0-verification.zip; do
    : > "$release_run/$asset"
done
assert_release_workflow_assets \
    "$release_run" \
    "$release_run/CopyLasso-0.2.0-verification.zip"
/bin/rm "$release_run/CopyLasso-0.2.0.dSYM.zip"
expect_failure "protected release asset is missing" \
    assert_release_workflow_assets \
    "$release_run" \
    "$release_run/CopyLasso-0.2.0-verification.zip"
: > "$release_run/CopyLasso-0.2.0.dSYM.zip"

printf 'qualified candidate disk image\n' > "$release_run/CopyLasso-0.2.0.dmg"
(
    cd "$release_run"
    /usr/bin/shasum -a 256 CopyLasso-0.2.0.dmg > CopyLasso-0.2.0.dmg.sha256
)
printf 'qualified candidate symbols\n' > "$release_run/CopyLasso-0.2.0.dSYM.zip"
printf 'qualified candidate verification\n' > "$release_run/CopyLasso-0.2.0-verification.zip"

readonly candidate_dmg_digest="$(/usr/bin/shasum -a 256 \
    "$release_run/CopyLasso-0.2.0.dmg" | /usr/bin/awk '{print $1}')"
readonly candidate_checksum_digest="$(/usr/bin/shasum -a 256 \
    "$release_run/CopyLasso-0.2.0.dmg.sha256" | /usr/bin/awk '{print $1}')"
readonly candidate_dsym_digest="$(/usr/bin/shasum -a 256 \
    "$release_run/CopyLasso-0.2.0.dSYM.zip" | /usr/bin/awk '{print $1}')"
readonly candidate_verification_digest="$(/usr/bin/shasum -a 256 \
    "$release_run/CopyLasso-0.2.0-verification.zip" | /usr/bin/awk '{print $1}')"
readonly valid_candidate="$temporary_directory/valid-candidate.json"
/usr/bin/jq -n \
    --rawfile body "$release_notes" \
    --arg commit "0123456789abcdef0123456789abcdef01234567" \
    --arg dmg_digest "sha256:$candidate_dmg_digest" \
    --arg checksum_digest "sha256:$candidate_checksum_digest" \
    --arg dsym_digest "sha256:$candidate_dsym_digest" \
    --arg verification_digest "sha256:$candidate_verification_digest" \
    '{
        id: 124,
        draft: true,
        prerelease: true,
        tag_name: "v0.2.0-rc.1",
        target_commitish: $commit,
        body: $body,
        assets: [
            {name: "CopyLasso-0.2.0.dmg", digest: $dmg_digest},
            {name: "CopyLasso-0.2.0.dmg.sha256", digest: $checksum_digest},
            {name: "CopyLasso-0.2.0.dSYM.zip", digest: $dsym_digest},
            {name: "CopyLasso-0.2.0-verification.zip", digest: $verification_digest}
        ]
    }' > "$valid_candidate"
assert_release_candidate_record \
    "$valid_candidate" \
    "0123456789abcdef0123456789abcdef01234567" \
    "1" \
    "$release_run" \
    "$release_notes"

/usr/bin/jq '(.assets[] | select(.name == "CopyLasso-0.2.0.dmg") | .digest) =
    "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' \
    "$valid_candidate" > "$temporary_directory/bad-candidate-digest.json"
expect_failure "uploaded release asset digest does not match" \
    assert_release_candidate_record \
    "$temporary_directory/bad-candidate-digest.json" \
    "0123456789abcdef0123456789abcdef01234567" \
    "1" \
    "$release_run" \
    "$release_notes"

/usr/bin/jq '.body = "different notes"' \
    "$valid_candidate" > "$temporary_directory/bad-candidate-notes.json"
expect_failure "release notes differ from the reviewed source" \
    assert_release_candidate_record \
    "$temporary_directory/bad-candidate-notes.json" \
    "0123456789abcdef0123456789abcdef01234567" \
    "1" \
    "$release_run" \
    "$release_notes"

printf '%064d  %s\n' 0 CopyLasso-0.2.0.dmg > \
    "$release_run/CopyLasso-0.2.0.dmg.sha256"
readonly mismatched_checksum_digest="$(/usr/bin/shasum -a 256 \
    "$release_run/CopyLasso-0.2.0.dmg.sha256" | /usr/bin/awk '{print $1}')"
/usr/bin/jq --arg digest "sha256:$mismatched_checksum_digest" '
    (.assets[] | select(.name == "CopyLasso-0.2.0.dmg.sha256") | .digest) = $digest
' "$valid_candidate" > "$temporary_directory/bad-candidate-checksum.json"
expect_failure "checksum does not match the qualified disk image" \
    assert_release_candidate_record \
    "$temporary_directory/bad-candidate-checksum.json" \
    "0123456789abcdef0123456789abcdef01234567" \
    "1" \
    "$release_run" \
    "$release_notes"
(
    cd "$release_run"
    /usr/bin/shasum -a 256 CopyLasso-0.2.0.dmg > CopyLasso-0.2.0.dmg.sha256
)

readonly valid_candidate_tag="$temporary_directory/valid-candidate-tag.json"
printf '%s\n' '{
  "ref": "refs/tags/v0.2.0-rc.1",
  "object": {
    "type": "commit",
    "sha": "0123456789abcdef0123456789abcdef01234567"
  }
}' > "$valid_candidate_tag"
assert_release_candidate_tag_record \
    "$valid_candidate_tag" \
    "0123456789abcdef0123456789abcdef01234567" \
    "v0.2.0-rc.1"
/usr/bin/sed 's/"type": "commit"/"type": "tag"/' \
    "$valid_candidate_tag" > "$temporary_directory/annotated-candidate-tag.json"
expect_failure "does not point directly to the candidate commit" \
    assert_release_candidate_tag_record \
    "$temporary_directory/annotated-candidate-tag.json" \
    "0123456789abcdef0123456789abcdef01234567" \
    "v0.2.0-rc.1"
/usr/bin/sed \
    's/0123456789abcdef0123456789abcdef01234567/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/' \
    "$valid_candidate_tag" > "$temporary_directory/wrong-candidate-tag.json"
expect_failure "does not point directly to the candidate commit" \
    assert_release_candidate_tag_record \
    "$temporary_directory/wrong-candidate-tag.json" \
    "0123456789abcdef0123456789abcdef01234567" \
    "v0.2.0-rc.1"

readonly fake_gh="$temporary_directory/gh"
readonly fake_gh_log="$temporary_directory/gh.log"
readonly fake_gh_tag_state="$temporary_directory/tag-created"
cat > "$fake_gh" <<'SCRIPT'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$FAKE_GH_LOG"
if [[ "$1" == "api" && "$*" == *"releases/tags/"* ]]; then
    if [[ "${FAKE_GH_MODE:-success}" == "preexisting-release" ]]; then
        /bin/cat "$FAKE_GH_RECORD"
        exit 0
    fi
    exit 1
fi
if [[ "$1" == "api" && "$*" == *"/releases?per_page=100"* ]]; then
    [[ "${FAKE_GH_MODE:-success}" != "release-list-fail" ]] || exit 1
    if [[ "${FAKE_GH_MODE:-success}" == "release-list-invalid" ]]; then
        printf '{}\n'
        exit 0
    fi
    if [[ "${FAKE_GH_MODE:-success}" == "preexisting-draft" ]]; then
        /usr/bin/jq -n --slurpfile release "$FAKE_GH_RECORD" '[ $release ]'
    else
        printf '[[]]\n'
    fi
    exit 0
fi
if [[ "$1" == "api" && "$*" == *"--method DELETE"* && "$*" == *"git/refs/tags/"* ]]; then
    [[ "${FAKE_GH_MODE:-success}" != "rollback-tag-delete-fail" ]] || exit 1
    /bin/rm -f "$FAKE_GH_TAG_STATE"
    exit 0
fi
if [[ "$1" == "api" && "$*" == *"--method DELETE"* ]]; then
    [[ "${FAKE_GH_MODE:-success}" != "rollback-release-delete-fail" ]] || exit 1
    exit 0
fi
if [[ "$1" == "api" && "$*" == *"git/ref/tags/"* ]]; then
    if [[ "${FAKE_GH_MODE:-success}" == "preexisting-tag" || -f "$FAKE_GH_TAG_STATE" ]]; then
        [[ "${FAKE_GH_MODE:-success}" != "tag-readback-fail" ]] || exit 1
        /bin/cat "$FAKE_GH_TAG_RECORD"
        exit 0
    fi
    exit 1
fi
if [[ "$1" == "api" && "$*" == *"--method POST"* && "$*" == *"git/refs"* ]]; then
    [[ "${FAKE_GH_MODE:-success}" != "tag-create-fail" ]] || exit 1
    [[ ! -f "$FAKE_GH_TAG_STATE" ]] || exit 1
    : > "$FAKE_GH_TAG_STATE"
    [[ "${FAKE_GH_MODE:-success}" != "tag-create-uncertain" ]] || exit 1
    /bin/cat "$FAKE_GH_TAG_RECORD"
    exit 0
fi
if [[ "$1" == "api" && "$*" == *"--method POST"* && "$*" == *"/releases"* ]]; then
    [[ "${FAKE_GH_MODE:-success}" != "release-create-fail" ]] || exit 1
    if [[ "${FAKE_GH_MODE:-success}" == "release-create-malformed" ]]; then
        printf '{"id":\n'
        exit 0
    fi
    printf '{"id":123}\n'
    exit 0
fi
if [[ "$1" == "release" && "$2" == "upload" ]]; then
    case "${FAKE_GH_MODE:-success}" in
        upload-fail | rollback-release-delete-fail | rollback-tag-delete-fail) exit 1 ;;
    esac
    exit
fi
if [[ "$1" == "api" && "$*" == *"releases/123"* ]]; then
    /bin/cat "$FAKE_GH_RECORD"
    exit 0
fi
exit 1
SCRIPT
/bin/chmod +x "$fake_gh"

export GH_TOKEN="test-only"
export COPYLASSO_GH_BIN="$fake_gh"
export FAKE_GH_LOG="$fake_gh_log"
export FAKE_GH_RECORD="$valid_draft"
export FAKE_GH_TAG_RECORD="$valid_candidate_tag"
export FAKE_GH_TAG_STATE="$fake_gh_tag_state"
export FAKE_GH_MODE="success"
"$draft_creator" \
    --repository owner/repository \
    --commit 0123456789abcdef0123456789abcdef01234567 \
    --tag v0.2.0-g42.12345 \
    --run-dir "$release_run" \
    --readback "$temporary_directory/readback.json"
assert_release_draft_record \
    "$temporary_directory/readback.json" \
    "0123456789abcdef0123456789abcdef01234567" \
    "v0.2.0-g42.12345"
if /usr/bin/grep -Fq -- '--method DELETE' "$fake_gh_log"; then
    fail "A successful draft must not be rolled back."
fi
if /usr/bin/grep -Fq -- 'git/refs' "$fake_gh_log"; then
    fail "A private rehearsal must not create or inspect a Git tag ref."
fi

: > "$fake_gh_log"
export FAKE_GH_MODE="upload-fail"
expect_failure "asset set could not be uploaded" \
    "$draft_creator" \
    --repository owner/repository \
    --commit 0123456789abcdef0123456789abcdef01234567 \
    --tag v0.2.0-g42.12345 \
    --run-dir "$release_run" \
    --readback "$temporary_directory/failed-readback.json"
/usr/bin/grep -Fq -- '--method DELETE' "$fake_gh_log" || \
    fail "A partial draft upload must delete the incomplete draft."

: > "$fake_gh_log"
/bin/rm -f "$fake_gh_tag_state"
export FAKE_GH_MODE="success"
export FAKE_GH_RECORD="$valid_candidate"
"$draft_creator" \
    --repository owner/repository \
    --commit 0123456789abcdef0123456789abcdef01234567 \
    --candidate-number 1 \
    --run-dir "$release_run" \
    --readback "$temporary_directory/candidate-readback.json"
assert_release_candidate_record \
    "$temporary_directory/candidate-readback.json" \
    "0123456789abcdef0123456789abcdef01234567" \
    "1" \
    "$release_run" \
    "$release_notes"
[[ -f "$fake_gh_tag_state" ]] || fail "The verified RC transaction must create its tag."
/usr/bin/grep -Fq -- '--method POST repos/owner/repository/git/refs' "$fake_gh_log" || \
    fail "The verified RC transaction must create its tag through the Git ref API."
/usr/bin/grep -Fq -- 'api repos/owner/repository/git/ref/tags/v0.2.0-rc.1' "$fake_gh_log" || \
    fail "The verified RC transaction must read back its owned exact tag."
tag_create_line="$(/usr/bin/grep -n -- '--method POST repos/owner/repository/git/refs' \
    "$fake_gh_log" | /usr/bin/head -n 1 | /usr/bin/cut -d: -f1)"
release_create_line="$(/usr/bin/grep -n -- '--method POST repos/owner/repository/releases' \
    "$fake_gh_log" | /usr/bin/head -n 1 | /usr/bin/cut -d: -f1)"
if [[ -z "$tag_create_line" || -z "$release_create_line" ]] || \
    ((tag_create_line >= release_create_line)); then
    fail "The RC transaction must prove tag ownership before creating its draft release."
fi
/usr/bin/grep -Fq -- \
    '--paginate --slurp repos/owner/repository/releases?per_page=100' \
    "$fake_gh_log" || fail "The verified RC transaction must inspect every existing release."
if /usr/bin/grep -Eq -- '--method (DELETE|PATCH)|--clobber|force=' "$fake_gh_log"; then
    fail "A successful RC transaction must not delete, overwrite, or force-update state."
fi

: > "$fake_gh_log"
/bin/rm -f "$fake_gh_tag_state"
export FAKE_GH_MODE="tag-create-uncertain"
expect_failure "tag creation outcome is ambiguous" \
    "$draft_creator" \
    --repository owner/repository \
    --commit 0123456789abcdef0123456789abcdef01234567 \
    --candidate-number 1 \
    --run-dir "$release_run" \
    --readback "$temporary_directory/uncertain-tag-readback.json"
[[ -f "$fake_gh_tag_state" ]] || \
    fail "An ambiguously created exact tag must be retained for manual inspection."
if /usr/bin/grep -Fq -- '--method DELETE' "$fake_gh_log"; then
    fail "An ambiguously created tag must never be deleted without proof of ownership."
fi
if /usr/bin/grep -Fq -- '--method POST repos/owner/repository/releases' "$fake_gh_log"; then
    fail "An ambiguous tag outcome must prevent draft-release creation."
fi

: > "$fake_gh_log"
/bin/rm -f "$fake_gh_tag_state"
export FAKE_GH_MODE="tag-create-fail"
expect_failure "could not create its immutable tag" \
    "$draft_creator" \
    --repository owner/repository \
    --commit 0123456789abcdef0123456789abcdef01234567 \
    --candidate-number 1 \
    --run-dir "$release_run" \
    --readback "$temporary_directory/tag-create-fail.json"
if /usr/bin/grep -Eq -- '--method (DELETE|POST) repos/owner/repository/releases' \
    "$fake_gh_log"; then
    fail "A failed tag creation must not mutate release state."
fi

: > "$fake_gh_log"
/bin/rm -f "$fake_gh_tag_state"
export FAKE_GH_MODE="release-create-fail"
expect_failure "release creation outcome is ambiguous" \
    "$draft_creator" \
    --repository owner/repository \
    --commit 0123456789abcdef0123456789abcdef01234567 \
    --candidate-number 1 \
    --run-dir "$release_run" \
    --readback "$temporary_directory/release-create-fail.json"
if /usr/bin/grep -Fq -- \
    '--method DELETE repos/owner/repository/git/refs/tags/v0.2.0-rc.1' \
    "$fake_gh_log"; then
    fail "An ambiguous release response must not delete a tag that a raced release may use."
fi
[[ -f "$fake_gh_tag_state" ]] || \
    fail "An ambiguous release response must retain the candidate tag for inspection."

: > "$fake_gh_log"
/bin/rm -f "$fake_gh_tag_state"
export FAKE_GH_MODE="release-create-malformed"
expect_failure "creation response has no valid identifier" \
    "$draft_creator" \
    --repository owner/repository \
    --commit 0123456789abcdef0123456789abcdef01234567 \
    --candidate-number 1 \
    --run-dir "$release_run" \
    --readback "$temporary_directory/release-create-malformed.json"
if /usr/bin/grep -Fq -- '--method DELETE' "$fake_gh_log"; then
    fail "A malformed successful release response must retain the tag and possible draft."
fi
[[ -f "$fake_gh_tag_state" ]] || \
    fail "A malformed successful release response must retain the candidate tag."

: > "$fake_gh_log"
/bin/rm -f "$fake_gh_tag_state"
export FAKE_GH_MODE="preexisting-release"
expect_failure "release already exists for the release-candidate tag" \
    "$draft_creator" \
    --repository owner/repository \
    --commit 0123456789abcdef0123456789abcdef01234567 \
    --candidate-number 1 \
    --run-dir "$release_run" \
    --readback "$temporary_directory/preexisting-release.json"
if /usr/bin/grep -Fq -- '--method POST' "$fake_gh_log"; then
    fail "A pre-existing release must prevent every RC mutation."
fi

for failure_mode in release-list-fail release-list-invalid; do
    : > "$fake_gh_log"
    /bin/rm -f "$fake_gh_tag_state"
    export FAKE_GH_MODE="$failure_mode"
    expect_failure "release" \
        "$draft_creator" \
        --repository owner/repository \
        --commit 0123456789abcdef0123456789abcdef01234567 \
        --candidate-number 1 \
        --run-dir "$release_run" \
        --readback "$temporary_directory/$failure_mode.json"
    if /usr/bin/grep -Fq -- '--method POST' "$fake_gh_log"; then
        fail "An unavailable or invalid release listing must prevent every RC mutation."
    fi
done

: > "$fake_gh_log"
/bin/rm -f "$fake_gh_tag_state"
export FAKE_GH_MODE="preexisting-draft"
expect_failure "release already exists for the release-candidate tag" \
    "$draft_creator" \
    --repository owner/repository \
    --commit 0123456789abcdef0123456789abcdef01234567 \
    --candidate-number 1 \
    --run-dir "$release_run" \
    --readback "$temporary_directory/preexisting-draft.json"
if /usr/bin/grep -Fq -- '--method POST' "$fake_gh_log"; then
    fail "A pre-existing draft must prevent every RC mutation."
fi

: > "$fake_gh_log"
/bin/rm -f "$fake_gh_tag_state"
export FAKE_GH_MODE="preexisting-tag"
expect_failure "tag already exists for the release candidate" \
    "$draft_creator" \
    --repository owner/repository \
    --commit 0123456789abcdef0123456789abcdef01234567 \
    --candidate-number 1 \
    --run-dir "$release_run" \
    --readback "$temporary_directory/preexisting-tag.json"
if /usr/bin/grep -Fq -- '--method POST' "$fake_gh_log"; then
    fail "A pre-existing tag must prevent every RC mutation."
fi

for failure_mode in upload-fail tag-readback-fail; do
    : > "$fake_gh_log"
    /bin/rm -f "$fake_gh_tag_state"
    export FAKE_GH_MODE="$failure_mode"
    expect_failure "release-candidate transaction" \
        "$draft_creator" \
        --repository owner/repository \
        --commit 0123456789abcdef0123456789abcdef01234567 \
        --candidate-number 1 \
        --run-dir "$release_run" \
        --readback "$temporary_directory/$failure_mode.json"
    /usr/bin/grep -Fq -- '--method DELETE repos/owner/repository/releases/123' \
        "$fake_gh_log" || fail "A failed RC transaction must delete its incomplete draft."
    /usr/bin/grep -Fq -- \
        '--method DELETE repos/owner/repository/git/refs/tags/v0.2.0-rc.1' \
        "$fake_gh_log" || fail "A failed RC transaction must delete its owned tag."
    [[ ! -f "$fake_gh_tag_state" ]] || \
        fail "A failed RC transaction must not retain a tag created by that invocation."
done

: > "$fake_gh_log"
/bin/rm -f "$fake_gh_tag_state"
export FAKE_GH_MODE="rollback-release-delete-fail"
expect_failure "Rollback could not delete the incomplete draft release" \
    "$draft_creator" \
    --repository owner/repository \
    --commit 0123456789abcdef0123456789abcdef01234567 \
    --candidate-number 1 \
    --run-dir "$release_run" \
    --readback "$temporary_directory/rollback-release-delete-fail.json"
if /usr/bin/grep -Fq -- \
    '--method DELETE repos/owner/repository/git/refs/tags/v0.2.0-rc.1' \
    "$fake_gh_log"; then
    fail "A retained incomplete release must prevent deletion of its candidate tag."
fi
[[ -f "$fake_gh_tag_state" ]] || \
    fail "A failed draft cleanup must retain the candidate tag for manual recovery."

: > "$fake_gh_log"
/bin/rm -f "$fake_gh_tag_state"
export FAKE_GH_MODE="rollback-tag-delete-fail"
expect_failure "Rollback could not delete the candidate tag" \
    "$draft_creator" \
    --repository owner/repository \
    --commit 0123456789abcdef0123456789abcdef01234567 \
    --candidate-number 1 \
    --run-dir "$release_run" \
    --readback "$temporary_directory/rollback-tag-delete-fail.json"
[[ -f "$fake_gh_tag_state" ]] || \
    fail "A failed tag cleanup must leave the tag visible for manual recovery."

unset GH_TOKEN COPYLASSO_GH_BIN FAKE_GH_LOG FAKE_GH_RECORD \
    FAKE_GH_TAG_RECORD FAKE_GH_TAG_STATE FAKE_GH_MODE

echo "Protected-release workflow tests passed."
