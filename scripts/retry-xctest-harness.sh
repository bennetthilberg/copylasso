#!/bin/bash

set -uo pipefail

if (( $# < 3 )); then
    echo "Usage: $0 <result-bundle> <log-file> <command> [arguments...]" >&2
    exit 64
fi

readonly result_bundle="$1"
readonly log_file="$2"
shift 2

readonly maximum_attempts="${COPYLASSO_XCTEST_HARNESS_ATTEMPTS:-2}"
readonly connection_failure='The test runner hung before establishing connection.'

case "$maximum_attempts" in
    '' | *[!0-9]* | 0)
        echo "COPYLASSO_XCTEST_HARNESS_ATTEMPTS must be a positive integer." >&2
        exit 64
        ;;
esac

for attempt in $(/usr/bin/seq 1 "$maximum_attempts"); do
    /bin/rm -rf "$result_bundle" "$log_file"
    echo "Running XCTest harness attempt $attempt of $maximum_attempts"

    "$@" 2>&1 | /usr/bin/tee "$log_file"
    status=${PIPESTATUS[0]}
    if [[ "$status" == 0 ]]; then
        exit 0
    fi

    if [[ "$attempt" == "$maximum_attempts" ]] || \
        ! /usr/bin/grep -Fq "$connection_failure" "$log_file"; then
        exit "$status"
    fi

    echo "Retrying XCTest after a test-runner connection failure (attempt $((attempt + 1)) of $maximum_attempts)."
done

exit 1
