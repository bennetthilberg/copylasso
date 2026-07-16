#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly package_script="$repository_root/scripts/package-release.sh"
readonly verifier_script="$repository_root/scripts/verify-release-package.sh"
readonly comparator_script="$repository_root/scripts/compare-release-packages.sh"
readonly test_script="$repository_root/scripts/test-release-package.sh"
readonly verifier_library="$repository_root/scripts/lib/release-package-verification.sh"
readonly packaging_documentation="$repository_root/docs/release-packaging.md"
readonly release_checklist="$repository_root/docs/release-checklist.md"

fail() {
    echo "$1" >&2
    exit 1
}

for executable in "$package_script" "$verifier_script" "$comparator_script" "$test_script"; do
    [[ -x "$executable" ]] || fail "Release-package script is missing or not executable: $(basename "$executable")"
done
for readable in "$verifier_library" "$packaging_documentation" "$release_checklist"; do
    [[ -r "$readable" ]] || fail "Release-package contract file is missing: $(basename "$readable")"
done

if ! /usr/bin/grep -Fxq '/dist/' "$repository_root/.gitignore" || \
    ! /usr/bin/grep -Fxq '*.dmg' "$repository_root/.gitignore" || \
    ! /usr/bin/grep -Fxq '*.dSYM' "$repository_root/.gitignore"; then
    fail "Generated release packages and symbols must remain ignored."
fi

for required_pattern in \
    'verify-developer-id-app.sh' \
    'git diff --quiet' \
    'Application inputs changed after the qualified G26 payload commit' \
    'dist/*' \
    '/usr/bin/ditto' \
    '/bin/ln -s /Applications' \
    'assert_release_volume_layout' \
    '-format UDZO' \
    '--timestamp' \
    'io.github.bennetthilberg.copylasso.dmg' \
    '--keychain-profile' \
    '--wait' \
    'notarytool log' \
    'stapler staple' \
    'stapler validate' \
    'CopyLasso-0.1.0.dmg.sha256' \
    'CopyLasso-0.1.0.dSYM.zip' \
    'release-evidence.txt'; do
    /usr/bin/grep -Fq -- "$required_pattern" "$package_script" "$verifier_library" || \
        fail "The package script is missing a required release step: $required_pattern"
done

if /usr/bin/grep -Eq 'xcodebuild|exportArchive|archivePath' "$package_script"; then
    fail "G27 must package the exact G26 application without rebuilding or exporting it."
fi
if /usr/bin/grep -Eq -- '--password|--apple-id|AC_PASSWORD|APPLE_ID' \
    "$package_script" "$verifier_script" "$packaging_documentation"; then
    fail "Release packaging must authenticate only through the saved Keychain profile."
fi

for required_pattern in \
    'assert_release_checksum' \
    'assert_release_notary_records' \
    'codesign --verify --strict' \
    'assert_release_dmg_signature' \
    'stapler validate' \
    'spctl --assess --type open --context context:primary-signature' \
    'hdiutil imageinfo' \
    'hdiutil attach -readonly -nobrowse' \
    'diskutil info' \
    'assert_release_volume_layout' \
    'verify-developer-id-app.sh' \
    'assert_release_payload_manifests_match' \
    'dwarfdump --uuid' \
    'assert_release_uuid_sets_match'; do
    /usr/bin/grep -Fq -- "$required_pattern" "$verifier_script" || \
        fail "The release verifier is missing a required check: $required_pattern"
done

for required_phrase in \
    'exact G26' \
    'copylasso-notary' \
    'CopyLasso-0.1.0.dmg' \
    'CopyLasso-0.1.0.dmg.sha256' \
    'CopyLasso-0.1.0.dSYM.zip' \
    'two complete runs' \
    'payload commit' \
    'packaging commit' \
    'Applications' \
    'G28' \
    'Do not publish'; do
    /usr/bin/grep -Fiq -- "$required_phrase" "$packaging_documentation" || \
        fail "Release-packaging documentation is missing required guidance: $required_phrase"
done

if /usr/bin/grep -Eq "TeamIdentifier=[A-Z0-9]{10}|[[:alnum:]._%+-]+@[[:alnum:].-]+\.[A-Za-z]{2,}|[a-z]{4}-[a-z]{4}-[a-z]{4}-[a-z]{4}" \
    "$package_script" \
    "$verifier_script" \
    "$comparator_script" \
    "$verifier_library" \
    "$packaging_documentation"; then
    fail "Release-package public files contain an account value, team value, or credential-like text."
fi

echo "Release-package static audit passed."
