#!/bin/bash

release_verification_fail() {
    echo "$1" >&2
    return 1
}

assert_release_metadata() {
    local info_plist="$1"
    local bundle_identifier
    local version
    local build

    if [[ ! -f "$info_plist" ]]; then
        release_verification_fail "The application Info.plist is missing."
        return 1
    fi
    if ! bundle_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info_plist" 2>/dev/null)"; then
        release_verification_fail "The application bundle identifier is missing."
        return 1
    fi
    if ! version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info_plist" 2>/dev/null)"; then
        release_verification_fail "The application version is missing."
        return 1
    fi
    if ! build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$info_plist" 2>/dev/null)"; then
        release_verification_fail "The application build is missing."
        return 1
    fi

    if [[ "$bundle_identifier" != "io.github.bennetthilberg.copylasso" ]]; then
        release_verification_fail "The application must use the production bundle identifier."
        return 1
    fi
    if [[ "$version" != "0.1.0" ]]; then
        release_verification_fail "The application must use version 0.1.0."
        return 1
    fi
    if [[ "$build" != "1" ]]; then
        release_verification_fail "The application must use build 1."
        return 1
    fi
}

assert_universal_architectures() {
    local architectures="$1"
    local normalized

    normalized="$(for architecture in $architectures; do echo "$architecture"; done |
        /usr/bin/sort | /usr/bin/tr '\n' ' ' | /usr/bin/sed 's/[[:space:]]*$//')"
    if [[ "$normalized" != "arm64 x86_64" ]]; then
        release_verification_fail "The application must contain exactly arm64 and x86_64."
        return 1
    fi
}

assert_release_entitlements() {
    local entitlements_plist="$1"
    local sandbox_value
    local xml
    local key_count

    if ! /usr/bin/plutil -lint "$entitlements_plist" >/dev/null 2>&1; then
        release_verification_fail "The signed entitlements are not a valid property list."
        return 1
    fi
    if ! sandbox_value="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "$entitlements_plist" 2>/dev/null)"; then
        release_verification_fail "The signed application must retain App Sandbox."
        return 1
    fi
    if [[ "$sandbox_value" != "true" ]]; then
        release_verification_fail "The signed application must retain App Sandbox."
        return 1
    fi

    if /usr/libexec/PlistBuddy -c 'Print :com.apple.security.get-task-allow' "$entitlements_plist" >/dev/null 2>&1; then
        release_verification_fail "The Release application must not contain get-task-allow."
        return 1
    fi

    if ! xml="$(/usr/bin/plutil -convert xml1 -o - "$entitlements_plist")"; then
        release_verification_fail "The signed entitlements could not be inspected."
        return 1
    fi
    key_count="$(/usr/bin/grep -c '<key>' <<< "$xml" || true)"
    if [[ "$key_count" != "1" ]]; then
        release_verification_fail "Release entitlements must contain only the reviewed App Sandbox capability."
        return 1
    fi
}

assert_developer_id_signature() {
    local signature_details="$1"

    if ! /usr/bin/grep -Fqx 'Identifier=io.github.bennetthilberg.copylasso' "$signature_details"; then
        release_verification_fail "The code signature identifier is not the production identifier."
        return 1
    fi
    if ! /usr/bin/grep -Fq 'Authority=Developer ID Application:' "$signature_details"; then
        release_verification_fail "The application is not signed with Developer ID Application."
        return 1
    fi
    if ! /usr/bin/grep -Eq '^Timestamp=.+$' "$signature_details"; then
        release_verification_fail "The Developer ID signature is missing a secure timestamp."
        return 1
    fi
    if ! /usr/bin/grep -F 'CodeDirectory ' "$signature_details" | /usr/bin/grep -Fq '(runtime)'; then
        release_verification_fail "The Developer ID signature is missing Hardened Runtime."
        return 1
    fi
    if ! /usr/bin/grep -Eq '^TeamIdentifier=.+$' "$signature_details"; then
        release_verification_fail "The Developer ID signature is missing its team identifier."
        return 1
    fi
}

assert_release_requirement() {
    local requirement_details="$1"

    if ! /usr/bin/grep -Fq 'identifier "io.github.bennetthilberg.copylasso"' "$requirement_details"; then
        release_verification_fail "The designated requirement does not contain the production identifier."
        return 1
    fi
    if ! /usr/bin/grep -Fq 'anchor apple generic' "$requirement_details"; then
        release_verification_fail "The designated requirement does not use Apple's generic anchor."
        return 1
    fi
    if ! /usr/bin/grep -Fq '1.2.840.113635.100.6.1.13' "$requirement_details"; then
        release_verification_fail "The designated requirement is not constrained to Developer ID Application."
        return 1
    fi
}

assert_notarized_gatekeeper() {
    local gatekeeper_details="$1"

    if ! /usr/bin/grep -Eq ': accepted$' "$gatekeeper_details"; then
        release_verification_fail "Gatekeeper did not accept the application."
        return 1
    fi
    if ! /usr/bin/grep -Fqx 'source=Notarized Developer ID' "$gatekeeper_details"; then
        release_verification_fail "Gatekeeper did not report Notarized Developer ID."
        return 1
    fi
    if ! /usr/bin/grep -Fq 'origin=Developer ID Application:' "$gatekeeper_details"; then
        release_verification_fail "Gatekeeper did not recognize the Developer ID Application origin."
        return 1
    fi
}
