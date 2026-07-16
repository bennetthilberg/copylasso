#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly audit_script="$repository_root/scripts/audit-release-workflow.sh"
readonly source_verifier="$repository_root/scripts/verify-release-workflow-source.sh"
readonly credential_preparer="$repository_root/scripts/prepare-release-keychain.sh"
readonly credential_cleanup="$repository_root/scripts/cleanup-release-keychain.sh"
readonly candidate_builder="$repository_root/scripts/build-release-candidate.sh"
readonly draft_creator="$repository_root/scripts/create-draft-release.sh"
readonly verifier_library="$repository_root/scripts/lib/release-workflow-verification.sh"
readonly workflow="$repository_root/.github/workflows/release.yml"
readonly documentation="$repository_root/docs/release-workflow.md"

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
    "$draft_creator"; do
    [[ -x "$executable" ]] || \
        fail "Protected-release executable is missing: $(basename "$executable")"
done

for readable in "$verifier_library" "$workflow" "$documentation"; do
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
    assert_protected_release_ref "refs/tags/v0.1.0-rc.1"
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

assert_release_draft_tag "v0.1.0-g28.12345"
expect_failure "draft tag name is invalid" \
    assert_release_draft_tag "v0.1.0-rc.1"

readonly valid_draft="$temporary_directory/valid-draft.json"
printf '%s\n' "{
  \"id\": 123,
  \"draft\": true,
  \"prerelease\": true,
  \"tag_name\": \"v0.1.0-g28.12345\",
  \"target_commitish\": \"0123456789abcdef0123456789abcdef01234567\",
  \"assets\": [
    {\"name\": \"CopyLasso-0.1.0.dmg\"},
    {\"name\": \"CopyLasso-0.1.0.dmg.sha256\"},
    {\"name\": \"CopyLasso-0.1.0.dSYM.zip\"},
    {\"name\": \"CopyLasso-0.1.0-verification.zip\"}
  ]
}" > "$valid_draft"
assert_release_draft_record \
    "$valid_draft" \
    "0123456789abcdef0123456789abcdef01234567" \
    "v0.1.0-g28.12345"

/usr/bin/sed 's/\"draft\": true/\"draft\": false/' \
    "$valid_draft" > "$temporary_directory/published.json"
expect_failure "not a draft" \
    assert_release_draft_record \
    "$temporary_directory/published.json" \
    "0123456789abcdef0123456789abcdef01234567" \
    "v0.1.0-g28.12345"
/usr/bin/sed '/CopyLasso-0.1.0.dSYM.zip/d' \
    "$valid_draft" > "$temporary_directory/missing-asset.json"
expect_failure "incomplete or unexpected asset set" \
    assert_release_draft_record \
    "$temporary_directory/missing-asset.json" \
    "0123456789abcdef0123456789abcdef01234567" \
    "v0.1.0-g28.12345"

printf 'Fixed content-free release diagnostic.\n' > "$temporary_directory/safe.log"
assert_release_log_is_public_safe "$temporary_directory/safe.log"
printf '%s%s\n' '-----BEGIN PRIVATE' ' KEY-----' > "$temporary_directory/private.log"
expect_failure "credential or account material" \
    assert_release_log_is_public_safe "$temporary_directory/private.log"

readonly release_run="$temporary_directory/release-run"
/bin/mkdir "$release_run"
for asset in \
    CopyLasso-0.1.0.dmg \
    CopyLasso-0.1.0.dmg.sha256 \
    CopyLasso-0.1.0.dSYM.zip \
    CopyLasso-0.1.0-verification.zip; do
    : > "$release_run/$asset"
done
assert_release_workflow_assets \
    "$release_run" \
    "$release_run/CopyLasso-0.1.0-verification.zip"
/bin/rm "$release_run/CopyLasso-0.1.0.dSYM.zip"
expect_failure "protected release asset is missing" \
    assert_release_workflow_assets \
    "$release_run" \
    "$release_run/CopyLasso-0.1.0-verification.zip"
: > "$release_run/CopyLasso-0.1.0.dSYM.zip"

readonly fake_gh="$temporary_directory/gh"
readonly fake_gh_log="$temporary_directory/gh.log"
cat > "$fake_gh" <<'SCRIPT'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$FAKE_GH_LOG"
if [[ "$1" == "api" && "$*" == *"releases/tags/"* ]]; then
    exit 1
fi
if [[ "$1" == "api" && "$*" == *"--method POST"* ]]; then
    printf '{"id":123}\n'
    exit 0
fi
if [[ "$1" == "release" && "$2" == "upload" ]]; then
    [[ "${FAKE_GH_MODE:-success}" != "upload-fail" ]]
    exit
fi
if [[ "$1" == "api" && "$*" == *"--method DELETE"* ]]; then
    exit 0
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
export FAKE_GH_MODE="success"
"$draft_creator" \
    --repository owner/repository \
    --commit 0123456789abcdef0123456789abcdef01234567 \
    --tag v0.1.0-g28.12345 \
    --run-dir "$release_run" \
    --readback "$temporary_directory/readback.json"
assert_release_draft_record \
    "$temporary_directory/readback.json" \
    "0123456789abcdef0123456789abcdef01234567" \
    "v0.1.0-g28.12345"
if /usr/bin/grep -Fq -- '--method DELETE' "$fake_gh_log"; then
    fail "A successful draft must not be rolled back."
fi

: > "$fake_gh_log"
export FAKE_GH_MODE="upload-fail"
expect_failure "asset set could not be uploaded" \
    "$draft_creator" \
    --repository owner/repository \
    --commit 0123456789abcdef0123456789abcdef01234567 \
    --tag v0.1.0-g28.12345 \
    --run-dir "$release_run" \
    --readback "$temporary_directory/failed-readback.json"
/usr/bin/grep -Fq -- '--method DELETE' "$fake_gh_log" || \
    fail "A partial draft upload must delete the incomplete draft."

unset GH_TOKEN COPYLASSO_GH_BIN FAKE_GH_LOG FAKE_GH_RECORD FAKE_GH_MODE

echo "Protected-release workflow tests passed."
