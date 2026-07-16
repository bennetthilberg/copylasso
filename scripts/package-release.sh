#!/bin/bash

set -euo pipefail
umask 077

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/release-package-verification.sh
source "$repository_root/scripts/lib/release-package-verification.sh"

usage() {
    cat >&2 <<'TEXT'
Usage: package-release.sh \
  --handoff /path/to/G26/<commit> \
  --payload-commit <40-character-commit> \
  --output-dir /path/to/repository/dist/<run>
TEXT
    exit 64
}

handoff_candidate=""
payload_commit=""
output_candidate=""
readonly notary_profile="copylasso-notary"
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --handoff)
            [[ "$#" -ge 2 ]] || usage
            handoff_candidate="$2"
            shift 2
            ;;
        --payload-commit)
            [[ "$#" -ge 2 ]] || usage
            payload_commit="$2"
            shift 2
            ;;
        --output-dir)
            [[ "$#" -ge 2 ]] || usage
            output_candidate="$2"
            shift 2
            ;;
        *) usage ;;
    esac
done

[[ -n "$handoff_candidate" && -n "$payload_commit" && -n "$output_candidate" ]] || usage
[[ "$payload_commit" =~ ^[0-9a-f]{40}$ ]] || \
    release_package_fail "The payload commit must be a full lowercase Git object identifier."
readonly expected_team_identifier="${COPYLASSO_EXPECTED_TEAM_ID:-}"
if [[ ! "$expected_team_identifier" =~ ^[A-Z0-9]{10}$ ]]; then
    release_package_fail \
        "COPYLASSO_EXPECTED_TEAM_ID must provide the approved release team outside the repository."
fi

[[ -d "$handoff_candidate" ]] || release_package_fail "The G26 handoff directory is missing."
readonly handoff_parent="$(cd "$(dirname "$handoff_candidate")" && /bin/pwd -P)"
readonly handoff="$handoff_parent/$(basename "$handoff_candidate")"
if [[ "$(basename "$handoff")" != "$payload_commit" ]]; then
    release_package_fail "The G26 handoff directory must be named for the payload commit."
fi
readonly payload_app="$handoff/export/CopyLasso.app"
readonly payload_dsym="$handoff/CopyLasso.xcarchive/dSYMs/CopyLasso.app.dSYM"
readonly payload_submission="$handoff/notary-submission.json"
readonly payload_log="$handoff/notary-log.json"
[[ -d "$payload_app" ]] || release_package_fail "The G26 handoff application is missing."
[[ -d "$payload_dsym" ]] || release_package_fail "The matching G26 dSYM is missing."
assert_release_notary_records "$payload_submission" "$payload_log"

cd "$repository_root"
readonly packaging_commit="$(/usr/bin/git rev-parse HEAD)"
[[ "$packaging_commit" =~ ^[0-9a-f]{40}$ ]] || \
    release_package_fail "The packaging source must be an exact Git commit."
/usr/bin/git cat-file -e "$payload_commit^{commit}" || \
    release_package_fail "The payload commit is not available in this repository."
/usr/bin/git merge-base --is-ancestor "$payload_commit" "$packaging_commit" || \
    release_package_fail "The payload commit is not an ancestor of the packaging commit."
if ! /usr/bin/git diff --quiet || ! /usr/bin/git diff --cached --quiet || \
    [[ -n "$(/usr/bin/git status --porcelain --untracked-files=no)" ]]; then
    release_package_fail "Release packaging requires a clean tracked worktree."
fi
if ! /usr/bin/git diff --quiet "$payload_commit..$packaging_commit" -- \
    BrandAssets \
    Configuration/CopyLasso-Info.plist \
    Configuration/Shared.xcconfig \
    CopyLasso \
    CopyLasso.xcodeproj \
    THIRD_PARTY_NOTICES.md; then
    release_package_fail \
        "Application inputs changed after the qualified G26 payload commit; rebuild is outside G27."
fi

case "$output_candidate" in
    /*) ;;
    *) output_candidate="$PWD/$output_candidate" ;;
esac
if [[ "$output_candidate" == *"/../"* ]] || [[ "$output_candidate" == */.. ]]; then
    release_package_fail "The release output path must not contain parent traversal."
fi
case "$output_candidate" in
    "$repository_root"/dist/*) ;;
    *) release_package_fail "Release output must remain under the repository's ignored dist directory." ;;
esac
readonly output_parent_candidate="$(dirname "$output_candidate")"
/bin/mkdir -p "$output_parent_candidate"
readonly output_parent="$(cd "$output_parent_candidate" && /bin/pwd -P)"
case "$output_parent" in
    "$repository_root"/dist | "$repository_root"/dist/*) ;;
    *) release_package_fail "The canonical release output escapes the ignored dist directory." ;;
esac
readonly output_directory="$output_parent/$(basename "$output_candidate")"
[[ ! -e "$output_directory" ]] || \
    release_package_fail "The release output directory already exists; use a fresh run directory."
/bin/mkdir "$output_directory"

readonly temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/copylasso-release-package.XXXXXX")"
cleanup() {
    /bin/rm -rf "$temporary_directory"
}
trap cleanup EXIT

if ! COPYLASSO_EXPECTED_TEAM_ID="$expected_team_identifier" \
    "$repository_root/scripts/verify-developer-id-app.sh" --post-notarization "$payload_app" \
    > "$output_directory/payload-verification.txt"; then
    release_package_fail "The exact G26 application no longer passes final verification."
fi

readonly staging_directory="$temporary_directory/volume"
/bin/mkdir "$staging_directory"
/usr/bin/ditto "$payload_app" "$staging_directory/CopyLasso.app"
/bin/ln -s /Applications "$staging_directory/Applications"
assert_release_volume_layout "$staging_directory"
create_release_payload_manifest "$payload_app" "$output_directory/payload-manifest.txt"
create_release_payload_manifest \
    "$staging_directory/CopyLasso.app" \
    "$temporary_directory/staged-payload.manifest"
assert_release_payload_manifests_match \
    "$output_directory/payload-manifest.txt" \
    "$temporary_directory/staged-payload.manifest"

readonly dmg="$output_directory/$COPYLASSO_RELEASE_DMG"
if ! /usr/bin/hdiutil create \
    -srcfolder "$staging_directory" \
    -volname "CopyLasso $COPYLASSO_RELEASE_VERSION" \
    -fs HFS+ \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$dmg" > "$output_directory/hdiutil-create.log" 2>&1; then
    release_package_fail "The release disk image could not be created."
fi

identity_records="$(/usr/bin/security find-identity -v -p codesigning 2>/dev/null || true)"
matching_identities="$(printf '%s\n' "$identity_records" | \
    /usr/bin/awk -v team="$expected_team_identifier" '
        $0 ~ /"Developer ID Application:/ && $0 ~ "\\(" team "\\)\"$" { print $2 }
    ')"
identity_count="$(printf '%s\n' "$matching_identities" | /usr/bin/awk 'NF { count += 1 } END { print count + 0 }')"
if [[ "$identity_count" != "1" ]]; then
    release_package_fail "Exactly one valid Developer ID Application identity must match the approved team."
fi
readonly signing_identity="$(printf '%s\n' "$matching_identities" | /usr/bin/head -n 1)"
unset identity_records matching_identities

if ! /usr/bin/codesign \
    --sign "$signing_identity" \
    --timestamp \
    --identifier "$COPYLASSO_RELEASE_DMG_IDENTIFIER" \
    "$dmg" > "$output_directory/dmg-signing.log" 2>&1; then
    release_package_fail "The release disk image could not be signed."
fi
if ! /usr/bin/codesign --verify --strict --verbose=2 "$dmg" \
    > "$output_directory/dmg-signature-verification.log" 2>&1; then
    release_package_fail "The signed release disk image failed strict verification."
fi

readonly submission_record="$output_directory/notary-submission.json"
readonly diagnostic_log="$output_directory/notary-log.json"
if ! xcrun notarytool submit "$dmg" \
    --keychain-profile "$notary_profile" \
    --wait \
    --output-format json > "$submission_record"; then
    release_package_fail "The disk-image notarization submission did not complete."
fi
readonly submission_identifier="$(/usr/bin/plutil -extract id raw "$submission_record" 2>/dev/null || true)"
[[ -n "$submission_identifier" ]] || \
    release_package_fail "The notarization response did not include a submission identifier."
if ! xcrun notarytool log "$submission_identifier" \
    --keychain-profile "$notary_profile" \
    "$diagnostic_log" > "$output_directory/notary-log-fetch.log" 2>&1; then
    release_package_fail "The disk-image notarization diagnostic log could not be saved."
fi
assert_release_notary_records "$submission_record" "$diagnostic_log"

if ! xcrun stapler staple "$dmg" > "$output_directory/staple.log" 2>&1; then
    release_package_fail "The notarization ticket could not be stapled to the disk image."
fi
if ! xcrun stapler validate "$dmg" > "$output_directory/stapler-validation.log" 2>&1; then
    release_package_fail "The stapled disk-image ticket did not validate."
fi

(
    cd "$output_directory"
    /usr/bin/shasum -a 256 "$COPYLASSO_RELEASE_DMG" > "$COPYLASSO_RELEASE_CHECKSUM"
)
if ! /usr/bin/ditto -c -k --norsrc --noextattr --keepParent \
    "$payload_dsym" "$output_directory/$COPYLASSO_RELEASE_DSYM"; then
    release_package_fail "The matching release dSYM could not be archived."
fi

readonly executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' \
    "$payload_app/Contents/Info.plist")"
/usr/bin/dwarfdump --uuid "$payload_app/Contents/MacOS/$executable_name" \
    > "$output_directory/application-uuids.txt"
/usr/bin/dwarfdump --uuid "$payload_dsym" > "$output_directory/dsym-uuids.txt"
assert_release_uuid_sets_match \
    "$output_directory/application-uuids.txt" \
    "$output_directory/dsym-uuids.txt"
normalized_release_uuids "$output_directory/dsym-uuids.txt" \
    > "$temporary_directory/normalized-dsym-uuids.txt"

readonly dmg_hash="$(/usr/bin/shasum -a 256 "$dmg" | /usr/bin/awk '{print $1}')"
readonly dmg_size="$(/usr/bin/stat -f '%z' "$dmg")"
readonly app_manifest_hash="$(/usr/bin/shasum -a 256 \
    "$output_directory/payload-manifest.txt" | /usr/bin/awk '{print $1}')"
readonly dsym_uuid_hash="$(/usr/bin/shasum -a 256 \
    "$temporary_directory/normalized-dsym-uuids.txt" | /usr/bin/awk '{print $1}')"
{
    printf 'version=%s\n' "$COPYLASSO_RELEASE_VERSION"
    printf 'build=%s\n' "$COPYLASSO_RELEASE_BUILD"
    printf 'payload_commit=%s\n' "$payload_commit"
    printf 'packaging_commit=%s\n' "$packaging_commit"
    printf 'dmg_identifier=%s\n' "$COPYLASSO_RELEASE_DMG_IDENTIFIER"
    printf 'dmg_filename=%s\n' "$COPYLASSO_RELEASE_DMG"
    printf 'dmg_sha256=%s\n' "$dmg_hash"
    printf 'dmg_size_bytes=%s\n' "$dmg_size"
    printf 'app_manifest_sha256=%s\n' "$app_manifest_hash"
    printf 'dsym_uuid_manifest_sha256=%s\n' "$dsym_uuid_hash"
    printf 'notary_submission_id=%s\n' "$submission_identifier"
} > "$output_directory/release-evidence.txt"

COPYLASSO_EXPECTED_TEAM_ID="$expected_team_identifier" \
    "$repository_root/scripts/verify-release-package.sh" \
    --payload-app "$payload_app" \
    --payload-commit "$payload_commit" \
    --packaging-commit "$packaging_commit" \
    "$output_directory" > "$output_directory/release-verification.txt"

echo "CopyLasso release package created and verified in $output_directory."
