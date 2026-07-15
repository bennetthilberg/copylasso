#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly retry_helper="$repository_root/scripts/retry-xctest-harness.sh"

mkdir -p "$repository_root/.build"
test_root="$(/usr/bin/mktemp -d "$repository_root/.build/xctest-harness-retry-contract.XXXXXX")"
readonly test_root

cleanup() {
    rm -rf "$test_root"
}

trap cleanup EXIT

fail() {
    echo "$1" >&2
    exit 1
}

retry_output="$(
    COPYLASSO_XCTEST_HARNESS_ATTEMPTS=2 "$retry_helper" \
        "$test_root/retry.xcresult" \
        "$test_root/retry.log" \
        /bin/sh -c '
            marker="$1"
            attempts="$2"
            printf "attempt\n" >> "$attempts"
            if [[ ! -e "$marker" ]]; then
                touch "$marker"
                echo "The test runner hung before establishing connection."
                exit 65
            fi
        ' _ "$test_root/retry-marker" "$test_root/retry-attempts"
)" || fail "The exact XCTest connection failure was not retried successfully."

if [[ "$(wc -l < "$test_root/retry-attempts" | tr -d ' ')" != 2 ]] || \
    ! grep -Fq 'Retrying XCTest after a test-runner connection failure' \
        <<< "$retry_output"; then
    fail "The exact XCTest connection failure must retry once before succeeding."
fi

set +e
ordinary_output="$(
    COPYLASSO_XCTEST_HARNESS_ATTEMPTS=2 "$retry_helper" \
        "$test_root/ordinary.xcresult" \
        "$test_root/ordinary.log" \
        /bin/sh -c '
            printf "attempt\n" >> "$1"
            echo "An ordinary test failed."
            exit 42
        ' _ "$test_root/ordinary-attempts"
    exit $?
)"
ordinary_status=$?
set -e

if [[ "$ordinary_status" != 42 ]] || \
    [[ "$(wc -l < "$test_root/ordinary-attempts" | tr -d ' ')" != 1 ]] || \
    grep -Fq 'Retrying XCTest' <<< "$ordinary_output"; then
    fail "An ordinary test failure must be returned without retrying."
fi

set +e
exhausted_output="$(
    COPYLASSO_XCTEST_HARNESS_ATTEMPTS=2 "$retry_helper" \
        "$test_root/exhausted.xcresult" \
        "$test_root/exhausted.log" \
        /bin/sh -c '
            printf "attempt\n" >> "$1"
            echo "The test runner hung before establishing connection."
            exit 65
        ' _ "$test_root/exhausted-attempts"
    exit $?
)"
exhausted_status=$?
set -e

if [[ "$exhausted_status" != 65 ]] || \
    [[ "$(wc -l < "$test_root/exhausted-attempts" | tr -d ' ')" != 2 ]] || \
    [[ "$(grep -Fc 'Retrying XCTest' <<< "$exhausted_output")" != 1 ]]; then
    fail "The XCTest connection retry must stop at the configured attempt cap."
fi

echo "CopyLasso XCTest harness retry contract passed."
