#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly tools_dir="${COPYLASSO_SPARKLE_TOOLS_DIR:-}"
readonly fixture_runner="$repository_root/scripts/fixtures/run-secure-update-signatures.sh"

fail() {
    echo "$1" >&2
    exit 1
}

[[ "$#" == "0" ]] || fail "Unexpected secure-update signature proof argument."
if [[ -n "${COPYLASSO_SECURE_UPDATE_FIXTURE_INNER:-}" ]]; then
    fail "COPYLASSO_SECURE_UPDATE_FIXTURE_INNER must not be preset."
fi
[[ -n "$tools_dir" ]] || fail "Set COPYLASSO_SPARKLE_TOOLS_DIR to Sparkle's bin directory."
[[ -x "$fixture_runner" ]] || fail "The sandboxed signature fixture runner is unavailable."

exec /usr/bin/sandbox-exec \
    -p '(version 1)(allow default)(deny network*)' \
    /usr/bin/env \
    -u COPYLASSO_SECURE_UPDATE_FIXTURE_INNER \
    COPYLASSO_SPARKLE_TOOLS_DIR="$tools_dir" \
    "$fixture_runner"
