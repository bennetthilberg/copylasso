#!/bin/bash

set -euo pipefail

readonly COPYLASSO_G28_VERSION="0.1.0"
readonly COPYLASSO_G28_DMG="CopyLasso-0.1.0.dmg"
readonly COPYLASSO_G28_CHECKSUM="CopyLasso-0.1.0.dmg.sha256"
readonly COPYLASSO_G28_DSYM="CopyLasso-0.1.0.dSYM.zip"
readonly COPYLASSO_G28_VERIFICATION="CopyLasso-0.1.0-verification.zip"

protected_release_fail() {
    echo "$1" >&2
    exit 1
}

assert_full_release_commit() {
    local g28_commit="$1"

    [[ "$g28_commit" =~ ^[0-9a-f]{40}$ ]] || \
        protected_release_fail "The protected release commit must be a full lowercase Git object identifier."
}

assert_protected_release_ref() {
    local g28_git_ref="$1"

    [[ "$g28_git_ref" == "refs/heads/main" ]] || \
        protected_release_fail "G28 releases may be dispatched only from protected main."
}

assert_release_source_state() {
    local g28_repository="$1"
    local g28_git_ref="$2"
    local g28_expected_commit="$3"
    local g28_actual_commit
    local g28_protected_main_commit

    [[ -d "$g28_repository/.git" ]] || \
        protected_release_fail "The protected release checkout is not a Git repository."
    assert_protected_release_ref "$g28_git_ref"
    assert_full_release_commit "$g28_expected_commit"

    g28_actual_commit="$(/usr/bin/git -C "$g28_repository" rev-parse HEAD)"
    [[ "$g28_actual_commit" == "$g28_expected_commit" ]] || \
        protected_release_fail "The checked-out commit does not match the dispatched commit."
    /usr/bin/git -C "$g28_repository" cat-file -e "$g28_expected_commit^{commit}" || \
        protected_release_fail "The dispatched commit is not available in the checkout."

    g28_protected_main_commit="$(/usr/bin/git -C "$g28_repository" \
        rev-parse refs/remotes/origin/main^{commit} 2>/dev/null || true)"
    [[ "$g28_protected_main_commit" == "$g28_expected_commit" ]] || \
        protected_release_fail "The dispatched commit is not the protected origin/main commit."

    if ! /usr/bin/git -C "$g28_repository" diff --quiet || \
        ! /usr/bin/git -C "$g28_repository" diff --cached --quiet || \
        [[ -n "$(/usr/bin/git -C "$g28_repository" status --porcelain --untracked-files=no)" ]]; then
        protected_release_fail "Protected release generation requires a clean tracked checkout."
    fi
}

assert_release_secret_contract() {
    local g28_expected_team_identifier="${COPYLASSO_EXPECTED_TEAM_ID:-}"
    local g28_key_identifier="${COPYLASSO_NOTARY_KEY_ID:-}"
    local g28_issuer_identifier="${COPYLASSO_NOTARY_ISSUER_ID:-}"

    [[ -n "${COPYLASSO_DEVELOPER_ID_P12_BASE64:-}" ]] || \
        protected_release_fail "The protected Developer ID certificate secret is missing."
    [[ -n "${COPYLASSO_DEVELOPER_ID_P12_PASSWORD:-}" ]] || \
        protected_release_fail "The protected Developer ID certificate password is missing."
    [[ -n "${COPYLASSO_NOTARY_KEY_BASE64:-}" ]] || \
        protected_release_fail "The protected notarization private-key secret is missing."
    [[ "$g28_expected_team_identifier" =~ ^[A-Z0-9]{10}$ ]] || \
        protected_release_fail "The protected release team identifier is invalid."
    [[ "$g28_key_identifier" =~ ^[A-Z0-9]{10}$ ]] || \
        protected_release_fail "The protected notarization key identifier is invalid."
    [[ "$g28_issuer_identifier" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] || \
        protected_release_fail "The protected notarization issuer identifier is invalid."
    [[ -n "${COPYLASSO_RELEASE_KEYCHAIN_PASSWORD:-}" ]] || \
        protected_release_fail "The temporary release Keychain password is missing."
}

assert_release_state_directory() {
    local g28_state_candidate="$1"
    local g28_runner_temporary="${RUNNER_TEMP:-}"

    [[ -n "$g28_runner_temporary" && "$g28_state_candidate" == "$g28_runner_temporary"/* ]] || \
        protected_release_fail "Release credential state must remain under RUNNER_TEMP."
    [[ "$g28_state_candidate" != *"/../"* && "$g28_state_candidate" != */.. ]] || \
        protected_release_fail "Release credential state must not contain parent traversal."
}

assert_release_draft_tag() {
    local g28_tag="$1"

    [[ "$g28_tag" =~ ^v0\.1\.0-g28\.[1-9][0-9]*$ ]] || \
        protected_release_fail "The G28 draft tag name is invalid."
}

assert_release_workflow_assets() {
    local g28_asset_run_directory="$1"
    local g28_asset_verification_bundle="$2"

    [[ -d "$g28_asset_run_directory" ]] || \
        protected_release_fail "The protected release-package directory is missing."
    local g28_asset_candidate
    for g28_asset_candidate in \
        "$g28_asset_run_directory/$COPYLASSO_G28_DMG" \
        "$g28_asset_run_directory/$COPYLASSO_G28_CHECKSUM" \
        "$g28_asset_run_directory/$COPYLASSO_G28_DSYM" \
        "$g28_asset_verification_bundle"; do
        [[ -f "$g28_asset_candidate" ]] || \
            protected_release_fail "A protected release asset is missing: $(basename "$g28_asset_candidate")"
    done
    [[ "$(basename "$g28_asset_verification_bundle")" == "$COPYLASSO_G28_VERIFICATION" ]] || \
        protected_release_fail "The protected verification bundle has the wrong name."
}

release_draft_asset_names() {
    local g28_record="$1"

    /usr/bin/plutil -extract assets xml1 -o - "$g28_record" 2>/dev/null | \
        /usr/bin/awk '
            /<key>name<\/key>/ {
                getline
                gsub(/^[[:space:]]*<string>|<\/string>[[:space:]]*$/, "")
                print
            }
        ' | LC_ALL=C /usr/bin/sort
}

assert_release_draft_record() {
    local g28_record="$1"
    local g28_expected_commit="$2"
    local g28_expected_tag="$3"
    local g28_expected_assets
    local g28_actual_assets

    [[ -f "$g28_record" ]] || protected_release_fail "The draft-release readback is missing."
    /usr/bin/plutil -p "$g28_record" >/dev/null || \
        protected_release_fail "The draft-release readback is not valid JSON."
    assert_full_release_commit "$g28_expected_commit"
    assert_release_draft_tag "$g28_expected_tag"

    [[ "$(/usr/bin/plutil -extract draft raw -o - "$g28_record" 2>/dev/null || true)" == "true" ]] || \
        protected_release_fail "The GitHub release is not a draft."
    [[ "$(/usr/bin/plutil -extract prerelease raw -o - "$g28_record" 2>/dev/null || true)" == "true" ]] || \
        protected_release_fail "The GitHub release is not marked as a prerelease."
    [[ "$(/usr/bin/plutil -extract tag_name raw -o - "$g28_record" 2>/dev/null || true)" == "$g28_expected_tag" ]] || \
        protected_release_fail "The draft release has the wrong tag name."
    [[ "$(/usr/bin/plutil -extract target_commitish raw -o - "$g28_record" 2>/dev/null || true)" == "$g28_expected_commit" ]] || \
        protected_release_fail "The draft release targets the wrong commit."

    g28_expected_assets="$(printf '%s\n' \
        "$COPYLASSO_G28_CHECKSUM" \
        "$COPYLASSO_G28_DMG" \
        "$COPYLASSO_G28_DSYM" \
        "$COPYLASSO_G28_VERIFICATION" | LC_ALL=C /usr/bin/sort)"
    g28_actual_assets="$(release_draft_asset_names "$g28_record")"
    [[ "$g28_actual_assets" == "$g28_expected_assets" ]] || \
        protected_release_fail "The draft release has an incomplete or unexpected asset set."
}

assert_release_log_is_public_safe() {
    local g28_log_file="$1"
    local g28_sensitive_pattern='BEGIN ([A-Z ]+ )?PRIVATE'
    g28_sensitive_pattern+=' KEY|BEGIN CERT'
    g28_sensitive_pattern+='IFICATE|TeamIdentifier=|Authority=Developer ID Application:'
    g28_sensitive_pattern+='|[[:alnum:]._%+-]+@[[:alnum:].-]+\.[A-Za-z]{2,}'
    g28_sensitive_pattern+='|[a-z]{4}-[a-z]{4}-[a-z]{4}-[a-z]{4}'

    [[ -f "$g28_log_file" ]] || protected_release_fail "The release log for inspection is missing."
    if /usr/bin/grep -Eiq -- "$g28_sensitive_pattern" "$g28_log_file"; then
        protected_release_fail "The public release log contains credential or account material."
    fi
}
