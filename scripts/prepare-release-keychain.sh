#!/bin/bash

set -euo pipefail
umask 077

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/release-workflow-verification.sh
source "$repository_root/scripts/lib/release-workflow-verification.sh"

usage() {
    echo "Usage: $0 --state-dir /path/under/RUNNER_TEMP" >&2
    exit 64
}

state_directory=""
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --state-dir)
            [[ "$#" -ge 2 ]] || usage
            state_directory="$2"
            shift 2
            ;;
        *) usage ;;
    esac
done
[[ -n "$state_directory" ]] || usage

assert_release_secret_contract
assert_release_state_directory "$state_directory"
[[ ! -e "$state_directory" && ! -L "$state_directory" ]] || \
    protected_release_fail "The temporary release credential state already exists."
/bin/mkdir -m 700 "$state_directory"

readonly keychain_path="$state_directory/copylasso-release.keychain-db"
readonly certificate_path="$state_directory/developer-id.p12"
readonly notary_key_path="$state_directory/notary-key.p8"
readonly original_keychains="$state_directory/original-keychains.txt"
readonly original_default="$state_directory/original-default-keychain.txt"
readonly identity_record="$state_directory/identity-record.txt"
readonly setup_log="$state_directory/setup.log"

cleanup_raw_credentials() {
    /bin/rm -f "$certificate_path" "$notary_key_path" "$identity_record"
}
trap cleanup_raw_credentials EXIT

/usr/bin/security list-keychains -d user | \
    /usr/bin/sed -E 's/^[[:space:]]*"//; s/"[[:space:]]*$//' > "$original_keychains"
/usr/bin/security default-keychain -d user | \
    /usr/bin/sed -E 's/^[[:space:]]*"//; s/"[[:space:]]*$//' > "$original_default"

printf '%s' "$COPYLASSO_DEVELOPER_ID_P12_BASE64" | \
    /usr/bin/base64 -D > "$certificate_path" || \
    protected_release_fail "The protected Developer ID certificate could not be decoded."
printf '%s' "$COPYLASSO_NOTARY_KEY_BASE64" | \
    /usr/bin/base64 -D > "$notary_key_path" || \
    protected_release_fail "The protected notarization key could not be decoded."
/bin/chmod 600 "$certificate_path" "$notary_key_path"

/usr/bin/security create-keychain \
    -p "$COPYLASSO_RELEASE_KEYCHAIN_PASSWORD" \
    "$keychain_path" > "$setup_log" 2>&1 || \
    protected_release_fail "The temporary release Keychain could not be created."
/usr/bin/security set-keychain-settings \
    -lut 7200 "$keychain_path" >> "$setup_log" 2>&1 || \
    protected_release_fail "The temporary release Keychain settings could not be applied."
/usr/bin/security unlock-keychain \
    -p "$COPYLASSO_RELEASE_KEYCHAIN_PASSWORD" \
    "$keychain_path" >> "$setup_log" 2>&1 || \
    protected_release_fail "The temporary release Keychain could not be unlocked."

existing_keychains=()
while IFS= read -r keychain; do
    [[ -n "$keychain" ]] && existing_keychains+=("$keychain")
done < "$original_keychains"
/usr/bin/security list-keychains -d user -s \
    "$keychain_path" "${existing_keychains[@]}" >> "$setup_log" 2>&1 || \
    protected_release_fail "The temporary release Keychain could not be added to the search list."
/usr/bin/security default-keychain -d user -s "$keychain_path" >> "$setup_log" 2>&1 || \
    protected_release_fail "The temporary release Keychain could not become the signing default."

/usr/bin/security import "$certificate_path" \
    -k "$keychain_path" \
    -P "$COPYLASSO_DEVELOPER_ID_P12_PASSWORD" \
    -T /usr/bin/codesign \
    -T /usr/bin/security \
    -T /usr/bin/xcodebuild >> "$setup_log" 2>&1 || \
    protected_release_fail "The protected Developer ID identity could not be imported."
/usr/bin/security set-key-partition-list \
    -S apple-tool:,apple:,codesign: \
    -s \
    -k "$COPYLASSO_RELEASE_KEYCHAIN_PASSWORD" \
    "$keychain_path" >> "$setup_log" 2>&1 || \
    protected_release_fail "The imported Developer ID private key could not be authorized for signing tools."

/usr/bin/security find-identity -v -p codesigning "$keychain_path" \
    > "$identity_record" 2>/dev/null || true
identity_count="$(/usr/bin/awk -v team="$COPYLASSO_EXPECTED_TEAM_ID" '
    index($0, "Developer ID Application:") && index($0, "(" team ")") { count += 1 }
    END { print count + 0 }
' "$identity_record")"
[[ "$identity_count" == "1" ]] || \
    protected_release_fail "The protected Keychain must contain exactly one matching Developer ID identity."

xcrun notarytool store-credentials copylasso-notary \
    --key "$notary_key_path" \
    --key-id "$COPYLASSO_NOTARY_KEY_ID" \
    --issuer "$COPYLASSO_NOTARY_ISSUER_ID" \
    --keychain "$keychain_path" >> "$setup_log" 2>&1 || \
    protected_release_fail "The protected notarization profile could not be stored."
xcrun notarytool history \
    --keychain-profile copylasso-notary \
    --keychain "$keychain_path" >> "$setup_log" 2>&1 || \
    protected_release_fail "The protected notarization profile could not authenticate."

cleanup_raw_credentials
trap - EXIT
echo "Protected release credentials are available only in the temporary Keychain."
