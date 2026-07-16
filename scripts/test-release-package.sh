#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly audit_script="$repository_root/scripts/audit-release-package.sh"
readonly package_script="$repository_root/scripts/package-release.sh"
readonly verifier_script="$repository_root/scripts/verify-release-package.sh"
readonly comparator_script="$repository_root/scripts/compare-release-packages.sh"
readonly verifier_library="$repository_root/scripts/lib/release-package-verification.sh"
readonly packaging_documentation="$repository_root/docs/release-packaging.md"

fail() {
    echo "$1" >&2
    exit 1
}

for executable in "$audit_script" "$package_script" "$verifier_script" "$comparator_script"; do
    [[ -x "$executable" ]] || fail "Release-package executable is missing: $(basename "$executable")"
done
[[ -r "$verifier_library" ]] || fail "Release-package verification library is missing."
[[ -r "$packaging_documentation" ]] || fail "Release-packaging documentation is missing."
if /usr/bin/grep -q -- '--notary-profile' "$package_script"; then
    fail "Release packaging must use only the G26 copylasso-notary profile."
fi
for required_commit_option in --payload-commit --packaging-commit; do
    /usr/bin/grep -Fq -- "$required_commit_option" "$verifier_script" || \
        fail "Release verification must require $required_commit_option."
    /usr/bin/grep -Fq -- "$required_commit_option" "$package_script" || \
        fail "Release packaging must pass $required_commit_option to verification."
done

# shellcheck source=scripts/lib/release-package-verification.sh
source "$verifier_library"

expect_failure() {
    local expected_message="$1"
    shift
    local output

    if output="$("$@" 2>&1)"; then
        fail "Expected command to fail: $*"
    fi
    if [[ "$output" != *"$expected_message"* ]]; then
        fail "Expected failure containing '$expected_message', received '$output'."
    fi
}

readonly temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/copylasso-g27-tests.XXXXXX")"
trap 'rm -rf "$temporary_directory"' EXIT

valid_layout="$temporary_directory/valid-layout"
mkdir -p "$valid_layout/CopyLasso.app/Contents/MacOS"
echo 'fixture executable' > "$valid_layout/CopyLasso.app/Contents/MacOS/CopyLasso"
ln -s /Applications "$valid_layout/Applications"
assert_release_volume_layout "$valid_layout"

cp -R "$valid_layout" "$temporary_directory/extra-layout"
echo 'unexpected' > "$temporary_directory/extra-layout/README.txt"
expect_failure "exactly CopyLasso.app and Applications" \
    assert_release_volume_layout "$temporary_directory/extra-layout"

cp -R "$valid_layout" "$temporary_directory/wrong-link-layout"
rm "$temporary_directory/wrong-link-layout/Applications"
ln -s /tmp "$temporary_directory/wrong-link-layout/Applications"
expect_failure "must resolve to /Applications" \
    assert_release_volume_layout "$temporary_directory/wrong-link-layout"

mkdir -p "$temporary_directory/missing-app-layout"
ln -s /Applications "$temporary_directory/missing-app-layout/Applications"
expect_failure "exactly CopyLasso.app and Applications" \
    assert_release_volume_layout "$temporary_directory/missing-app-layout"

external_app="$temporary_directory/external/CopyLasso.app"
mkdir -p "$external_app"
symlink_app_layout="$temporary_directory/symlink-app-layout"
mkdir -p "$symlink_app_layout"
ln -s "$external_app" "$symlink_app_layout/CopyLasso.app"
ln -s /Applications "$symlink_app_layout/Applications"
expect_failure "must be a real directory" \
    assert_release_volume_layout "$symlink_app_layout"

source_app="$temporary_directory/source/CopyLasso.app"
mkdir -p "$source_app/Contents/MacOS" "$source_app/Contents/Resources"
printf 'binary fixture\n' > "$source_app/Contents/MacOS/CopyLasso"
printf 'resource fixture\n' > "$source_app/Contents/Resources/content.txt"
ln -s content.txt "$source_app/Contents/Resources/current.txt"
chmod 755 "$source_app/Contents/MacOS/CopyLasso"

source_manifest="$temporary_directory/source.manifest"
same_manifest="$temporary_directory/same.manifest"
changed_manifest="$temporary_directory/changed.manifest"
create_release_payload_manifest "$source_app" "$source_manifest"
create_release_payload_manifest "$source_app" "$same_manifest"
assert_release_payload_manifests_match "$source_manifest" "$same_manifest"
printf 'changed\n' >> "$source_app/Contents/Resources/content.txt"
create_release_payload_manifest "$source_app" "$changed_manifest"
expect_failure "payload differs from the qualified G26 application" \
    assert_release_payload_manifests_match "$source_manifest" "$changed_manifest"

dmg_fixture="$temporary_directory/CopyLasso-0.1.0.dmg"
printf 'disk image fixture\n' > "$dmg_fixture"
checksum_fixture="$temporary_directory/CopyLasso-0.1.0.dmg.sha256"
(
    cd "$temporary_directory"
    /usr/bin/shasum -a 256 "$(basename "$dmg_fixture")" > "$(basename "$checksum_fixture")"
)
assert_release_checksum "$dmg_fixture" "$checksum_fixture"
(
    readonly dmg="$dmg_fixture"
    readonly checksum_file="$checksum_fixture"
    assert_release_checksum "$dmg_fixture" "$checksum_fixture"
)

wrong_checksum="$temporary_directory/wrong.sha256"
printf '%064d  CopyLasso-0.1.0.dmg\n' 0 > "$wrong_checksum"
expect_failure "checksum does not match" assert_release_checksum "$dmg_fixture" "$wrong_checksum"

wrong_name_checksum="$temporary_directory/wrong-name.sha256"
checksum_value="$(/usr/bin/shasum -a 256 "$dmg_fixture" | /usr/bin/awk '{print $1}')"
printf '%s  Other.dmg\n' "$checksum_value" > "$wrong_name_checksum"
expect_failure "must name CopyLasso-0.1.0.dmg" \
    assert_release_checksum "$dmg_fixture" "$wrong_name_checksum"

valid_signature="$temporary_directory/valid-dmg-signature.txt"
cat > "$valid_signature" <<'TEXT'
Identifier=io.github.bennetthilberg.copylasso.dmg
Signature size=9000
Authority=Developer ID Application: Redacted
Authority=Developer ID Certification Authority
Authority=Apple Root CA
Timestamp=Jul 16, 2026 at 12:00:00 PM
TeamIdentifier=REDACTED
TEXT
assert_release_dmg_signature "$valid_signature" "REDACTED"
(
    readonly expected_team_identifier="REDACTED"
    readonly signature_record="$valid_signature"
    assert_release_dmg_signature "$valid_signature" "REDACTED"
)

sed '/Developer ID Application/d' "$valid_signature" > "$temporary_directory/development-signature.txt"
expect_failure "Developer ID Application" assert_release_dmg_signature \
    "$temporary_directory/development-signature.txt" "REDACTED"
sed '/Timestamp=/d' "$valid_signature" > "$temporary_directory/no-timestamp-signature.txt"
expect_failure "secure timestamp" assert_release_dmg_signature \
    "$temporary_directory/no-timestamp-signature.txt" "REDACTED"
sed 's/io.github.bennetthilberg.copylasso.dmg/io.github.bennetthilberg.copylasso.debug.dmg/' \
    "$valid_signature" > "$temporary_directory/wrong-identifier-signature.txt"
expect_failure "release disk-image identifier" assert_release_dmg_signature \
    "$temporary_directory/wrong-identifier-signature.txt" "REDACTED"
sed 's/TeamIdentifier=REDACTED/TeamIdentifier=DIFFERENT/' \
    "$valid_signature" > "$temporary_directory/wrong-team-signature.txt"
expect_failure "approved release team" assert_release_dmg_signature \
    "$temporary_directory/wrong-team-signature.txt" "REDACTED"

valid_gatekeeper="$temporary_directory/valid-dmg-gatekeeper.txt"
cat > "$valid_gatekeeper" <<'TEXT'
/private/example/CopyLasso-0.1.0.dmg: accepted
source=Notarized Developer ID
origin=Developer ID Application: Redacted
TEXT
assert_release_dmg_gatekeeper "$valid_gatekeeper"
sed 's/Notarized Developer ID/Developer ID/' "$valid_gatekeeper" > \
    "$temporary_directory/developer-id-gatekeeper.txt"
assert_release_dmg_gatekeeper "$temporary_directory/developer-id-gatekeeper.txt"
sed 's/: accepted/: rejected/' "$valid_gatekeeper" > "$temporary_directory/rejected-gatekeeper.txt"
expect_failure "did not accept" assert_release_dmg_gatekeeper \
    "$temporary_directory/rejected-gatekeeper.txt"
sed 's/Developer ID Application: Redacted/Apple Development: Redacted/' \
    "$valid_gatekeeper" > "$temporary_directory/wrong-origin-gatekeeper.txt"
expect_failure "unexpected origin" assert_release_dmg_gatekeeper \
    "$temporary_directory/wrong-origin-gatekeeper.txt"

valid_imageinfo="$temporary_directory/valid-imageinfo.txt"
cat > "$valid_imageinfo" <<'TEXT'
Format Description: UDIF read-only compressed (zlib)
Format: UDZO
TEXT
assert_release_dmg_imageinfo "$valid_imageinfo"
sed 's/Format: UDZO/Format: UDRW/' "$valid_imageinfo" > "$temporary_directory/writable-imageinfo.txt"
expect_failure "read-only UDZO" assert_release_dmg_imageinfo \
    "$temporary_directory/writable-imageinfo.txt"

valid_diskutil="$temporary_directory/valid-diskutil.txt"
cat > "$valid_diskutil" <<'TEXT'
   Media Read-Only:           Yes
   Volume Read-Only:          Yes (read-only mount flag set)
TEXT
assert_release_read_only_mount "$valid_diskutil"
sed 's/Media Read-Only:           Yes/Media Read-Only:           No/' \
    "$valid_diskutil" > "$temporary_directory/writable-media.txt"
expect_failure "media is not read-only" assert_release_read_only_mount \
    "$temporary_directory/writable-media.txt"
sed 's/Volume Read-Only:          Yes/Volume Read-Only:          No/' \
    "$valid_diskutil" > "$temporary_directory/writable-volume.txt"
expect_failure "volume is not read-only" assert_release_read_only_mount \
    "$temporary_directory/writable-volume.txt"

valid_submission="$temporary_directory/valid-submission.json"
cat > "$valid_submission" <<'JSON'
{"id":"00000000-0000-0000-0000-000000000000","status":"Accepted"}
JSON
valid_log="$temporary_directory/valid-notary-log.json"
cat > "$valid_log" <<'JSON'
{"jobId":"00000000-0000-0000-0000-000000000000","status":"Accepted","issues":[]}
JSON
assert_release_notary_records "$valid_submission" "$valid_log"
(
    readonly submission_record="$valid_submission"
    readonly diagnostic_log="$valid_log"
    assert_release_notary_records "$valid_submission" "$valid_log"
)

null_issues_log="$temporary_directory/null-issues-log.json"
cat > "$null_issues_log" <<'JSON'
{
  "jobId": "00000000-0000-0000-0000-000000000000",
  "status": "Accepted",
  "issues": null
}
JSON
assert_release_notary_records "$valid_submission" "$null_issues_log"

sed 's/Accepted/Invalid/' "$valid_submission" > "$temporary_directory/invalid-submission.json"
expect_failure "submission was not accepted" assert_release_notary_records \
    "$temporary_directory/invalid-submission.json" "$valid_log"
cat > "$temporary_directory/warning-log.json" <<'JSON'
{"jobId":"00000000-0000-0000-0000-000000000000","status":"Accepted","issues":[{"severity":"warning"}]}
JSON
expect_failure "contains issues" assert_release_notary_records \
    "$valid_submission" "$temporary_directory/warning-log.json"

valid_app_uuids="$temporary_directory/app-uuids.txt"
valid_dsym_uuids="$temporary_directory/dsym-uuids.txt"
cat > "$valid_app_uuids" <<'TEXT'
UUID: AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA (arm64) CopyLasso
UUID: BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB (x86_64) CopyLasso
TEXT
cat > "$valid_dsym_uuids" <<'TEXT'
UUID: BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB (x86_64) CopyLasso
UUID: AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA (arm64) CopyLasso
TEXT
assert_release_uuid_sets_match "$valid_app_uuids" "$valid_dsym_uuids"
sed 's/BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB/CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC/' \
    "$valid_dsym_uuids" > "$temporary_directory/wrong-dsym-uuids.txt"
expect_failure "dSYM UUIDs do not match" assert_release_uuid_sets_match \
    "$valid_app_uuids" "$temporary_directory/wrong-dsym-uuids.txt"

portable_evidence="$temporary_directory/portable-evidence.txt"
cat > "$portable_evidence" <<'TEXT'
version=0.1.0
build=1
TEXT
assert_release_evidence_is_portable "$portable_evidence"
absolute_path_evidence="$temporary_directory/absolute-path-evidence.txt"
cat > "$absolute_path_evidence" <<'TEXT'
version=0.1.0
local_artifact=/local/build/output
TEXT
expect_failure "must not contain local absolute paths" \
    assert_release_evidence_is_portable "$absolute_path_evidence"

assert_release_commit_matches \
    "payload" \
    "1111111111111111111111111111111111111111" \
    "1111111111111111111111111111111111111111"
expect_failure "payload commit does not match" \
    assert_release_commit_matches \
    "payload" \
    "1111111111111111111111111111111111111111" \
    "2222222222222222222222222222222222222222"
expect_failure "expected payload commit is invalid" \
    assert_release_commit_matches "payload" "not-a-commit" "not-a-commit"

assert_release_artifact_names \
    "CopyLasso-0.1.0.dmg" \
    "CopyLasso-0.1.0.dmg.sha256" \
    "CopyLasso-0.1.0.dSYM.zip"
expect_failure "release artifact names" assert_release_artifact_names \
    "CopyLasso-latest.dmg" \
    "CopyLasso-0.1.0.dmg.sha256" \
    "CopyLasso-0.1.0.dSYM.zip"

for run_name in comparison-1 comparison-2; do
    run="$temporary_directory/$run_name"
    mkdir "$run"
    printf 'equivalent image fixture\n' > "$run/CopyLasso-0.1.0.dmg"
    printf 'symbol fixture\n' > "$run/CopyLasso-0.1.0.dSYM.zip"
    cp "$source_manifest" "$run/payload-manifest.txt"
    (
        cd "$run"
        /usr/bin/shasum -a 256 CopyLasso-0.1.0.dmg > CopyLasso-0.1.0.dmg.sha256
    )
    cat > "$run/release-evidence.txt" <<'TEXT'
version=0.1.0
build=1
payload_commit=1111111111111111111111111111111111111111
packaging_commit=2222222222222222222222222222222222222222
dmg_identifier=io.github.bennetthilberg.copylasso.dmg
dmg_filename=CopyLasso-0.1.0.dmg
app_manifest_sha256=3333333333333333333333333333333333333333333333333333333333333333
dsym_uuid_manifest_sha256=4444444444444444444444444444444444444444444444444444444444444444
TEXT
done
"$comparator_script" \
    "$temporary_directory/comparison-1" \
    "$temporary_directory/comparison-2" >/dev/null
sed -i '' 's/build=1/build=2/' "$temporary_directory/comparison-2/release-evidence.txt"
expect_failure "normalized evidence: build" "$comparator_script" \
    "$temporary_directory/comparison-1" \
    "$temporary_directory/comparison-2"

echo "Release-package contract tests passed."
