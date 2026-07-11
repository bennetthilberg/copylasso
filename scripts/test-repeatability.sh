#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly requested_architecture="${COPYLASSO_CI_ARCH:-$(uname -m)}"
readonly derived_data="${COPYLASSO_REPEAT_DERIVED_DATA_PATH:-$repository_root/.build/ci-$requested_architecture}"
readonly repeat_count="${COPYLASSO_REPEAT_COUNT:-3}"

case "$requested_architecture" in
    arm64 | x86_64) ;;
    *)
        echo "Unsupported repeatability-test architecture: $requested_architecture" >&2
        exit 1
        ;;
esac

case "$repeat_count" in
    '' | *[!0-9]* | 0)
        echo "COPYLASSO_REPEAT_COUNT must be a positive integer." >&2
        exit 1
        ;;
esac

case "$derived_data" in
    "$repository_root"/.build/*) ;;
    *)
        echo "Repeatability-test DerivedData must remain under $repository_root/.build." >&2
        exit 1
        ;;
esac

if [[ ! -d "$derived_data/Build/Products/Debug/CopyLasso.app/Contents/PlugIns/CopyLassoTests.xctest" ]]; then
    echo "Run scripts/ci.sh with the selected DerivedData before the repeatability check." >&2
    exit 1
fi

for run_number in $(/usr/bin/seq 1 "$repeat_count"); do
    result_bundle="$derived_data/Repeatability-$run_number.xcresult"
    /bin/rm -rf "$result_bundle"
    echo "Running deterministic unit pass $run_number of $repeat_count for $requested_architecture"
    /usr/bin/xcodebuild test-without-building \
        -project "$repository_root/CopyLasso.xcodeproj" \
        -scheme CopyLasso \
        -destination "platform=macOS,arch=$requested_architecture" \
        -derivedDataPath "$derived_data" \
        -clonedSourcePackagesDirPath "$derived_data/SourcePackages" \
        -configuration Debug \
        -enableCodeCoverage YES \
        -parallel-testing-enabled NO \
        -test-timeouts-enabled YES \
        -default-test-execution-time-allowance 60 \
        -maximum-test-execution-time-allowance 120 \
        -only-testing:CopyLassoTests \
        -resultBundlePath "$result_bundle" \
        CODE_SIGNING_ALLOWED=NO
done

echo "CopyLasso passed $repeat_count consecutive unit runs for $requested_architecture."
