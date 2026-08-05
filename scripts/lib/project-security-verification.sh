#!/bin/bash

set -euo pipefail

project_security_fail() {
    echo "$1" >&2
    exit 1
}

assert_copylasso_hardened_runtime() {
    local project_file="$1"
    local project_json
    local app_target_count

    [[ -f "$project_file" ]] || \
        project_security_fail "The Xcode project file is missing."
    project_json="$(/usr/bin/plutil -convert json -o - "$project_file" 2>/dev/null)" || \
        project_security_fail "The Xcode project file is invalid."
    app_target_count="$(/usr/bin/jq -er '
        [
            .objects
            | to_entries[]
            | select(
                .value.isa == "PBXNativeTarget" and
                .value.name == "CopyLasso" and
                .value.productType == "com.apple.product-type.application"
            )
        ]
        | length
    ' <<< "$project_json" 2>/dev/null)" || \
        project_security_fail "The Xcode project target graph is invalid."
    [[ "$app_target_count" == "1" ]] || \
        project_security_fail "The project must contain exactly one CopyLasso application target."

    if ! /usr/bin/jq -e '
        .objects as $objects
        | [
            $objects
            | to_entries[]
            | select(
                .value.isa == "PBXNativeTarget" and
                .value.name == "CopyLasso" and
                .value.productType == "com.apple.product-type.application"
            )
        ][0].value.buildConfigurationList as $configuration_list_identifier
        | $objects[$configuration_list_identifier] as $configuration_list
        | [
            $configuration_list.buildConfigurations[]?
            | $objects[.]
            | select(.isa == "XCBuildConfiguration")
        ] as $configurations
        | ($configuration_list.isa == "XCConfigurationList") and
            (($configurations | length) == 2) and
            (([$configurations[].name] | sort) == ["Debug", "Release"]) and
            all(
                $configurations[];
                .buildSettings.ENABLE_HARDENED_RUNTIME == "YES"
            )
    ' <<< "$project_json" >/dev/null 2>&1; then
        project_security_fail \
            "Debug and Release app configurations must both enable Hardened Runtime."
    fi
}
