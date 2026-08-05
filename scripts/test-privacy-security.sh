#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/project-security-verification.sh
source "$repository_root/scripts/lib/project-security-verification.sh"

fail() {
    echo "$1" >&2
    exit 1
}

expect_failure() {
    local expected_message="$1"
    shift
    local output

    if output="$("$@" 2>&1)"; then
        fail "Expected command to fail: $*"
    fi
    [[ "$output" == *"$expected_message"* ]] || \
        fail "Expected failure containing '$expected_message', received '$output'."
}

readonly temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/copylasso-security-tests.XXXXXX")"
trap 'rm -rf "$temporary_directory"' EXIT
readonly valid_project="$temporary_directory/valid-project.json"

/usr/bin/jq -n '
{
  objects: {
    APP_TARGET: {
      isa: "PBXNativeTarget",
      name: "CopyLasso",
      productType: "com.apple.product-type.application",
      buildConfigurationList: "APP_CONFIGS"
    },
    APP_CONFIGS: {
      isa: "XCConfigurationList",
      buildConfigurations: ["APP_DEBUG", "APP_RELEASE"]
    },
    APP_DEBUG: {
      isa: "XCBuildConfiguration",
      name: "Debug",
      buildSettings: {ENABLE_HARDENED_RUNTIME: "YES"}
    },
    APP_RELEASE: {
      isa: "XCBuildConfiguration",
      name: "Release",
      buildSettings: {ENABLE_HARDENED_RUNTIME: "YES"}
    },
    DECOY_TARGET: {
      isa: "PBXNativeTarget",
      name: "CopyLassoTests",
      productType: "com.apple.product-type.bundle.unit-test",
      buildConfigurationList: "DECOY_CONFIGS"
    },
    DECOY_CONFIGS: {
      isa: "XCConfigurationList",
      buildConfigurations: ["DECOY_DEBUG", "DECOY_RELEASE"]
    },
    DECOY_DEBUG: {
      isa: "XCBuildConfiguration",
      name: "Debug",
      buildSettings: {ENABLE_HARDENED_RUNTIME: "YES"}
    },
    DECOY_RELEASE: {
      isa: "XCBuildConfiguration",
      name: "Release",
      buildSettings: {ENABLE_HARDENED_RUNTIME: "YES"}
    }
  }
}' > "$valid_project"

assert_copylasso_hardened_runtime "$valid_project"

/usr/bin/jq '.objects.APP_DEBUG.buildSettings.ENABLE_HARDENED_RUNTIME = "NO"' \
    "$valid_project" > "$temporary_directory/debug-disabled.json"
expect_failure "Debug and Release app configurations" \
    assert_copylasso_hardened_runtime "$temporary_directory/debug-disabled.json"

/usr/bin/jq 'del(.objects.APP_RELEASE)' \
    "$valid_project" > "$temporary_directory/release-missing.json"
expect_failure "Debug and Release app configurations" \
    assert_copylasso_hardened_runtime "$temporary_directory/release-missing.json"

/usr/bin/jq '.objects.SECOND_APP = .objects.APP_TARGET' \
    "$valid_project" > "$temporary_directory/duplicate-app.json"
expect_failure "exactly one CopyLasso application target" \
    assert_copylasso_hardened_runtime "$temporary_directory/duplicate-app.json"

/usr/bin/jq '.objects.APP_TARGET.productType = "com.apple.product-type.bundle.unit-test"' \
    "$valid_project" > "$temporary_directory/wrong-product.json"
expect_failure "exactly one CopyLasso application target" \
    assert_copylasso_hardened_runtime "$temporary_directory/wrong-product.json"

cat > "$temporary_directory/valid-ui-tests.swift" <<'SWIFT'
let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
attachment.name = "diagnostic"
attachment.lifetime = .deleteOnSuccess
add(attachment)
SWIFT
assert_ui_test_screenshots_are_failure_only "$temporary_directory/valid-ui-tests.swift"

cat > "$temporary_directory/retained-ui-tests.swift" <<'SWIFT'
let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
attachment.lifetime = .keepAlways
add(attachment)
SWIFT
expect_failure "must be deleted after successful UI tests" \
    assert_ui_test_screenshots_are_failure_only "$temporary_directory/retained-ui-tests.swift"

cat > "$temporary_directory/unbounded-ui-tests.swift" <<'SWIFT'
let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
add(screenshot)
let unrelated = XCTAttachment(string: "diagnostic")
unrelated.lifetime = .deleteOnSuccess
add(unrelated)
SWIFT
expect_failure "must be deleted after successful UI tests" \
    assert_ui_test_screenshots_are_failure_only "$temporary_directory/unbounded-ui-tests.swift"

echo "CopyLasso privacy and security contract tests passed."
