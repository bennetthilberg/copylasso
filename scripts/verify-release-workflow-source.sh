#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/release-workflow-verification.sh
source "$repository_root/scripts/lib/release-workflow-verification.sh"

usage() {
    echo "Usage: $0 --expected-ref refs/heads/main --expected-commit <full-commit>" >&2
    exit 64
}

expected_ref=""
expected_commit=""
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --expected-ref)
            [[ "$#" -ge 2 ]] || usage
            expected_ref="$2"
            shift 2
            ;;
        --expected-commit)
            [[ "$#" -ge 2 ]] || usage
            expected_commit="$2"
            shift 2
            ;;
        *) usage ;;
    esac
done

[[ -n "$expected_ref" && -n "$expected_commit" ]] || usage
assert_release_source_state "$repository_root" "$expected_ref" "$expected_commit"
echo "Protected release source matches the exact protected main commit."
