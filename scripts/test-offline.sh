#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly requested_architecture="${COPYLASSO_CI_ARCH:-$(uname -m)}"
readonly derived_data="${COPYLASSO_OFFLINE_DERIVED_DATA_PATH:-$repository_root/.build/ci-$requested_architecture}"
readonly products="$derived_data/Build/Products/Debug"
readonly app="$products/CopyLasso.app"
readonly test_bundle="$app/Contents/PlugIns/CopyLassoTests.xctest"
readonly package_frameworks="$products/PackageFrameworks"

case "$requested_architecture" in
    arm64 | x86_64) ;;
    *)
        echo "Unsupported offline-test architecture: $requested_architecture" >&2
        exit 1
        ;;
esac

case "$derived_data" in
    "$repository_root"/.build/*) ;;
    *)
        echo "Offline-test DerivedData must remain under $repository_root/.build." >&2
        exit 1
        ;;
esac

if [[ ! -d "$test_bundle" ]] || \
    [[ ! -f "$app/Contents/MacOS/CopyLasso.debug.dylib" ]] || \
    [[ ! -d "$package_frameworks" ]]; then
    echo "Build and test CopyLasso before running the offline suite." >&2
    exit 1
fi

/bin/ln -sf \
    "$app/Contents/MacOS/CopyLasso.debug.dylib" \
    "$package_frameworks/CopyLasso.debug.dylib"

test_runner=(/usr/bin/xcrun xctest)
if [[ "$requested_architecture" == "x86_64" ]]; then
    test_runner=(/usr/bin/arch -x86_64 /usr/bin/xcrun xctest)
fi

/usr/bin/sandbox-exec \
    -p '(version 1)(allow default)(deny network*)' \
    /usr/bin/env \
    LLVM_PROFILE_FILE="$derived_data/Offline-%p.profraw" \
    DYLD_FRAMEWORK_PATH="$app/Contents/Frameworks:$package_frameworks" \
    "${test_runner[@]}" \
    "$test_bundle"
