#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly project_path="$repository_root/CopyLasso.xcodeproj"
readonly scheme="CopyLasso"
readonly requested_architecture="${COPYLASSO_CI_ARCH:-$(uname -m)}"
readonly derived_data="${COPYLASSO_DERIVED_DATA_PATH:-$repository_root/.build/ci-$requested_architecture}"

case "$requested_architecture" in
    arm64 | x86_64) ;;
    *)
        echo "Unsupported CI architecture: $requested_architecture" >&2
        exit 1
        ;;
esac

case "$derived_data" in
    "$repository_root"/.build/*) ;;
    *)
        echo "Derived data must remain under $repository_root/.build." >&2
        exit 1
        ;;
esac

if [[ "$(xcodebuild -version | /usr/bin/head -n 1)" != "Xcode 26.6" ]]; then
    echo "CopyLasso CI requires Xcode 26.6." >&2
    xcodebuild -version >&2
    exit 1
fi

cd "$repository_root"
rm -rf "$derived_data"
mkdir -p "$derived_data"

echo "Linting Swift sources"
xcrun swift-format lint --recursive --strict \
    CopyLasso \
    CopyLassoTests \
    CopyLassoUITests

readonly committed_development_team_pattern='^[[:space:]]*"?DEVELOPMENT_TEAM(\[[^]]+\])?"?[[:space:]]*=[[:space:]]*[A-Z0-9]{10};'

if /usr/bin/grep -Eq "$committed_development_team_pattern" \
    CopyLasso.xcodeproj/project.pbxproj; then
    echo "A concrete Apple development team must not be committed to the Xcode project." >&2
    exit 1
fi

echo "Resolving package dependencies"
xcodebuild -resolvePackageDependencies \
    -project "$project_path" \
    -scheme "$scheme" \
    -clonedSourcePackagesDirPath "$derived_data/SourcePackages"

readonly destination="platform=macOS,arch=$requested_architecture"
common_arguments=(
    -project "$project_path"
    -scheme "$scheme"
    -destination "$destination"
    -derivedDataPath "$derived_data"
    -clonedSourcePackagesDirPath "$derived_data/SourcePackages"
    CODE_SIGNING_ALLOWED=NO
)

echo "Building Debug for $requested_architecture"
xcodebuild build \
    "${common_arguments[@]}" \
    -configuration Debug

probe_arguments=('SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited)')
if [[ "${COPYLASSO_CI_FAILURE_PROBE:-false}" == "true" ]]; then
    probe_arguments=('SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) COPYLASSO_CI_FAILURE_PROBE')
    echo "Controlled CI failure probe enabled"
fi

echo "Building unit-test and UI-test bundles"
xcodebuild build-for-testing \
    "${common_arguments[@]}" \
    -configuration Debug \
    "${probe_arguments[@]}"

echo "Running unit tests"
xcodebuild test-without-building \
    "${common_arguments[@]}" \
    -configuration Debug \
    -parallel-testing-enabled NO \
    -test-timeouts-enabled YES \
    -default-test-execution-time-allowance 60 \
    -maximum-test-execution-time-allowance 120 \
    -only-testing:CopyLassoTests \
    -resultBundlePath "$derived_data/UnitTests.xcresult" \
    "${probe_arguments[@]}"

echo "Inspecting required build settings"
xcodebuild -showBuildSettings \
    -project "$project_path" \
    -scheme "$scheme" \
    -configuration Debug \
    CODE_SIGNING_ALLOWED=NO \
    > "$derived_data/debug-build-settings.txt"
xcodebuild -showBuildSettings \
    -project "$project_path" \
    -scheme "$scheme" \
    -configuration Release \
    CODE_SIGNING_ALLOWED=NO \
    > "$derived_data/release-build-settings.txt"

assert_setting() {
    local settings_file="$1"
    local setting_name="$2"
    local expected_value="$3"

    if ! /usr/bin/grep -Eq "^[[:space:]]+$setting_name = $expected_value$" "$settings_file"; then
        echo "Expected $setting_name to equal $expected_value." >&2
        exit 1
    fi
}

assert_setting "$derived_data/debug-build-settings.txt" MACOSX_DEPLOYMENT_TARGET 14.0
assert_setting "$derived_data/debug-build-settings.txt" SWIFT_VERSION 6.0
assert_setting "$derived_data/debug-build-settings.txt" SWIFT_STRICT_CONCURRENCY complete
assert_setting "$derived_data/debug-build-settings.txt" SWIFT_TREAT_WARNINGS_AS_ERRORS YES
assert_setting "$derived_data/debug-build-settings.txt" GCC_TREAT_WARNINGS_AS_ERRORS YES
assert_setting "$derived_data/debug-build-settings.txt" ENABLE_APP_SANDBOX YES
assert_setting "$derived_data/debug-build-settings.txt" PRODUCT_BUNDLE_IDENTIFIER io.github.bennetthilberg.copylasso.debug
assert_setting "$derived_data/release-build-settings.txt" PRODUCT_BUNDLE_IDENTIFIER io.github.bennetthilberg.copylasso
assert_setting "$derived_data/release-build-settings.txt" ENABLE_HARDENED_RUNTIME YES
assert_setting "$derived_data/release-build-settings.txt" ARCHS "arm64 x86_64"
assert_setting "$derived_data/release-build-settings.txt" ONLY_ACTIVE_ARCH NO

echo "Building Universal 2 Release"
xcodebuild build \
    -project "$project_path" \
    -scheme "$scheme" \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$derived_data" \
    -clonedSourcePackagesDirPath "$derived_data/SourcePackages" \
    CODE_SIGNING_ALLOWED=NO

readonly release_executable="$derived_data/Build/Products/Release/CopyLasso.app/Contents/MacOS/CopyLasso"
if [[ ! -x "$release_executable" ]]; then
    echo "Release executable was not produced." >&2
    exit 1
fi

for release_architecture in arm64 x86_64; do
    release_module="$derived_data/Build/Products/Release/CopyLasso.swiftmodule/$release_architecture-apple-macos.swiftmodule"
    if [[ ! -f "$release_module" ]]; then
        echo "Release Swift module is missing $release_architecture." >&2
        exit 1
    fi
    if /usr/bin/grep -a -q 'ScreenCaptureSpikeModel' "$release_module"; then
        echo "The Debug-only screen-capture spike was compiled into Release." >&2
        exit 1
    fi
    if /usr/bin/grep -a -q 'SelectionOverlayController\|DisplayGeometry' "$release_module"; then
        echo "The Debug-only selection-overlay spike was compiled into Release." >&2
        exit 1
    fi
done

readonly release_architectures="$(xcrun lipo -archs "$release_executable")"
for required_architecture in arm64 x86_64; do
    if [[ " $release_architectures " != *" $required_architecture "* ]]; then
        echo "Release executable is missing $required_architecture." >&2
        exit 1
    fi
done

echo "CopyLasso CI passed for $requested_architecture; Release architectures: $release_architectures"
