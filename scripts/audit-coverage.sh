#!/bin/bash

set -euo pipefail

readonly result_bundle="${1:-}"

if [[ -z "$result_bundle" ]] || [[ ! -d "$result_bundle" ]]; then
    echo "Usage: $0 <UnitTests.xcresult>" >&2
    exit 1
fi

readonly report_json="$(/usr/bin/mktemp -t copylasso-coverage).json"
trap '/bin/rm -f "$report_json"' EXIT

/usr/bin/xcrun xccov view --report --json "$result_bundle" > "$report_json"

ratio_basis_points() {
    local covered="$1"
    local executable="$2"

    if [[ "$executable" -le 0 ]]; then
        echo 0
        return
    fi
    echo $((covered * 10000 / executable))
}

format_basis_points() {
    /usr/bin/awk -v basis_points="$1" 'BEGIN { printf "%.2f", basis_points / 100 }'
}

assert_ratio() {
    local label="$1"
    local covered="$2"
    local executable="$3"
    local minimum_basis_points="$4"
    local actual_basis_points
    actual_basis_points="$(ratio_basis_points "$covered" "$executable")"

    printf '%s: %s/%s lines (%s%%)\n' \
        "$label" \
        "$covered" \
        "$executable" \
        "$(format_basis_points "$actual_basis_points")"

    if [[ "$actual_basis_points" -lt "$minimum_basis_points" ]]; then
        echo "$label must remain at or above $(format_basis_points "$minimum_basis_points")%." >&2
        exit 1
    fi
}

app_metrics="$(/usr/bin/jq -r '
    [
        .targets[]
        | select(.name == "CopyLasso.app")
        | .files[]
        | select(
            .name != "OnboardingView.swift"
            and .name != "LaunchAtLoginStatusView.swift"
            and .name != "MenuBarLabelView.swift"
        )
    ]
    | [(map(.coveredLines) | add), (map(.executableLines) | add)]
    | @tsv
' "$report_json")"
if [[ -z "$app_metrics" ]]; then
    echo "The unit result does not contain CopyLasso application coverage." >&2
    exit 1
fi
read -r app_covered app_executable <<< "$app_metrics"
assert_ratio "Stable application aggregate" "$app_covered" "$app_executable" 7000

logic_metrics="$(/usr/bin/jq -r '
    [
        .targets[]
        | select(.name == "CopyLasso.app")
        | .files[]
        | select(.path | test("/CopyLasso/(Models|CaptureWorkflow|Settings)/"))
    ]
    | [(map(.coveredLines) | add), (map(.executableLines) | add)]
    | @tsv
' "$report_json")"
read -r logic_covered logic_executable <<< "$logic_metrics"
assert_ratio "Platform-neutral logic" "$logic_covered" "$logic_executable" 9000

required_file_minimums=(
    "AboutMetadata.swift|9000"
    "AppSettingsStore.swift|10000"
    "CaptureCommand.swift|9000"
    "CaptureCoordinator.swift|10000"
    "ClipboardService.swift|9500"
    "FeedbackPresentationContent.swift|10000"
    "FeedbackPreview.swift|10000"
    "GlobalShortcutStore.swift|10000"
    "ScreenCapturePermissionHistory.swift|10000"
    "ScreenCapturePermissionService.swift|9000"
    "SelectionGeometry.swift|9800"
    "SettingsController.swift|9200"
    "TextAssembler.swift|9000"
    "VisionOCRService.swift|9000"
)

for requirement in "${required_file_minimums[@]}"; do
    file_name="${requirement%%|*}"
    minimum_basis_points="${requirement##*|}"
    metrics="$(/usr/bin/jq -r --arg file_name "$file_name" '
        first(
            .targets[]
            | select(.name == "CopyLasso.app")
            | .files[]
            | select((.path | split("/") | last) == $file_name)
            | [.coveredLines, .executableLines]
            | @tsv
        ) // empty
    ' "$report_json")"
    if [[ -z "$metrics" ]]; then
        echo "Coverage is missing required production file: $file_name" >&2
        exit 1
    fi
    read -r covered executable <<< "$metrics"
    assert_ratio "$file_name" "$covered" "$executable" "$minimum_basis_points"
done

echo "CopyLasso coverage audit passed."
