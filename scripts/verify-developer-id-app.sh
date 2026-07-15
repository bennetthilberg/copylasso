#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/developer-id-verification.sh
source "$repository_root/scripts/lib/developer-id-verification.sh"

usage() {
    echo "Usage: $0 [--pre-notarization|--post-notarization] /path/to/CopyLasso.app" >&2
    exit 64
}

mode="post"
case "${1:-}" in
    --pre-notarization)
        mode="pre"
        shift
        ;;
    --post-notarization)
        mode="post"
        shift
        ;;
esac

[[ "$#" == 1 ]] || usage
readonly application_candidate="$1"
[[ -d "$application_candidate" ]] || release_verification_fail "The application bundle is missing."
case "$application_candidate" in
    *.app) ;;
    *) release_verification_fail "The verification target must be an application bundle." ;;
esac

readonly application_parent="$(cd "$(dirname "$application_candidate")" && /bin/pwd -P)"
readonly application="$application_parent/$(basename "$application_candidate")"
readonly signed_info_plist="$application/Contents/Info.plist"
readonly signed_executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$signed_info_plist" 2>/dev/null || true)"
readonly signed_executable="$application/Contents/MacOS/$signed_executable_name"
readonly expected_team_identifier="${COPYLASSO_EXPECTED_TEAM_ID:-}"
readonly temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/copylasso-developer-id-verify.XXXXXX")"
trap 'rm -rf "$temporary_directory"' EXIT

if [[ ! "$expected_team_identifier" =~ ^[A-Z0-9]{10}$ ]]; then
    release_verification_fail \
        "COPYLASSO_EXPECTED_TEAM_ID must provide the approved release team outside the repository."
fi
assert_release_metadata "$signed_info_plist"
[[ -n "$signed_executable_name" && -x "$signed_executable" ]] ||
    release_verification_fail "The signed application executable is missing."
readonly application_architectures="$(/usr/bin/lipo -archs "$signed_executable")"
assert_universal_architectures "$application_architectures"

if ! /usr/bin/codesign --verify --deep --strict --verbose=2 "$application" >"$temporary_directory/codesign-verify.txt" 2>&1; then
    release_verification_fail "Strict recursive code-signature verification failed."
fi

application_team_identifier=""
for architecture in $application_architectures; do
    if ! /usr/bin/codesign --display --architecture "$architecture" --verbose=4 "$application" \
        > /dev/null 2>"$temporary_directory/signature-$architecture.txt"; then
        release_verification_fail "A Developer ID signature slice could not be inspected."
    fi
    assert_developer_id_signature \
        "$temporary_directory/signature-$architecture.txt" \
        "$expected_team_identifier"
    slice_team_identifier="$(
        /usr/bin/sed -n 's/^TeamIdentifier=//p' \
            "$temporary_directory/signature-$architecture.txt" | /usr/bin/head -n 1
    )"
    if [[ -z "$application_team_identifier" ]]; then
        application_team_identifier="$slice_team_identifier"
    elif [[ "$slice_team_identifier" != "$application_team_identifier" ]]; then
        release_verification_fail "The application signature slices do not use the same team."
    fi

    if ! /usr/bin/codesign --display --architecture "$architecture" --requirements - "$application" \
        >"$temporary_directory/requirement-$architecture.txt" \
        2>"$temporary_directory/requirement-diagnostics-$architecture.txt"; then
        release_verification_fail "A designated requirement slice could not be inspected."
    fi
    assert_release_requirement \
        "$temporary_directory/requirement-$architecture.txt" \
        "$application_team_identifier"

    if ! /usr/bin/codesign --display --architecture "$architecture" \
        --entitlements - --xml "$application" \
        >"$temporary_directory/entitlements-$architecture.plist" \
        2>"$temporary_directory/entitlements-diagnostics-$architecture.txt"; then
        release_verification_fail "A signed entitlement slice could not be extracted."
    fi
    assert_release_entitlements "$temporary_directory/entitlements-$architecture.plist"
done
readonly application_team_identifier

mach_o_count=0
while IFS= read -r -d '' candidate; do
    if /usr/bin/file -b "$candidate" | /usr/bin/grep -Fq 'Mach-O'; then
        mach_o_count=$((mach_o_count + 1))
        if ! /usr/bin/codesign --verify --strict --verbose=2 "$candidate" >"$temporary_directory/nested-codesign-$mach_o_count.txt" 2>&1; then
            release_verification_fail "A nested Mach-O signature failed strict verification."
        fi
        if ! candidate_architectures="$(/usr/bin/lipo -archs "$candidate")"; then
            release_verification_fail "A nested Mach-O architecture list could not be inspected."
        fi
        for architecture in $candidate_architectures; do
            if ! /usr/bin/codesign --display --architecture "$architecture" --verbose=4 "$candidate" \
                > /dev/null \
                2>"$temporary_directory/nested-signature-$mach_o_count-$architecture.txt"; then
                release_verification_fail "A nested Mach-O Developer ID signature slice could not be inspected."
            fi
            assert_nested_developer_id_signature \
                "$temporary_directory/nested-signature-$mach_o_count-$architecture.txt" \
                "$application_team_identifier"
        done
    fi
done < <(/usr/bin/find "$application/Contents" -type f -print0)
[[ "$mach_o_count" -gt 0 ]] || release_verification_fail "No signed Mach-O executable was found."

nested_bundle_count=0
while IFS= read -r -d '' nested_bundle; do
    if ! bundle_contains_mach_o "$nested_bundle"; then
        continue
    fi
    nested_bundle_count=$((nested_bundle_count + 1))
    if ! /usr/bin/codesign --verify --strict --verbose=2 "$nested_bundle" \
        >"$temporary_directory/nested-bundle-$nested_bundle_count.txt" 2>&1; then
        release_verification_fail "A nested code bundle failed strict signature verification."
    fi
done < <(
    /usr/bin/find "$application/Contents" -type d \
        \( -name '*.app' -o -name '*.appex' -o -name '*.bundle' -o -name '*.framework' -o -name '*.xpc' \) \
        -print0
)

if [[ "$mode" == "post" ]]; then
    if ! xcrun stapler validate "$application" >"$temporary_directory/stapler.txt" 2>&1; then
        release_verification_fail "The notarization ticket is absent or invalid."
    fi
    if ! /usr/sbin/spctl --assess --type execute --verbose=4 "$application" >"$temporary_directory/gatekeeper.txt" 2>&1; then
        release_verification_fail "Gatekeeper assessment failed."
    fi
    assert_notarized_gatekeeper "$temporary_directory/gatekeeper.txt"
fi

echo "CopyLasso Developer ID application verification passed ($mode-notarization)."
