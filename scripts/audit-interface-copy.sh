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
    /usr/bin/perl -ne '
        while (/"(?:\\.|[^"\\])*\.\.\.(?:\\.|[^"\\])*"/g) {
            print "$ARGV:$.:$_";
        }
        close ARGV if eof;
    ' "$@"
}

readonly interpolated_copy_fixture='Text("Loading \(item)...")'
readonly escaped_copy_fixture='Text("Loading \"item\"...")'
fixture_match_count="$({
    /usr/bin/printf '%s\n%s\n' \
        "$interpolated_copy_fixture" \
        "$escaped_copy_fixture" | \
        swift_string_ellipsis_matches - | \
        /usr/bin/wc -l | \
        /usr/bin/tr -d ' '
})"
if [[ "$fixture_match_count" != "2" ]]; then
    fail "The interface-copy audit must detect interpolated and escaped Swift strings."
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
