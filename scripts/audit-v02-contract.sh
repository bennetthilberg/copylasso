#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly contract="$repository_root/docs/v0.2-product-contract.md"
readonly baseline_contract="$repository_root/docs/v0.1-product-contract.md"
readonly entitlements="$repository_root/CopyLasso/CopyLasso.entitlements"
readonly expected_baseline_contract_digest='3426807f08168cec2aaca337b80d7657a8a2d8569d48ecaafe0ec75672f92291'

fail() {
    echo "$1" >&2
    exit 1
}

require_contract_text() {
    local required_text="$1"

    /usr/bin/grep -Fq "$required_text" "$contract" || \
        fail "The v0.2 contract is missing required text: $required_text"
}

[[ -f "$contract" ]] || fail "Required v0.2 contract file is missing: docs/v0.2-product-contract.md"
[[ -f "$baseline_contract" ]] || fail "The historical v0.1 product contract must remain present."

baseline_contract_digest="$(/usr/bin/shasum -a 256 "$baseline_contract" | /usr/bin/awk '{print $1}')"
if [[ "$baseline_contract_digest" != "$expected_baseline_contract_digest" ]]; then
    fail "G34 must preserve the reviewed historical v0.1 product contract byte for byte."
fi

for required_text in \
    '# CopyLasso v0.2 Product Contract' \
    '**Status:** Released product contract' \
    '**Approved:** July 22, 2026' \
    '**Implementation status:** Released as 0.2.2 (5) on August 10, 2026.' \
    '[v0.1 product contract](v0.1-product-contract.md)' \
    'automatic update checks are enabled by default' \
    'disable automatic checks in Settings' \
    'Check for Updates' \
    'static, cryptographically signed update metadata' \
    'It sends no stable user or device identifier.' \
    'Downloading, installing, and relaunching always require explicit user confirmation.' \
    'Success sound is enabled by default' \
    'only after the clipboard write succeeds' \
    'CopyLasso exposes one Capture command and one configurable shortcut.' \
    '`Shift-Command-2` (`⇧⌘2`) remains assigned to the single Capture command.' \
    'Any eligible supported code result wins over recognized text' \
    'If no eligible code remains, CopyLasso uses the ordinary OCR result.' \
    'Eligible observations are sorted in visual top-to-bottom, left-to-right order' \
    'Deduplication happens before any single-result, multiline, or' \
    'retained visual order with one newline' \
    'If multiple unique payloads remain and any contains a line break' \
    'code-specific ambiguity' \
    'never opens a URL' \
    'at least 300 samples' \
    'at least 200 positive math samples' \
    'at least 100 negative selections' \
    'at least 15 examples' \
    'blind evaluation corpus' \
    'Any change after unblinding invalidates the result' \
    'A G39 study applies the gates sequentially.' \
    'If no candidate survives them, G39 records no-go without' \
    'at least 95% structurally correct' \
    'Accuracy over all positive math samples is at least 85%' \
    'no reported positive class is below 70% normalized exact match' \
    'no more than 1% false-success rate' \
    'p95 recognition latency no greater than 2' \
    'base M1 MacBook Air with 8 GB memory' \
    '2018 MacBook Air with a 1.6 GHz dual-core Intel Core i5 and 8 GB' \
    'hardware cannot be measured, the candidate cannot receive a go' \
    'no more than 750 MiB of added peak memory' \
    'no more than 200 MiB of installed-size growth' \
    'macOS 14 or newer' \
    'Universal 2' \
    'redistributable licensing' \
    '## Privacy, Security, and Data Lifetime' \
    'Text, code payloads, clipboard data, and HUD previews never' \
    '## Accessibility, Focus, and Failure Behavior' \
    'Keyboard-only and VoiceOver users can check, defer, confirm, cancel, and retry' \
    'No outcome relies on sound or color alone.' \
    'publicly available as version and build `0.2.2 (5)`' \
    '[v0.2 release-state record](v0.2-release-state.md)' \
    'G39 concluded no-go, so CopyLasso 0.2.2 contains no LaTeX recognition' \
    'G40 is omitted.' \
    'issue #36' \
    'issue #38' \
    'issue #47' \
    'issue #48' \
    'issue #49'; do
    require_contract_text "$required_text"
done

if /usr/bin/grep -Eq '(^|[^0-9])0\.2\.0[[:space:]]*\([[:space:]]*[12][[:space:]]*\)' "$contract"; then
    fail "The planned v0.2 contract must not reuse a released build number."
fi

[[ -f "$entitlements" ]] || fail "The approved v0.2 sandbox entitlements file is missing."
entitlements_json="$(/usr/bin/plutil -convert json -o - "$entitlements")" || \
    fail "The approved v0.2 sandbox entitlements are invalid."
if ! /usr/bin/jq -e '
    (keys | sort) == [
        "com.apple.security.app-sandbox",
        "com.apple.security.network.client",
        "com.apple.security.temporary-exception.mach-lookup.global-name"
    ] and
    .["com.apple.security.app-sandbox"] == true and
    .["com.apple.security.network.client"] == true and
    .["com.apple.security.temporary-exception.mach-lookup.global-name"] == [
        "$(PRODUCT_BUNDLE_IDENTIFIER)-spks",
        "$(PRODUCT_BUNDLE_IDENTIFIER)-spki"
    ]
    ' <<< "$entitlements_json" >/dev/null; then
    fail "G36 must retain only the reviewed v0.2 updater sandbox capabilities."
fi

for documentation_contract in \
    "$repository_root/README.md:CopyLasso 0.2.0 was the first updater-enabled public release." \
    "$repository_root/README.md:those older application binaries contain" \
    "$repository_root/PRIVACY.md:Update requests send no screen pixels" \
    "$repository_root/PRIVACY.md:manually install the latest public release once" \
    "$repository_root/docs/security-and-privacy-review.md:This review describes the public CopyLasso 0.2.2 boundary."; do
    documentation_file="${documentation_contract%%:*}"
    required_text="${documentation_contract#*:}"
    /usr/bin/grep -Fq "$required_text" "$documentation_file" || \
        fail "Public v0.2 documentation does not retain the secure-update boundary: $required_text"
done

if /usr/bin/grep -R -nE \
    'TODO|example\.com|Capture LaTeX (is|are) (available now|shipping)' \
    "$contract"; then
    fail "The v0.2 contract contains a placeholder or falsely shipped feature claim."
fi

echo "CopyLasso v0.2 product-contract audit passed."
