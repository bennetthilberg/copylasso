#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly metadata="$repository_root/Configuration/ReleaseMetadata.xcconfig"
readonly notes="$repository_root/docs/release-notes/0.3.0.md"
readonly qualification="$repository_root/docs/v0.3-release-qualification.md"
readonly candidate_qualification="$repository_root/docs/v0.3-release-candidate.md"
readonly contract="$repository_root/docs/v0.3-product-contract.md"
readonly workflow="$repository_root/.github/workflows/release.yml"
readonly entitlements="$repository_root/CopyLasso/CopyLasso.entitlements"

fail() {
    echo "$1" >&2
    exit 1
}

require_text() {
    local file="$1"
    local expected="$2"

    /usr/bin/grep -Fq -- "$expected" "$file" || \
        fail "The v0.3 qualification contract is missing from ${file#$repository_root/}: $expected"
}

for required_file in \
    "$metadata" \
    "$notes" \
    "$qualification" \
    "$candidate_qualification" \
    "$contract" \
    "$workflow" \
    "$entitlements"; do
    [[ -r "$required_file" ]] || \
        fail "Required v0.3 qualification file is missing: ${required_file#$repository_root/}"
done

for candidate_text in \
    '# CopyLasso v0.3 Private Candidate Qualification' \
    'exact protected-main commit' \
    'exactly four assets' \
    'authenticated update metadata' \
    'public 0.2.2' \
    'clean install' \
    'Disposable-account clean-state preflight' \
    'io.github.bennetthilberg.copylasso.capture-history' \
    'historical G36 fixture is not evidence for G55' \
    'exact signed public tag `v0.2.2`' \
    '81016fe43ee617b5f251564b03904137a4447266' \
    'git verify-tag v0.2.2' \
    "git rev-parse 'v0.2.2^{commit}'" \
    'Exact public 0.2.2 clean-install baseline' \
    'launch the immutable public 0.2.2 app' \
    'COPYLASSO_PRIVATE_UPDATE_FIXTURE' \
    'nonshipping Apple Development-signed 0.2.2 updater fixture' \
    'production bundle identifier' \
    'CopyLasso-0.3.0.zip' \
    'ditto -c -k --keepParent' \
    'valid Ed25519 enclosure signature is the update trust path' \
    'same Apple team for Sparkle installer-service authorization' \
    'untouched candidate application' \
    'complete file, directory' \
    'mode, and symbolic-link manifest' \
    'create_release_payload_manifest' \
    'assert_release_payload_manifests_match' \
    'against the untouched candidate payload' \
    'not release evidence' \
    'public 0.2.2 actually supports' \
    'Reset candidate state before migration qualification' \
    'signed public 0.2.2 production feed' \
    'exact public 0.2.2 DMG enclosure' \
    'English as the new language default' \
    'serve it on `127.0.0.1`' \
    'minimum supported macOS 14 must pass' \
    'Retained Gaps And Disposition' \
    'explicit maintainer approval' \
    'Do not publish'; do
    require_text "$candidate_qualification" "$candidate_text"
done

if /usr/bin/grep -Fq 'Change only that old' "$candidate_qualification" || \
    /usr/bin/grep -Fq 're-sign that old copy' "$candidate_qualification" || \
    /usr/bin/grep -Fq 'enclosure to be the exact candidate DMG bytes' \
        "$candidate_qualification" || \
    /usr/bin/grep -Fq 'Serve only that appcast and exact candidate DMG' \
        "$candidate_qualification"; then
    fail "The G55 updater qualification must not claim that Info.plist edits can redirect the immutable public 0.2.2 binary."
fi

for current_asset in \
    'CopyLasso-0.3.0.dmg' \
    'CopyLasso-0.3.0.dmg.sha256' \
    'CopyLasso-0.3.0.dSYM.zip' \
    'CopyLasso-0.3.0-verification.zip'; do
    require_text "$repository_root/docs/release-workflow.md" "$current_asset"
done
require_text "$repository_root/docs/release-workflow.md" \
    'Historical G50 Draft Assets and Local Readback'
require_text "$repository_root/docs/release-workflow.md" \
    'Historical G50 Private Rehearsal'
require_text "$repository_root/docs/release-checklist.md" \
    '- [x] Pass focused migration/integration checks'
require_text "$repository_root/docs/release-checklist.md" \
    '- [x] Stop with a ready G54 PR.'
require_text "$repository_root/docs/release-checklist.md" \
    'Build only the nonshipping 0.2.2-source updater fixture'
require_text "$repository_root/docs/testing.md" \
    '## G55 public-0.2.2-to-candidate update fixture'
require_text "$repository_root/docs/secure-update-operations.md" \
    '## G55 exact-source update qualification fixture'

require_text "$metadata" 'COPYLASSO_RELEASE_VERSION = 0.3.0'
require_text "$metadata" 'COPYLASSO_RELEASE_BUILD = 6'
require_text "$repository_root/docs/architecture/build-configuration.md" \
    '| Marketing version | `0.3.0` |'
require_text "$repository_root/docs/architecture/build-configuration.md" \
    '| Build number | `6` |'

for notes_text in \
    '# CopyLasso 0.3.0' \
    'Text Languages' \
    'U.S. English remains the default' \
    'Save Capture History' \
    'off by default' \
    'AES-256-GCM' \
    'seven days' \
    '100 entries' \
    '256 KiB' \
    'never stores screenshots' \
    'CopyLasso 0.2.2' \
    'Screen Recording' \
    'single display' \
    'protected content' \
    'LaTeX recognition is not included'; do
    require_text "$notes" "$notes_text"
done

for qualification_text in \
    '# CopyLasso v0.3 Source Qualification' \
    '0.3.0 (6)' \
    '0.2.2 remains the latest public release' \
    'G55' \
    'v0.3.0-rc.N' \
    'No protected release workflow was dispatched' \
    'macOS 14' \
    'Universal 2' \
    'Developer ID' \
    'notarized'; do
    require_text "$qualification" "$qualification_text"
done

for contract_text in \
    '**Status:** Release-qualified source contract for v0.3.0 (6).' \
    'CopyLasso 0.2.2 remains the latest public release.' \
    'U.S. English remains the only default OCR language' \
    '**Save Capture History** is off by default' \
    'It does not add translation, text-to-speech'; do
    require_text "$contract" "$contract_text"
done

unreleased_section="$(/usr/bin/awk '
    /^## Unreleased$/ { capture = 1; next }
    /^## / && capture { exit }
    capture { print }
' "$repository_root/CHANGELOG.md")"
[[ -z "${unreleased_section//[[:space:]]/}" ]] || \
    fail "The current Unreleased changelog section must be empty after drafting 0.3.0."

v03_section="$(/usr/bin/awk '
    /^## 0\.3\.0 - Unreleased$/ { capture = 1; next }
    /^## / && capture { exit }
    capture { print }
' "$repository_root/CHANGELOG.md")"
for changelog_text in \
    'Text Languages editor' \
    'encrypted capture history' \
    'Removed ellipses'; do
    [[ "$v03_section" == *"$changelog_text"* ]] || \
        fail "The 0.3.0 changelog draft is missing: $changelog_text"
done

for workflow_text in \
    'release_goal=G55' \
    'release_subdirectory=g55' \
    'release_candidate_tag "$COPYLASSO_CANDIDATE_NUMBER"'; do
    require_text "$workflow" "$workflow_text"
done

require_text "$repository_root/CopyLassoTests/Settings/UserDefaultsSettingsStoreTests.swift" \
    'testVersion022PreferencesUpgradeToVersion030WithSafeFeatureDefaults'
require_text "$repository_root/docs/testing.md" '## G54 v0.3 Source Qualification'
require_text "$repository_root/docs/release-packaging.md" \
    '## G54 exact-head qualification package'
require_text "$repository_root/docs/security-and-privacy-review.md" \
    'G54 adds no entitlement, dependency, network destination, capture command, or'

if /usr/bin/grep -nE \
    'release upload|release edit.+--draft=false|make_latest=true|git push.+v0\.3\.0|git tag.+v0\.3\.0' \
    "$workflow"; then
    fail "G54 must not add a publication or final-tag path."
fi

entitlements_json="$(/usr/bin/plutil -convert json -o - "$entitlements")" || \
    fail "CopyLasso entitlements are invalid."
if ! /usr/bin/jq -e '
    (keys | sort) == [
        "com.apple.security.app-sandbox",
        "com.apple.security.network.client",
        "com.apple.security.temporary-exception.mach-lookup.global-name"
    ]
' <<< "$entitlements_json" >/dev/null; then
    fail "v0.3 qualification must not widen the reviewed entitlement set."
fi

if /usr/bin/find "$repository_root" \
    \( -path "$repository_root/.git" -o -path "$repository_root/.build" \) -prune -o \
    -type f \( -iname '*latex*.mlmodel*' -o -iname '*latex*.onnx' -o -iname '*latex*.tflite' \) \
    -print | /usr/bin/grep -q .; then
    fail "v0.3 must not ship a LaTeX model or runtime artifact."
fi

echo "CopyLasso v0.3 release-qualification audit passed."
