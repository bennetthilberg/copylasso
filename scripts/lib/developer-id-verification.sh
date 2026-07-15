#!/bin/bash

release_verification_fail() {
    echo "$1" >&2
    return 1
}

signature_has_hardened_runtime() {
    local signature_details="$1"

    /usr/bin/grep -Eq \
        'CodeDirectory .*flags=[^[:space:]]*\(([^,()]+,)*runtime(,[^,()]+)*\)' \
        "$signature_details"
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

bundle_contains_mach_o() {
    local bundle="$1"
    local candidate

    while IFS= read -r -d '' candidate; do
        if /usr/bin/file -b "$candidate" | /usr/bin/grep -Fq 'Mach-O'; then
            return 0
        fi
    done < <(/usr/bin/find "$bundle" -type f -print0)
    return 1
}

assert_release_entitlements() {
    local entitlements_plist="$1"
    local sandbox_node_type
    local xml
    local key_count

    if ! /usr/bin/plutil -lint "$entitlements_plist" >/dev/null 2>&1; then
        release_verification_fail "The signed entitlements are not a valid property list."
        return 1
    fi
    if ! xml="$(/usr/bin/plutil -convert xml1 -o - "$entitlements_plist")"; then
        release_verification_fail "The signed entitlements could not be inspected."
        return 1
    fi
    sandbox_node_type="$(
        /usr/bin/printf '%s' "$xml" |
            /usr/bin/xmllint --nonet --xpath \
                'name(/plist/dict/key[.="com.apple.security.app-sandbox"]/following-sibling::*[1])' \
                - 2>/dev/null || true
    )"
    case "$sandbox_node_type" in
        true) ;;
        false | "")
            release_verification_fail "The signed application must retain App Sandbox."
            return 1
            ;;
        *)
            release_verification_fail "The signed App Sandbox entitlement must be a Boolean true value."
            return 1
            ;;
    esac

    if /usr/libexec/PlistBuddy -c 'Print :com.apple.security.get-task-allow' "$entitlements_plist" >/dev/null 2>&1; then
        release_verification_fail "The Release application must not contain get-task-allow."
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
    local required_team_identifier="${2:-}"
    local signature_team_identifier

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
    if ! signature_has_hardened_runtime "$signature_details"; then
        release_verification_fail "The Developer ID signature is missing Hardened Runtime."
        return 1
    fi
    signature_team_identifier="$(
        /usr/bin/sed -n 's/^TeamIdentifier=//p' "$signature_details" | /usr/bin/head -n 1
    )"
    if [[ -z "$signature_team_identifier" ]]; then
        release_verification_fail "The Developer ID signature is missing its team identifier."
        return 1
    fi
    if [[ -n "$required_team_identifier" && \
        "$signature_team_identifier" != "$required_team_identifier" ]]; then
        release_verification_fail "The Developer ID signature does not match the approved release team."
        return 1
    fi
}

assert_nested_developer_id_signature() {
    local signature_details="$1"
    local required_team_identifier="$2"
    local nested_team_identifier

    if ! /usr/bin/grep -Eq '^Identifier=.+$' "$signature_details"; then
        release_verification_fail "The nested code signature is missing its identifier."
        return 1
    fi
    if ! /usr/bin/grep -Fq 'Authority=Developer ID Application:' "$signature_details"; then
        release_verification_fail "The nested code is not signed with Developer ID Application."
        return 1
    fi
    if ! /usr/bin/grep -Eq '^Timestamp=.+$' "$signature_details"; then
        release_verification_fail "The nested Developer ID signature is missing a secure timestamp."
        return 1
    fi
    if ! signature_has_hardened_runtime "$signature_details"; then
        release_verification_fail "The nested Developer ID signature is missing Hardened Runtime."
        return 1
    fi
    nested_team_identifier="$(/usr/bin/sed -n 's/^TeamIdentifier=//p' "$signature_details" | /usr/bin/head -n 1)"
    if [[ -z "$nested_team_identifier" || "$nested_team_identifier" != "$required_team_identifier" ]]; then
        release_verification_fail "The nested Developer ID signature does not match the application team."
        return 1
    fi
}

assert_release_requirement() {
    local requirement_details="$1"
    local required_team_identifier="${2:-}"

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
    if [[ -z "$required_team_identifier" ]] ||
        ! /usr/bin/grep -Eq \
            "certificate leaf\\[subject\\.OU\\] = (\"$required_team_identifier\"|$required_team_identifier)([[:space:]]|$)" \
            "$requirement_details"; then
        release_verification_fail "The designated requirement does not match the application team."
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
