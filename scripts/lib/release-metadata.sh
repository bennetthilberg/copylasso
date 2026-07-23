#!/bin/bash

if [[ "${COPYLASSO_RELEASE_METADATA_LOADED:-}" == "1" ]]; then
    return 0
fi

readonly COPYLASSO_RELEASE_METADATA_LOADED=1
readonly copylasso_release_metadata_root="$(
    cd "$(dirname "${BASH_SOURCE[0]}")/../.." && /bin/pwd -P
)"
readonly copylasso_release_metadata_file="$copylasso_release_metadata_root/Configuration/ReleaseMetadata.xcconfig"

copylasso_release_metadata_fail() {
    echo "$1" >&2
    return 1
}

copylasso_release_metadata_value() {
    local key="$1"

    /usr/bin/awk -F= -v expected_key="$key" '
        {
            key = $1
            value = $2
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            if (key == expected_key) {
                print value
                count += 1
            }
        }
        END {
            if (count != 1) {
                exit 1
            }
        }
    ' "$copylasso_release_metadata_file"
}

[[ -f "$copylasso_release_metadata_file" ]] || \
    copylasso_release_metadata_fail "Release metadata source is missing."

readonly COPYLASSO_RELEASE_VERSION="$(
    copylasso_release_metadata_value COPYLASSO_RELEASE_VERSION
)"
readonly COPYLASSO_RELEASE_BUILD="$(
    copylasso_release_metadata_value COPYLASSO_RELEASE_BUILD
)"

[[ "$COPYLASSO_RELEASE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || \
    copylasso_release_metadata_fail "The release version is invalid."
[[ "$COPYLASSO_RELEASE_BUILD" =~ ^[1-9][0-9]*$ ]] || \
    copylasso_release_metadata_fail "The release build is invalid."

readonly COPYLASSO_RELEASE_TAG="v$COPYLASSO_RELEASE_VERSION"
readonly COPYLASSO_RELEASE_DMG="CopyLasso-$COPYLASSO_RELEASE_VERSION.dmg"
readonly COPYLASSO_RELEASE_CHECKSUM="$COPYLASSO_RELEASE_DMG.sha256"
readonly COPYLASSO_RELEASE_DSYM="CopyLasso-$COPYLASSO_RELEASE_VERSION.dSYM.zip"
readonly COPYLASSO_RELEASE_VERIFICATION="CopyLasso-$COPYLASSO_RELEASE_VERSION-verification.zip"
readonly COPYLASSO_RELEASE_APPCAST="CopyLasso-$COPYLASSO_RELEASE_VERSION-appcast.xml"
