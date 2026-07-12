#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ci_script="$repository_root/scripts/ci.sh"
readonly repeatability_script="$repository_root/scripts/test-repeatability.sh"
readonly workflow="$repository_root/.github/workflows/ci.yml"

fail() {
    echo "$1" >&2
    exit 1
}

repeatability_invocations="$({
    /usr/bin/grep -Ec '^[[:space:]]*\./scripts/test-repeatability\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$repeatability_invocations" != "1" ]]; then
    fail "Canonical CI must invoke scripts/test-repeatability.sh exactly once."
fi

contract_invocations="$({
    /usr/bin/grep -Ec '^[[:space:]]*\./scripts/test-ci-contract\.sh[[:space:]]*$' \
        "$ci_script" || true
})"
if [[ "$contract_invocations" != "1" ]]; then
    fail "Canonical CI must run its repeatability contract exactly once."
fi

if ! /usr/bin/grep -Fq 'COPYLASSO_CI_ARCH="$requested_architecture" \' "$ci_script" || \
    ! /usr/bin/grep -Fq 'COPYLASSO_REPEAT_DERIVED_DATA_PATH="$derived_data" \' "$ci_script" || \
    ! /usr/bin/grep -Fq 'COPYLASSO_REPEAT_COUNT=3 \' "$ci_script"; then
    fail "Canonical CI must pass its architecture, existing DerivedData, and exact repeat count."
fi

build_for_testing_line="$(/usr/bin/grep -n '^xcodebuild build-for-testing' "$ci_script" | \
    /usr/bin/cut -d: -f1)"
repeatability_line="$(/usr/bin/grep -nE \
    '^[[:space:]]*\./scripts/test-repeatability\.sh[[:space:]]*$' "$ci_script" | \
    /usr/bin/cut -d: -f1)"
offline_line="$(/usr/bin/grep -nE \
    '^[[:space:]]*\./scripts/test-offline\.sh[[:space:]]*$' "$ci_script" | \
    /usr/bin/cut -d: -f1)"
release_line="$(/usr/bin/grep -n '^echo "Building Universal 2 Release"' "$ci_script" | \
    /usr/bin/cut -d: -f1)"
if ((repeatability_line <= build_for_testing_line || repeatability_line >= release_line)); then
    fail "Repeatability must reuse the built unit bundle before the Release build."
fi

offline_block="$(/usr/bin/sed -n "$((offline_line - 2)),${offline_line}p" "$ci_script")"
if ! /usr/bin/grep -Fq 'COPYLASSO_CI_ARCH="$requested_architecture" \' \
    <<< "$offline_block" || \
    ! /usr/bin/grep -Fq 'COPYLASSO_OFFLINE_DERIVED_DATA_PATH="$derived_data" \' \
        <<< "$offline_block"; then
    fail "Canonical offline tests must receive the requested architecture and existing DerivedData."
fi

if ! /usr/bin/grep -Fq '/usr/bin/xcodebuild test-without-building \' \
    "$repeatability_script" || \
    /usr/bin/grep -Eq '/usr/bin/xcodebuild (build|build-for-testing|test) ' \
        "$repeatability_script" || \
    ! /usr/bin/grep -Fq -- '-only-testing:CopyLassoTests' "$repeatability_script" || \
    /usr/bin/grep -Fq 'CopyLassoUITests' "$repeatability_script"; then
    fail "Repeatability must run only the already-built unit bundle without UI tests."
fi

workflow_ci_invocations="$({
    /usr/bin/grep -Ec '^[[:space:]]*run: \./scripts/ci\.sh[[:space:]]*$' "$workflow" || true
})"
if [[ "$workflow_ci_invocations" != "1" ]] || \
    ! /usr/bin/grep -Fq 'architecture: arm64' "$workflow" || \
    ! /usr/bin/grep -Fq 'architecture: x86_64' "$workflow" || \
    ! /usr/bin/grep -Fq 'COPYLASSO_CI_ARCH: ${{ matrix.architecture }}' "$workflow"; then
    fail "Both GitHub architecture jobs must enter through canonical CI."
fi

echo "CopyLasso CI repeatability contract passed."
