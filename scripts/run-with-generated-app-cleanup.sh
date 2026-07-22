#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"

# shellcheck source=scripts/lib/launch-services-cleanup.sh
source "$repository_root/scripts/lib/launch-services-cleanup.sh"

if [[ "${COPYLASSO_CLEANUP_TEST_MODE:-0}" != "1" ]]; then
    unset COPYLASSO_LSREGISTER_PATH
fi

if [[ "$#" -lt 4 ]] || [[ "$3" != "--" ]]; then
    echo "Usage: $0 APPROVED_BUILD_ROOT GENERATED_APP -- COMMAND [ARGUMENT ...]" >&2
    exit 64
fi

readonly copylasso_cleanup_build_root="$1"
readonly copylasso_cleanup_application="$2"
shift 3

set +e
"$@"
readonly wrapped_status="$?"
set -e

cleanup_status=0
unregister_generated_copylasso_product \
    "$copylasso_cleanup_application" \
    "$copylasso_cleanup_build_root" || cleanup_status="$?"

if [[ "$wrapped_status" != "0" ]]; then
    if [[ "$cleanup_status" != "0" ]]; then
        echo "Generated-product cleanup also failed after the wrapped command." >&2
    fi
    exit "$wrapped_status"
fi
exit "$cleanup_status"
