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
                .buildSettings.ENABLE_HARDENED_RUNTIME == "YES" and
                    ([
                        .buildSettings
                        | keys[]
                        | select(startswith("ENABLE_HARDENED_RUNTIME["))
                    ] | length) == 0
            )
    ' <<< "$project_json" >/dev/null 2>&1; then
        project_security_fail \
            "Debug and Release app configurations must both enable Hardened Runtime."
    fi
}

assert_ui_test_screenshots_are_failure_only() {
    local ui_test_file="$1"

    [[ -f "$ui_test_file" ]] || \
        project_security_fail "The UI test source is missing."
    if /usr/bin/grep -Fq '.lifetime = .keepAlways' "$ui_test_file" || \
        ! /usr/bin/awk '
            /XCTAttachment\(screenshot:/ {
                if (pending) {
                    invalid = 1
                }
                pending = 1
                delete_on_success = 0
                screenshot_count += 1
                attachment = $0
                if (attachment !~ /^[[:space:]]*(let|var)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*XCTAttachment\(screenshot:/) {
                    invalid = 1
                    next
                }
                sub(/^[[:space:]]*(let|var)[[:space:]]+/, "", attachment)
                sub(/[[:space:]]*=.*$/, "", attachment)
                next
            }
            pending && /\.lifetime[[:space:]]*=/ {
                assignment = $0
                gsub(/[[:space:]]/, "", assignment)
                if (assignment == attachment ".lifetime=.deleteOnSuccess") {
                    delete_on_success = 1
                } else if (index(assignment, attachment ".lifetime=") == 1) {
                    invalid = 1
                    delete_on_success = 0
                }
                next
            }
            pending && /add\(/ {
                addition = $0
                gsub(/[[:space:]]/, "", addition)
                if (!delete_on_success || \
                    (addition != "add(" attachment ")" && \
                     addition != "self.add(" attachment ")")) {
                    invalid = 1
                }
                pending = 0
                delete_on_success = 0
                attachment = ""
            }
            END {
                exit(invalid || pending || screenshot_count == 0)
            }
        ' "$ui_test_file"; then
        project_security_fail \
            "Desktop screenshots must be deleted after successful UI tests."
    fi
}
