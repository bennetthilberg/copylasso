#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly contract="$repository_root/docs/v0.2-product-contract.md"
readonly baseline_contract="$repository_root/docs/v0.1-product-contract.md"
readonly release_metadata="$repository_root/Configuration/ReleaseMetadata.xcconfig"
readonly entitlements="$repository_root/CopyLasso/CopyLasso.entitlements"

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

for required_text in \
    '# CopyLasso v0.2 Product Contract' \
    '**Status:** Approved scope for the planned v0.2 release' \
    '**Approved:** July 22, 2026' \
    '**Implementation status:** Planned; these features are not present in CopyLasso 0.1.1' \
    '[v0.1 product contract](v0.1-product-contract.md)' \
    'automatic update checks are enabled by default' \
    'disable automatic checks in Settings' \
    'Check for Updates' \
    'static, cryptographically signed update metadata' \
    'stable user or device identifier' \
    'Downloading, installing, and relaunching always require explicit user confirmation.' \
    'Success sound is enabled by default' \
    'only after the clipboard write succeeds' \
    'Capture Text, Capture Code, and Capture LaTeX are separate commands.' \
    '`Shift-Command-2` (`⇧⌘2`) remains assigned only to Capture Text.' \
    'Capture Code and Capture LaTeX shortcuts are unset by default.' \
    'unique payloads in visual top-to-bottom, left-to-right order' \
    'one newline between payloads' \
    'never opens a URL' \
    'at least 200 controlled samples' \
    'at least 95% structurally correct' \
    'at least 85% normalized exact match' \
    'no more than 1% false-success rate' \
    'p95 recognition latency no greater than 2 seconds on Apple Silicon' \
    'no greater than 4 seconds on Intel' \
    'no more than 750 MiB of added peak memory' \
    'no more than 200 MiB of installed-size growth' \
    'macOS 14 or newer' \
    'Universal 2' \
    'redistributable licensing' \
    '0.1.1 (2)' \
    'G41 may freeze `0.2.0 (3)`' \
    'G40 is omitted if G39 concludes no-go' \
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

/usr/bin/grep -Fq 'COPYLASSO_RELEASE_VERSION = 0.1.1' "$release_metadata" || \
    fail "G34 must leave the current release version at 0.1.1."
/usr/bin/grep -Fq 'COPYLASSO_RELEASE_BUILD = 2' "$release_metadata" || \
    fail "G34 must leave the current release build at 2."

if /usr/bin/grep -Eq 'com\.apple\.security\.network\.(client|server)' "$entitlements"; then
    fail "G34 must not add a network entitlement."
fi

/usr/bin/grep -Fq 'automatic updater' "$repository_root/README.md" || \
    fail "README current-state copy must still say the 0.1.1 app has no updater."
/usr/bin/grep -Fq 'network-client implementation' "$repository_root/README.md" || \
    fail "README current-state copy must still say the 0.1.1 app has no network client."
/usr/bin/grep -Fq \
    'no network-client or server entitlement, networking implementation, telemetry service, or automatic updater' \
    "$repository_root/PRIVACY.md" || \
    fail "PRIVACY current-state copy must still describe the 0.1.1 network boundary."
/usr/bin/grep -Fq \
    'no network-client or server entitlement, networking implementation, content-history store, updater' \
    "$repository_root/docs/security-and-privacy-review.md" || \
    fail "The security review must still describe the 0.1.1 network boundary."

if /usr/bin/grep -R -nE \
    'TODO|example\.com|Capture (Code|LaTeX) (is|are) (available now|shipping|included in 0\.1\.1)' \
    "$contract"; then
    fail "The v0.2 contract contains a placeholder or falsely shipped feature claim."
fi

echo "CopyLasso v0.2 product-contract audit passed."
