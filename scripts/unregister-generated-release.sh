#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"

# shellcheck source=scripts/lib/launch-services-cleanup.sh
source "$repository_root/scripts/lib/launch-services-cleanup.sh"

if [[ "${COPYLASSO_CLEANUP_TEST_MODE:-0}" != "1" ]]; then
    unset COPYLASSO_LSREGISTER_PATH
fi

# Archive uses ACTION=install. Its protected export path is intentionally not
# part of ordinary generated-product cleanup.
if [[ "${CONFIGURATION:-}" != "Release" ]] || \
    [[ "${ACTION:-build}" != "build" ]] || \
    [[ "${COPYLASSO_GENERATED_CLEANUP_WRAPPED:-0}" == "1" ]]; then
    exit 0
fi

readonly build_directory="${BUILD_DIR:-}"
readonly target_build_directory="${TARGET_BUILD_DIR:-}"
readonly wrapper_name="${WRAPPER_NAME:-}"

if [[ -z "$build_directory" ]] || [[ -z "$target_build_directory" ]] || \
    [[ "$wrapper_name" != "CopyLasso.app" ]] || \
    [[ "$build_directory" != */Build/Products ]]; then
    echo "Ordinary Release cleanup received unexpected Xcode build settings." >&2
    exit 1
fi

readonly cleanup_approved_build_root="${build_directory%/Build/Products}"
readonly cleanup_generated_application="$target_build_directory/$wrapper_name"
unregister_generated_copylasso_product \
    "$cleanup_generated_application" \
    "$cleanup_approved_build_root"
