#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/release-workflow-verification.sh
source "$repository_root/scripts/lib/release-workflow-verification.sh"

usage() {
    echo "Usage: $0 --state-dir /path/under/RUNNER_TEMP" >&2
    exit 64
}

state_directory=""
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --state-dir)
            [[ "$#" -ge 2 ]] || usage
            state_directory="$2"
            shift 2
            ;;
        *) usage ;;
    esac
done
[[ -n "$state_directory" ]] || usage

assert_release_state_directory "$state_directory"
if [[ ! -e "$state_directory" ]]; then
    echo "No temporary release credential state remains."
    exit 0
fi
[[ -d "$state_directory" && ! -L "$state_directory" ]] || \
    protected_release_fail "The temporary release credential state is not a real directory."

readonly keychain_path="$state_directory/copylasso-release.keychain-db"
readonly original_keychains="$state_directory/original-keychains.txt"
readonly original_default="$state_directory/original-default-keychain.txt"
cleanup_failed="false"

if [[ -s "$original_default" ]]; then
    original_default_path="$(/bin/cat "$original_default")"
    if [[ -n "$original_default_path" ]]; then
        if ! /usr/bin/security default-keychain -d user -s \
            "$original_default_path" >/dev/null 2>&1; then
            echo "The original default Keychain could not be restored." >&2
            cleanup_failed="true"
        fi
    fi
fi

if [[ -f "$original_keychains" ]]; then
    restored_keychains=()
    while IFS= read -r keychain; do
        [[ -n "$keychain" ]] && restored_keychains+=("$keychain")
    done < "$original_keychains"
    if [[ "${#restored_keychains[@]}" -gt 0 ]]; then
        if ! /usr/bin/security list-keychains -d user -s \
            "${restored_keychains[@]}" >/dev/null 2>&1; then
            echo "The original Keychain search list could not be restored." >&2
            cleanup_failed="true"
        fi
    fi
fi

if [[ -e "$keychain_path" ]]; then
    if ! /usr/bin/security delete-keychain "$keychain_path" >/dev/null 2>&1; then
        echo "The temporary release Keychain could not be deleted cleanly." >&2
        cleanup_failed="true"
    fi
fi
/bin/rm -rf "$state_directory"
[[ ! -e "$state_directory" ]] || \
    protected_release_fail "Temporary release credential state remains after cleanup."

if [[ "$cleanup_failed" == "true" ]]; then
    protected_release_fail \
        "Temporary release material was removed, but the runner Keychain state was not fully restored."
fi

echo "Temporary release credentials were removed."
