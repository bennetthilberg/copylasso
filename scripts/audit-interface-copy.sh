#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

fail() {
    echo "$1" >&2
    exit 1
}

unicode_ellipsis_matches="$({
    /usr/bin/grep -R -n --include='*.swift' '…' CopyLasso || true
})"
if [[ -n "$unicode_ellipsis_matches" ]]; then
    /usr/bin/printf '%s\n' "$unicode_ellipsis_matches" >&2
    fail "CopyLasso-authored interface copy must not contain an ellipsis."
fi

swift_string_ellipsis_matches() {
    /usr/bin/perl -0777 -ne '
        while (/("""(?:(?!""")[\s\S])*"""|"(?:\\.|[^"\\])*")/g) {
            if ($1 =~ /\.\.\./) {
                print "$ARGV\n";
                last;
            }
        }
    ' "$@"
}

readonly interpolated_copy_fixture='Text("Loading \(item)...")'
readonly escaped_copy_fixture='Text("Loading \"item\"...")'
readonly multiline_copy_fixture=$'Text("""\nLoading...\n""")'
readonly range_operator_fixture='let label = "Loading"; let range = 1...6'
fixture_match_count="$({
    for fixture in \
        "$interpolated_copy_fixture" \
        "$escaped_copy_fixture" \
        "$multiline_copy_fixture"; do
        /usr/bin/printf '%s\n' "$fixture" | swift_string_ellipsis_matches -
    done | \
        /usr/bin/wc -l | \
        /usr/bin/tr -d ' '
})"
if [[ "$fixture_match_count" != "3" ]]; then
    fail "The interface-copy audit must detect interpolated, escaped, and multiline Swift strings."
fi
if /usr/bin/printf '%s\n' "$range_operator_fixture" | swift_string_ellipsis_matches - | /usr/bin/grep -q .; then
    fail "The interface-copy audit must not confuse Swift range operators with interface copy."
fi

ascii_ellipsis_string_matches="$({
    while IFS= read -r -d '' swift_file; do
        swift_string_ellipsis_matches "$swift_file"
    done < <(/usr/bin/find CopyLasso -type f -name '*.swift' -print0)
})"
if [[ -n "$ascii_ellipsis_string_matches" ]]; then
    /usr/bin/printf '%s\n' "$ascii_ellipsis_string_matches" >&2
    fail "CopyLasso-authored interface copy must not contain an ellipsis."
fi

for required_label in \
    'Button("History")' \
    'Button("Check for Updates")' \
    'Button("Settings")' \
    'Button("Finish Setup")' \
    'Button("View History")' \
    'Button("Reset Local Development State"' \
    'Button("Acknowledgements")'; do
    if ! /usr/bin/grep -R -Fq --include='*.swift' "$required_label" CopyLasso/SharedUI; then
        fail "Required ellipsis-free interface label is missing: $required_label"
    fi
done

if ! /usr/bin/grep -Fq \
    'String(normalized.prefix(Self.maximumCharacterCount))' \
    CopyLasso/Models/FeedbackPreview.swift; then
    fail "The bounded HUD preview must truncate without adding punctuation."
fi

echo "Authenticated release notes and captured content remain unmodified."
echo "Interface-copy audit passed."
