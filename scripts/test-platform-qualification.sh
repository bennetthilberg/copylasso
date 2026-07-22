#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly cleanup_library="$repository_root/scripts/lib/launch-services-cleanup.sh"
readonly cleanup_runner="$repository_root/scripts/run-with-generated-app-cleanup.sh"
readonly ordinary_release_cleanup="$repository_root/scripts/unregister-generated-release.sh"
readonly qualification_audit="$repository_root/scripts/audit-platform-qualification.sh"
readonly shared_scheme="$repository_root/CopyLasso.xcodeproj/xcshareddata/xcschemes/CopyLasso.xcscheme"

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
    if [[ "$output" != *"$expected_message"* ]]; then
        fail "Expected failure containing '$expected_message', received '$output'."
    fi
}

[[ -r "$cleanup_library" ]] || fail "Launch Services cleanup library is missing."
[[ -x "$cleanup_runner" ]] || fail "Generated-app cleanup runner is missing."
[[ -x "$ordinary_release_cleanup" ]] || fail "Ordinary Release cleanup is missing."
[[ -x "$qualification_audit" ]] || fail "Platform qualification audit is missing."
[[ "$(/usr/bin/grep -Fc 'scripts/unregister-generated-release.sh' "$shared_scheme")" == "1" ]] || \
    fail "The shared scheme must invoke ordinary Release cleanup exactly once."

# shellcheck source=scripts/lib/launch-services-cleanup.sh
source "$cleanup_library"

readonly temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/copylasso-g33-tests.XXXXXX")"
trap 'rm -rf "$temporary_directory"' EXIT

readonly derived_data="$temporary_directory/DerivedData"
readonly release_application="$derived_data/Build/Products/Release/CopyLasso.app"
readonly fixture_plist="$temporary_directory/Info.plist"
readonly fake_lsregister="$temporary_directory/lsregister"
readonly lsregister_log="$temporary_directory/lsregister.log"

/bin/mkdir -p "$release_application/Contents"
readonly canonical_release_application="$(
    cd "$(/usr/bin/dirname "$release_application")" && \
        /usr/bin/printf '%s/%s\n' "$(/bin/pwd -P)" "$(/usr/bin/basename "$release_application")"
)"
/usr/bin/plutil -create xml1 "$fixture_plist"
/usr/bin/plutil -insert CFBundleIdentifier \
    -string io.github.bennetthilberg.copylasso "$fixture_plist"
/bin/cp "$fixture_plist" "$release_application/Contents/Info.plist"

/usr/bin/printf '%s\n' \
    '#!/bin/bash' \
    '/usr/bin/printf "%s\\t%s\\n" "$1" "$2" >> "$COPYLASSO_TEST_LSREGISTER_LOG"' \
    > "$fake_lsregister"
/bin/chmod +x "$fake_lsregister"

assert_generated_copylasso_product "$release_application" "$derived_data"
expect_failure "Installed applications are never eligible" \
    assert_generated_copylasso_product "/Applications/CopyLasso.app" "/Applications"

readonly outside_application="$temporary_directory/Outside/CopyLasso.app"
/bin/mkdir -p "$outside_application/Contents"
/bin/cp "$fixture_plist" "$outside_application/Contents/Info.plist"
expect_failure "must remain under the approved build root" \
    assert_generated_copylasso_product "$outside_application" "$derived_data"

readonly nested_application="$derived_data/Build/Products/Release/Nested/CopyLasso.app"
/bin/mkdir -p "$nested_application/Contents"
/bin/cp "$fixture_plist" "$nested_application/Contents/Info.plist"
expect_failure "must be a direct Xcode build product" \
    assert_generated_copylasso_product "$nested_application" "$derived_data"

readonly debug_identity_application="$derived_data/Build/Products/Debug/CopyLasso.app"
/bin/mkdir -p "$debug_identity_application/Contents"
/usr/bin/plutil -create xml1 "$debug_identity_application/Contents/Info.plist"
/usr/bin/plutil -insert CFBundleIdentifier \
    -string io.github.bennetthilberg.copylasso.debug \
    "$debug_identity_application/Contents/Info.plist"
expect_failure "production bundle identifier" \
    assert_generated_copylasso_product "$debug_identity_application" "$derived_data"

readonly linked_application="$derived_data/Build/Products/Linked/CopyLasso.app"
/bin/mkdir -p "$(/usr/bin/dirname "$linked_application")"
/bin/ln -s "$outside_application" "$linked_application"
expect_failure "symbolic links are not eligible" \
    assert_generated_copylasso_product "$linked_application" "$derived_data"

COPYLASSO_LSREGISTER_PATH="$fake_lsregister" \
COPYLASSO_TEST_LSREGISTER_LOG="$lsregister_log" \
    unregister_generated_copylasso_product "$release_application" "$derived_data"
[[ "$(/bin/cat "$lsregister_log")" == $'-u\t'"$canonical_release_application" ]] || \
    fail "Generated Release cleanup did not unregister the exact canonical product."

readonly missing_application="$derived_data/Build/Products/Missing/CopyLasso.app"
COPYLASSO_LSREGISTER_PATH="$fake_lsregister" \
COPYLASSO_TEST_LSREGISTER_LOG="$lsregister_log" \
    unregister_generated_copylasso_product "$missing_application" "$derived_data"
[[ "$(/usr/bin/wc -l < "$lsregister_log" | /usr/bin/tr -d ' ')" == "1" ]] || \
    fail "A missing product must be an idempotent cleanup no-op."

CONFIGURATION=Debug \
BUILD_DIR="$derived_data/Build/Products" \
TARGET_BUILD_DIR="$derived_data/Build/Products/Debug" \
WRAPPER_NAME=CopyLasso.app \
COPYLASSO_LSREGISTER_PATH="$fake_lsregister" \
COPYLASSO_CLEANUP_TEST_MODE=1 \
COPYLASSO_TEST_LSREGISTER_LOG="$lsregister_log" \
    "$ordinary_release_cleanup"
[[ "$(/usr/bin/wc -l < "$lsregister_log" | /usr/bin/tr -d ' ')" == "1" ]] || \
    fail "Ordinary cleanup must leave Debug builds registered."

CONFIGURATION=Release \
BUILD_DIR="$derived_data/Build/Products" \
TARGET_BUILD_DIR="$derived_data/Build/Products/Release" \
WRAPPER_NAME=CopyLasso.app \
COPYLASSO_LSREGISTER_PATH="$fake_lsregister" \
COPYLASSO_CLEANUP_TEST_MODE=1 \
COPYLASSO_TEST_LSREGISTER_LOG="$lsregister_log" \
    "$ordinary_release_cleanup"
[[ "$(/usr/bin/wc -l < "$lsregister_log" | /usr/bin/tr -d ' ')" == "2" ]] || \
    fail "Ordinary Release cleanup did not unregister its generated product."

CONFIGURATION=Release \
BUILD_DIR="$derived_data/Build/Products" \
TARGET_BUILD_DIR="$derived_data/Build/Products/Release" \
WRAPPER_NAME=CopyLasso.app \
COPYLASSO_GENERATED_CLEANUP_WRAPPED=1 \
COPYLASSO_LSREGISTER_PATH="$fake_lsregister" \
COPYLASSO_CLEANUP_TEST_MODE=1 \
COPYLASSO_TEST_LSREGISTER_LOG="$lsregister_log" \
    "$ordinary_release_cleanup"
[[ "$(/usr/bin/wc -l < "$lsregister_log" | /usr/bin/tr -d ' ')" == "2" ]] || \
    fail "The shared scheme must defer to the failure-safe CI cleanup wrapper."

readonly build_fixture="$temporary_directory/build-fixture.sh"
/usr/bin/printf '%s\n' \
    '#!/bin/bash' \
    'set -euo pipefail' \
    '/bin/mkdir -p "$COPYLASSO_TEST_APP/Contents"' \
    '/bin/cp "$COPYLASSO_TEST_PLIST" "$COPYLASSO_TEST_APP/Contents/Info.plist"' \
    'exit "${COPYLASSO_TEST_EXIT_STATUS:-0}"' \
    > "$build_fixture"
/bin/chmod +x "$build_fixture"

run_cleanup_fixture() {
    local status="$1"

    /bin/rm -rf "$release_application"
    COPYLASSO_LSREGISTER_PATH="$fake_lsregister" \
    COPYLASSO_CLEANUP_TEST_MODE=1 \
    COPYLASSO_TEST_LSREGISTER_LOG="$lsregister_log" \
    COPYLASSO_TEST_APP="$release_application" \
    COPYLASSO_TEST_PLIST="$fixture_plist" \
    COPYLASSO_TEST_EXIT_STATUS="$status" \
        "$cleanup_runner" \
        "$derived_data" \
        "$release_application" \
        -- \
        "$build_fixture"
}

run_cleanup_fixture 0
if run_cleanup_fixture 17; then
    fail "The cleanup runner must preserve the wrapped build's failure status."
else
    readonly wrapped_status="$?"
    [[ "$wrapped_status" == "17" ]] || \
        fail "Expected wrapped failure status 17, received $wrapped_status."
fi
[[ "$(/usr/bin/wc -l < "$lsregister_log" | /usr/bin/tr -d ' ')" == "4" ]] || \
    fail "Cleanup must run after both successful and failed generated builds."

echo "CopyLasso platform qualification contract passed."
