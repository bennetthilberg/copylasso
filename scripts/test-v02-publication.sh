#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly workflow="$repository_root/.github/workflows/prepare-publication.yml"
readonly verifier_library="$repository_root/scripts/lib/v02-publication-verification.sh"
readonly release_package_library="$repository_root/scripts/lib/release-package-verification.sh"
readonly transaction_library="$repository_root/scripts/lib/v02-publication-transaction.sh"
readonly candidate_downloader="$repository_root/scripts/download-v02-candidate.sh"
readonly package_verifier="$repository_root/scripts/verify-v02-candidate-package.sh"
readonly generic_package_verifier="$repository_root/scripts/verify-release-package.sh"
readonly appcast_generator="$repository_root/scripts/generate-release-appcast.sh"
readonly draft_creator="$repository_root/scripts/create-v02-publication-draft.sh"
readonly feed_preparer="$repository_root/scripts/prepare-update-feed.sh"
readonly audit_script="$repository_root/scripts/audit-v02-publication.sh"
readonly runbook="$repository_root/docs/v0.2-publication-runbook.md"

fail() {
    echo "$1" >&2
    exit 1
}

for executable in \
    "$candidate_downloader" \
    "$package_verifier" \
    "$appcast_generator" \
    "$draft_creator" \
    "$feed_preparer" \
    "$audit_script"; do
    [[ -x "$executable" ]] || \
        fail "G49 publication executable is missing: $(/usr/bin/basename "$executable")"
done

for readable in \
    "$workflow" \
    "$verifier_library" \
    "$release_package_library" \
    "$transaction_library" \
    "$generic_package_verifier" \
    "$runbook"; do
    [[ -r "$readable" ]] || \
        fail "G49 publication contract file is missing: $(/usr/bin/basename "$readable")"
done

# shellcheck source=scripts/lib/v02-publication-verification.sh
source "$verifier_library"
# shellcheck source=scripts/lib/v02-publication-transaction.sh
source "$transaction_library"

[[ "$COPYLASSO_RELEASE_APPCAST" == "CopyLasso-0.2.1-appcast.xml" ]] || \
    fail "The G49 verifier must pin the approved restricted appcast filename."

feed_step="$(/usr/bin/sed -n \
    '/- name: Prepare feed-only deployment bundle/,/- name: Create verified private final draft/p' \
    "$workflow")"
[[ "$feed_step" == *'source ./scripts/lib/v02-publication-verification.sh'* ]] || \
    fail "The G49 feed step must load pinned v0.2.1 publication metadata."
[[ "$feed_step" != *'source ./scripts/lib/release-metadata.sh'* ]] || \
    fail "The G49 feed step must not load mutable current release metadata."
[[ "$feed_step" == *'--release-notes "scripts/fixtures/v0.2.1-published-release-notes.md"'* ]] || \
    fail "The G49 feed step must use the byte-exact published v0.2.1 notes fixture."

/usr/bin/grep -Fq -- \
    '$repository_root/$COPYLASSO_V02_RELEASE_NOTES' \
    "$candidate_downloader" || \
    fail "The candidate downloader must validate against the selected immutable notes."
if /usr/bin/grep -Fq -- \
    'docs/release-notes/$COPYLASSO_RELEASE_VERSION.md' \
    "$candidate_downloader"; then
    fail "The candidate downloader must not validate against mutable reader-facing notes."
fi

if /usr/bin/grep -Fq -- '--pinned-v02-metadata' "$package_verifier"; then
    fail "G49 package verification must use current 0.2.1 release metadata."
fi
/usr/bin/grep -Fq -- \
    '--release-metadata-profile "$COPYLASSO_V02_RELEASE_PACKAGE_PROFILE"' \
    "$package_verifier" || \
    fail "The candidate verifier must select immutable package metadata."
/usr/bin/grep -Fq -- '--pinned-v02-metadata' "$generic_package_verifier" || \
    fail "The generic verifier must retain explicit historical v0.2.0 support."

pinned_v021_package_metadata="$(
    COPYLASSO_RELEASE_PACKAGE_METADATA_PROFILE=v0.2.1 \
        /bin/bash -c '
            source "$1"
            printf "%s|%s|%s|%s|%s\n" \
                "$COPYLASSO_RELEASE_VERSION" \
                "$COPYLASSO_RELEASE_BUILD" \
                "$COPYLASSO_RELEASE_DMG" \
                "$COPYLASSO_RELEASE_DSYM" \
                "$COPYLASSO_RELEASE_APPCAST"
        ' _ "$release_package_library"
)"
[[ "$pinned_v021_package_metadata" == \
    '0.2.1|4|CopyLasso-0.2.1.dmg|CopyLasso-0.2.1.dSYM.zip|CopyLasso-0.2.1-appcast.xml' ]] || \
    fail "The v0.2.1 package profile must resolve only immutable candidate metadata."

pinned_package_metadata="$(
    COPYLASSO_RELEASE_PACKAGE_METADATA_PROFILE=v0.2.0 \
        /bin/bash -c '
            source "$1"
            printf "%s|%s|%s|%s|%s\n" \
                "$COPYLASSO_RELEASE_VERSION" \
                "$COPYLASSO_RELEASE_BUILD" \
                "$COPYLASSO_RELEASE_DMG" \
                "$COPYLASSO_RELEASE_DSYM" \
                "$COPYLASSO_RELEASE_APPCAST"
        ' _ "$release_package_library"
)"
[[ "$pinned_package_metadata" == \
    '0.2.0|3|CopyLasso-0.2.0.dmg|CopyLasso-0.2.0.dSYM.zip|CopyLasso-0.2.0-appcast.xml' ]] || \
    fail "The explicit historical package profile must resolve only pinned v0.2 metadata."

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

readonly release_notes_path="$repository_root/scripts/fixtures/v0.2.1-published-release-notes.md"
assert_v02_repository "bennetthilberg/copylasso"
expect_failure "only on the reviewed CopyLasso repository" \
    assert_v02_repository "other/repository"
assert_v02_candidate_commit "$COPYLASSO_V02_CANDIDATE_COMMIT"
expect_failure "only the approved G48 source commit" \
    assert_v02_candidate_commit "0123456789abcdef0123456789abcdef01234567"
assert_v02_final_tag "v0.2.1"
expect_failure "final v0.2 release tag is invalid" \
    assert_v02_final_tag "v0.2.1-rc.1"
assert_v02_release_notes "$release_notes_path"

readonly temporary_directory="$(/usr/bin/mktemp -d \
    "${TMPDIR:-/private/tmp}/copylasso-g49-tests.XXXXXX")"
trap '/bin/rm -rf "$temporary_directory"' EXIT
readonly verifier_fixture_commit="$(git -C "$repository_root" rev-parse HEAD)"
readonly verifier_payload="$temporary_directory/payload/$verifier_fixture_commit/export/CopyLasso.app"
readonly verifier_run="$temporary_directory/release-run"
/bin/mkdir -p "$verifier_payload" "$verifier_run"
expect_failure \
    'A required release-package artifact is missing: CopyLasso-0.2.1.dmg' \
    /usr/bin/env COPYLASSO_EXPECTED_TEAM_ID=AAAAAAAAAA \
    "$generic_package_verifier" \
    --release-metadata-profile v0.2.1 \
    --payload-app "$verifier_payload" \
    --payload-commit "$verifier_fixture_commit" \
    --packaging-commit "$verifier_fixture_commit" \
    "$verifier_run"
readonly candidate_record="$temporary_directory/candidate.json"
/usr/bin/jq -n \
    --rawfile body "$release_notes_path" \
    --argjson id "$COPYLASSO_V02_CANDIDATE_RELEASE_ID" \
    --arg tag "$COPYLASSO_V02_CANDIDATE_TAG" \
    --arg commit "$COPYLASSO_V02_CANDIDATE_COMMIT" \
    --arg dmg_digest "sha256:$COPYLASSO_V02_DMG_SHA256" \
    --arg checksum_digest "sha256:$COPYLASSO_V02_CHECKSUM_SHA256" \
    --arg dsym_digest "sha256:$COPYLASSO_V02_DSYM_SHA256" \
    --arg verification_digest "sha256:$COPYLASSO_V02_VERIFICATION_SHA256" \
    --argjson dmg_size "$COPYLASSO_V02_DMG_SIZE" \
    --argjson checksum_size "$COPYLASSO_V02_CHECKSUM_SIZE" \
    --argjson dsym_size "$COPYLASSO_V02_DSYM_SIZE" \
    --argjson verification_size "$COPYLASSO_V02_VERIFICATION_SIZE" '
    {
      id: $id,
      draft: true,
      prerelease: true,
      published_at: null,
      tag_name: $tag,
      target_commitish: $commit,
      body: $body,
      assets: [
        {
          id: 1,
          name: "CopyLasso-0.2.1.dmg",
          size: $dmg_size,
          digest: $dmg_digest,
          state: "uploaded"
        },
        {
          id: 2,
          name: "CopyLasso-0.2.1.dmg.sha256",
          size: $checksum_size,
          digest: $checksum_digest,
          state: "uploaded"
        },
        {
          id: 3,
          name: "CopyLasso-0.2.1.dSYM.zip",
          size: $dsym_size,
          digest: $dsym_digest,
          state: "uploaded"
        },
        {
          id: 4,
          name: "CopyLasso-0.2.1-verification.zip",
          size: $verification_size,
          digest: $verification_digest,
          state: "uploaded"
        }
      ]
    }
' > "$candidate_record"
assert_v02_candidate_release_record "$candidate_record" "$release_notes_path"

/usr/bin/jq '.draft = false' "$candidate_record" > \
    "$temporary_directory/published-candidate.json"
expect_failure "identity or state is invalid" \
    assert_v02_candidate_release_record \
    "$temporary_directory/published-candidate.json" "$release_notes_path"
/usr/bin/jq \
    '(.assets[] | select(.name == "CopyLasso-0.2.1.dmg") | .digest) =
      "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' \
    "$candidate_record" > "$temporary_directory/mutated-candidate.json"
expect_failure "differs from the approved bytes" \
    assert_v02_candidate_release_record \
    "$temporary_directory/mutated-candidate.json" "$release_notes_path"
/usr/bin/jq 'del(.assets[3])' "$candidate_record" > \
    "$temporary_directory/incomplete-candidate.json"
expect_failure "unexpected asset set" \
    assert_v02_candidate_release_record \
    "$temporary_directory/incomplete-candidate.json" "$release_notes_path"

readonly public_draft="$temporary_directory/public-draft.json"
/usr/bin/jq -n \
    --rawfile body "$release_notes_path" \
    --arg tag "$COPYLASSO_V02_FINAL_TAG" \
    --arg commit "$COPYLASSO_V02_CANDIDATE_COMMIT" \
    --arg name "$COPYLASSO_V02_RELEASE_NAME" \
    --arg dmg_digest "sha256:$COPYLASSO_V02_DMG_SHA256" \
    --arg checksum_digest "sha256:$COPYLASSO_V02_CHECKSUM_SHA256" \
    --argjson dmg_size "$COPYLASSO_V02_DMG_SIZE" \
    --argjson checksum_size "$COPYLASSO_V02_CHECKSUM_SIZE" '
    {
      id: 900,
      draft: true,
      prerelease: false,
      published_at: null,
      tag_name: $tag,
      target_commitish: $commit,
      name: $name,
      body: $body,
      assets: [
        {
          id: 10,
          name: "CopyLasso-0.2.1.dmg",
          size: $dmg_size,
          digest: $dmg_digest,
          state: "uploaded"
        },
        {
          id: 11,
          name: "CopyLasso-0.2.1.dmg.sha256",
          size: $checksum_size,
          digest: $checksum_digest,
          state: "uploaded"
        }
      ]
    }
' > "$public_draft"
assert_v02_publication_draft_record "$public_draft" "$release_notes_path"
/usr/bin/jq \
    '.draft = false | .published_at = "2026-07-28T20:00:00Z"' \
    "$public_draft" > "$temporary_directory/public-release.json"
assert_v02_public_release_record \
    "$temporary_directory/public-release.json" "$release_notes_path"
/usr/bin/jq '.prerelease = true' "$public_draft" > \
    "$temporary_directory/prerelease-draft.json"
expect_failure "identity or state is invalid" \
    assert_v02_publication_draft_record \
    "$temporary_directory/prerelease-draft.json" "$release_notes_path"
/usr/bin/jq '.assets += [{
    id: 12,
    name: "CopyLasso-0.2.1.dSYM.zip",
    size: 1,
    digest: "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    state: "uploaded"
  }]' "$public_draft" > "$temporary_directory/extra-public-asset.json"
expect_failure "exactly two uploaded assets" \
    assert_v02_publication_draft_record \
    "$temporary_directory/extra-public-asset.json" "$release_notes_path"

readonly candidate_tag="$temporary_directory/candidate-tag.json"
/usr/bin/jq -n \
    --arg ref "refs/tags/$COPYLASSO_V02_CANDIDATE_TAG" \
    --arg commit "$COPYLASSO_V02_CANDIDATE_COMMIT" \
    '{ref: $ref, object: {type: "commit", sha: $commit}}' > "$candidate_tag"
assert_v02_candidate_tag_record "$candidate_tag"
/usr/bin/jq '.object.type = "tag"' "$candidate_tag" > \
    "$temporary_directory/annotated-candidate-tag.json"
expect_failure "no longer identifies the approved source commit" \
    assert_v02_candidate_tag_record \
    "$temporary_directory/annotated-candidate-tag.json"

readonly previous_public_release="$temporary_directory/previous-public-release.json"
/usr/bin/jq -n \
    --arg tag "$COPYLASSO_V02_PREVIOUS_PUBLIC_TAG" '
    {
      id: 800,
      draft: false,
      prerelease: false,
      published_at: "2026-07-21T16:00:00Z",
      tag_name: $tag
    }
' > "$previous_public_release"
assert_v02_prepublication_latest_record "$previous_public_release"
/usr/bin/jq '.tag_name = "v0.1.1"' "$previous_public_release" > \
    "$temporary_directory/wrong-latest-release.json"
expect_failure "no longer the latest public release" \
    assert_v02_prepublication_latest_record \
    "$temporary_directory/wrong-latest-release.json"

readonly final_tag_ref="$temporary_directory/final-tag-ref.json"
/usr/bin/jq -n \
    --arg ref "refs/tags/$COPYLASSO_V02_FINAL_TAG" \
    '{ref: $ref, object: {type: "tag", sha: "0123456789abcdef0123456789abcdef01234567"}}' \
    > "$final_tag_ref"
assert_v02_final_tag_ref_record "$final_tag_ref"
readonly final_tag_object="$temporary_directory/final-tag-object.json"
/usr/bin/jq -n \
    --arg tag "$COPYLASSO_V02_FINAL_TAG" \
    --arg message "$COPYLASSO_V02_FINAL_TAG_MESSAGE" \
    --arg signature $'-----BEGIN SSH SIGNATURE-----\nfixture-signature\n-----END SSH SIGNATURE-----\n' \
    --arg commit "$COPYLASSO_V02_CANDIDATE_COMMIT" '
    {
      tag: $tag,
      message: ($message + "\n" + $signature),
      object: {type: "commit", sha: $commit},
      verification: {verified: true, reason: "valid", signature: $signature}
    }
' > "$final_tag_object"
assert_v02_final_tag_object_record "$final_tag_object"
/usr/bin/jq '.message = "Unexpected release title\n" + .verification.signature' \
    "$final_tag_object" > "$temporary_directory/wrong-final-tag-message.json"
expect_failure "not the reviewed GitHub-verified signed tag" \
    assert_v02_final_tag_object_record \
    "$temporary_directory/wrong-final-tag-message.json"
/usr/bin/jq '.message = (.message | sub("fixture-signature"; "different-signature"))' \
    "$final_tag_object" > "$temporary_directory/mismatched-final-tag-signature.json"
expect_failure "not the reviewed GitHub-verified signed tag" \
    assert_v02_final_tag_object_record \
    "$temporary_directory/mismatched-final-tag-signature.json"
/usr/bin/jq '.verification.verified = false | .verification.reason = "unsigned"' \
    "$final_tag_object" > "$temporary_directory/unsigned-final-tag.json"
expect_failure "not the reviewed GitHub-verified signed tag" \
    assert_v02_final_tag_object_record \
    "$temporary_directory/unsigned-final-tag.json"
assert_v02_latest_release_record \
    "$temporary_directory/public-release.json" \
    "$temporary_directory/public-release.json"
/usr/bin/jq '.id = 901' "$temporary_directory/public-release.json" > \
    "$temporary_directory/not-latest.json"
expect_failure "not GitHub's latest public release" \
    assert_v02_latest_release_record \
    "$temporary_directory/public-release.json" "$temporary_directory/not-latest.json"

readonly fixture_file="$temporary_directory/exact-file"
/usr/bin/printf 'publication fixture\n' > "$fixture_file"
readonly fixture_size="$(/usr/bin/stat -f '%z' "$fixture_file")"
readonly fixture_digest="$(
    /usr/bin/shasum -a 256 "$fixture_file" | /usr/bin/awk '{print $1}'
)"
assert_v02_exact_file "$fixture_file" "$fixture_size" "$fixture_digest" \
    "The publication fixture"
expect_failure "wrong size" \
    assert_v02_exact_file "$fixture_file" 1 "$fixture_digest" \
    "The publication fixture"

readonly unqualified_candidate="$temporary_directory/unqualified-candidate"
/bin/mkdir "$unqualified_candidate"
for asset_name in \
    "$COPYLASSO_RELEASE_DMG" \
    "$COPYLASSO_RELEASE_CHECKSUM" \
    "$COPYLASSO_RELEASE_DSYM" \
    "$COPYLASSO_RELEASE_VERIFICATION"; do
    /usr/bin/printf 'unqualified fixture\n' > "$unqualified_candidate/$asset_name"
done
missing_secret_output="$({
    env -u COPYLASSO_SPARKLE_PRIVATE_KEY "$appcast_generator" \
        --application "$temporary_directory/missing.app" \
        --candidate-dir "$unqualified_candidate" \
        --release-notes "$release_notes_path" \
        --output "$temporary_directory/rejected-appcast.xml" \
        --sparkle-tools-dir "$temporary_directory/missing-tools" 2>&1
} || true)"
[[ "$missing_secret_output" == \
    'The protected Sparkle signing secret is unavailable.' ]] || \
    fail "The final appcast generator must fail closed without its protected secret."
readonly test_private_key="$(
    /usr/bin/openssl rand -base64 32 | /usr/bin/tr -d '\n'
)"
unqualified_output="$({
    COPYLASSO_SPARKLE_PRIVATE_KEY="$test_private_key" "$appcast_generator" \
        --application "$temporary_directory/missing.app" \
        --candidate-dir "$unqualified_candidate" \
        --release-notes "$release_notes_path" \
        --output "$temporary_directory/rejected-appcast.xml" \
        --sparkle-tools-dir "$temporary_directory/missing-tools" 2>&1
} || true)"
[[ "$unqualified_output" == 'The approved v0.2 disk image has the wrong size.' ]] || \
    fail "The final appcast generator must reject unqualified candidate bytes."
[[ ! -e "$temporary_directory/rejected-appcast.xml" ]] || \
    fail "Rejected candidate bytes must not produce public update metadata."

readonly feed_fixture="$temporary_directory/feed"
readonly appcast_fixture="$temporary_directory/appcast.xml"
{
    /usr/bin/printf '%s' \
        '<?xml version="1.0" encoding="utf-8"?>' \
        '<rss xmlns:sparkle="https://sparkle-project.org/xml-namespaces/sparkle" version="2.0">' \
        '<channel><item>' \
        "<sparkle:version>$COPYLASSO_RELEASE_BUILD</sparkle:version>" \
        "<sparkle:shortVersionString>$COPYLASSO_RELEASE_VERSION</sparkle:shortVersionString>" \
        '<description sparkle:format="plain-text"><![CDATA['
    /bin/cat "$release_notes_path"
    /usr/bin/printf '%s' \
        ']]></description>' \
        "<enclosure url=\"$COPYLASSO_V02_DOWNLOAD_URL\" length=\"$COPYLASSO_V02_DMG_SIZE\" sparkle:edSignature=\"fixture-signature\" />" \
        '</item></channel></rss>'
} > "$appcast_fixture"
assert_v02_appcast_contract "$appcast_fixture" "$release_notes_path"
/usr/bin/sed "s|$COPYLASSO_V02_FINAL_TAG|$COPYLASSO_V02_CANDIDATE_TAG|" \
    "$appcast_fixture" > "$temporary_directory/rc-appcast.xml"
expect_failure "wrong enclosure URL" \
    assert_v02_appcast_contract \
    "$temporary_directory/rc-appcast.xml" "$release_notes_path"

"$feed_preparer" \
    --appcast "$appcast_fixture" \
    --release-notes "$release_notes_path" \
    --output-dir "$feed_fixture" >/dev/null
assert_v02_feed_bundle "$feed_fixture"
/usr/bin/printf 'unexpected\n' > "$feed_fixture/index.html"
expect_failure "only appcast.xml and _headers" \
    assert_v02_feed_bundle "$feed_fixture"
/bin/rm "$feed_fixture/index.html"
expect_failure "destination already exists" \
    "$feed_preparer" \
    --appcast "$appcast_fixture" \
    --release-notes "$release_notes_path" \
    --output-dir "$feed_fixture"

readonly sparkle_fixture_archive="$temporary_directory/sparkle-fixture.dmg"
readonly sparkle_fixture_signer_source="$temporary_directory/sign-sparkle-fixture.swift"
readonly sparkle_fixture_signer="$temporary_directory/sign-sparkle-fixture"
readonly sparkle_fixture_appcast="$temporary_directory/signed-appcast.xml"
readonly sparkle_fixture_public_key="$temporary_directory/sparkle-public-key.txt"
readonly sparkle_fixture_application="$temporary_directory/CopyLasso.app"
/usr/bin/printf 'fixture dmg\n' > "$sparkle_fixture_archive"
cat > "$sparkle_fixture_signer_source" <<'SWIFT'
import CryptoKit
import Foundation

guard CommandLine.arguments.count == 5 else {
  exit(64)
}

let templateURL = URL(fileURLWithPath: CommandLine.arguments[1])
let archiveURL = URL(fileURLWithPath: CommandLine.arguments[2])
let appcastURL = URL(fileURLWithPath: CommandLine.arguments[3])
let publicKeyURL = URL(fileURLWithPath: CommandLine.arguments[4])
let seed = Data((0..<32).map(UInt8.init))
let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
let archive = try Data(contentsOf: archiveURL)
let archiveSignature = try privateKey.signature(for: archive).base64EncodedString()
let template = try String(contentsOf: templateURL, encoding: .utf8)
let content = template.replacingOccurrences(
  of: "fixture-signature",
  with: archiveSignature
)
guard content != template, let contentData = content.data(using: .utf8) else {
  exit(1)
}
let feedSignature = try privateKey.signature(for: contentData).base64EncodedString()
let signingBlock = """
<!-- sparkle-signatures:
edSignature: \(feedSignature)
length: \(contentData.count)
-->

"""
var signedFeed = contentData
signedFeed.append(Data(signingBlock.utf8))
try signedFeed.write(to: appcastURL, options: .atomic)
try Data(privateKey.publicKey.rawRepresentation.base64EncodedString().utf8)
  .write(to: publicKeyURL, options: .atomic)
SWIFT
/usr/bin/xcrun swiftc \
    "$sparkle_fixture_signer_source" \
    -o "$sparkle_fixture_signer"
"$sparkle_fixture_signer" \
    "$appcast_fixture" \
    "$sparkle_fixture_archive" \
    "$sparkle_fixture_appcast" \
    "$sparkle_fixture_public_key"
/bin/mkdir -p "$sparkle_fixture_application/Contents"
/usr/bin/plutil -create xml1 \
    "$sparkle_fixture_application/Contents/Info.plist"
/usr/bin/plutil -insert SUPublicEDKey -string \
    "$(/bin/cat "$sparkle_fixture_public_key")" \
    "$sparkle_fixture_application/Contents/Info.plist"
/usr/bin/plutil -insert SURequireSignedFeed -bool true \
    "$sparkle_fixture_application/Contents/Info.plist"
assert_v02_sparkle_signatures \
    "$sparkle_fixture_appcast" \
    "$sparkle_fixture_archive" \
    "$sparkle_fixture_application"
/usr/bin/perl -0pe 's/CopyLasso/CopyLassp/' \
    "$sparkle_fixture_appcast" > "$temporary_directory/tampered-appcast.xml"
expect_failure "Sparkle signature verification failed" \
    assert_v02_sparkle_signatures \
    "$temporary_directory/tampered-appcast.xml" \
    "$sparkle_fixture_archive" \
    "$sparkle_fixture_application"
/bin/cp "$sparkle_fixture_archive" "$temporary_directory/tampered-archive.dmg"
/usr/bin/printf 'tampered\n' >> "$temporary_directory/tampered-archive.dmg"
expect_failure "Sparkle signature verification failed" \
    assert_v02_sparkle_signatures \
    "$sparkle_fixture_appcast" \
    "$temporary_directory/tampered-archive.dmg" \
    "$sparkle_fixture_application"

readonly transaction_candidate="$temporary_directory/transaction-candidate"
/bin/mkdir "$transaction_candidate"
/usr/bin/printf 'fixture dmg\n' > \
    "$transaction_candidate/$COPYLASSO_RELEASE_DMG"
/usr/bin/printf 'fixture checksum\n' > \
    "$transaction_candidate/$COPYLASSO_RELEASE_CHECKSUM"
readonly empty_creation="$temporary_directory/empty-creation.json"
/usr/bin/jq '.assets = []' "$public_draft" > "$empty_creation"
readonly partial_draft="$temporary_directory/partial-draft.json"
/usr/bin/jq '.assets = [.assets[0]]' "$public_draft" > "$partial_draft"

assert_fixture_draft_record() {
    local record="$1"
    local ignored_notes="$2"

    [[ "$ignored_notes" == "$release_notes_path" ]] || return 1
    /usr/bin/jq -e '
        .id == 900
        and .draft == true
        and .prerelease == false
        and .tag_name == "v0.2.1"
        and (.assets | map(.name) | sort) == [
          "CopyLasso-0.2.1.dmg",
          "CopyLasso-0.2.1.dmg.sha256"
        ]
    ' "$record" >/dev/null 2>&1
}

readonly fake_gh="$temporary_directory/gh"
readonly fake_gh_log="$temporary_directory/gh.log"
readonly fake_listing_count="$temporary_directory/listing-count"
/usr/bin/printf '0\n' > "$fake_listing_count"
cat > "$fake_gh" <<'SCRIPT'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$FAKE_GH_LOG"
if [[ "$1" == "api" && "$*" == *"releases/tags/"* ]]; then
    case "${FAKE_GH_MODE:-success}" in
        preexisting-release)
            /usr/bin/printf 'HTTP/2.0 200 OK\n\n'
            /bin/cat "$FAKE_GH_FINAL_RECORD"
            exit 0
            ;;
        release-lookup-error)
            /usr/bin/printf 'HTTP/2.0 503 Service Unavailable\n\n{}\n'
            exit 1
            ;;
        *)
            /usr/bin/printf 'HTTP/2.0 404 Not Found\n\n{}\n'
            exit 1
            ;;
    esac
fi
if [[ "$1" == "api" && "$*" == *"releases/latest"* ]]; then
    if [[ "${FAKE_GH_MODE:-success}" == "wrong-latest" ]]; then
        /bin/cat "$FAKE_GH_WRONG_LATEST_RECORD"
    else
        /bin/cat "$FAKE_GH_LATEST_RECORD"
    fi
    exit 0
fi
if [[ "$1" == "api" && "$*" == *"/releases?per_page=100"* ]]; then
    count="$(/bin/cat "$FAKE_GH_LISTING_COUNT")"
    count="$((count + 1))"
    /usr/bin/printf '%s\n' "$count" > "$FAKE_GH_LISTING_COUNT"
    if [[ "${FAKE_GH_MODE:-success}" == "invalid-listing" ]]; then
        /usr/bin/printf '{}\n'
    elif [[ "${FAKE_GH_MODE:-success}" == "preexisting-invalid-draft" ]]; then
        /usr/bin/jq -n --slurpfile record "$FAKE_GH_PARTIAL_RECORD" '[ $record ]'
    elif [[ "${FAKE_GH_MODE:-success}" == "preexisting-listing" ||
        "${FAKE_GH_MODE:-success}" == "preexisting-exact-draft" ]]; then
        /usr/bin/jq -n --slurpfile record "$FAKE_GH_FINAL_RECORD" '[ $record ]'
    elif [[ "${FAKE_GH_MODE:-success}" == ambiguous-create* && "$count" -gt 1 ]]; then
        /usr/bin/jq -n --slurpfile record "$FAKE_GH_CREATION_RECORD" '[ $record ]'
    else
        /usr/bin/printf '[[]]\n'
    fi
    exit 0
fi
if [[ "$1" == "api" && "$*" == *"git/ref/tags/"* ]]; then
    case "${FAKE_GH_MODE:-success}" in
        preexisting-tag)
            /usr/bin/printf 'HTTP/2.0 200 OK\n\n{}\n'
            exit 0
            ;;
        tag-lookup-error)
            /usr/bin/printf 'HTTP/2.0 401 Unauthorized\n\n{}\n'
            exit 1
            ;;
        *)
            /usr/bin/printf 'HTTP/2.0 404 Not Found\n\n{}\n'
            exit 1
            ;;
    esac
fi
if [[ "$1" == "api" && "$*" == *"--method POST"* && "$*" == *"/releases"* ]]; then
    [[ "${FAKE_GH_MODE:-success}" != ambiguous-create* ]] || exit 1
    /bin/cat "$FAKE_GH_CREATION_RECORD"
    exit 0
fi
if [[ "$1" == "release" && "$2" == "upload" ]]; then
    case "${FAKE_GH_MODE:-success}" in
        upload-fail | ambiguous-upload | ambiguous-create-upload-fail) exit 1 ;;
        *) exit 0 ;;
    esac
fi
if [[ "$1" == "api" && "$*" == *"releases/900"* ]]; then
    if [[ "${FAKE_GH_MODE:-success}" == "upload-fail" ||
        "${FAKE_GH_MODE:-success}" == "ambiguous-create-upload-fail" ]]; then
        /bin/cat "$FAKE_GH_PARTIAL_RECORD"
    else
        /bin/cat "$FAKE_GH_FINAL_RECORD"
    fi
    exit 0
fi
if [[ "$1" == "api" && "$*" == *"--method DELETE"* ]]; then
    exit 0
fi
exit 1
SCRIPT
/bin/chmod +x "$fake_gh"

export FAKE_GH_LOG="$fake_gh_log"
export FAKE_GH_LISTING_COUNT="$fake_listing_count"
export FAKE_GH_CREATION_RECORD="$empty_creation"
export FAKE_GH_FINAL_RECORD="$public_draft"
export FAKE_GH_PARTIAL_RECORD="$partial_draft"
export FAKE_GH_LATEST_RECORD="$previous_public_release"
export FAKE_GH_WRONG_LATEST_RECORD="$temporary_directory/wrong-latest-release.json"

run_transaction() {
    local mode="$1"
    local destination="$2"

    export FAKE_GH_MODE="$mode"
    /usr/bin/printf '0\n' > "$fake_listing_count"
    : > "$fake_gh_log"
    create_v02_publication_draft_transaction \
        "$COPYLASSO_V02_REPOSITORY" \
        "$transaction_candidate" \
        "$release_notes_path" \
        "$destination" \
        "$fake_gh" \
        assert_fixture_draft_record
}

run_transaction success "$temporary_directory/transaction-success.json"
[[ -f "$temporary_directory/transaction-success.json" ]] || \
    fail "The exact publication-draft transaction did not produce readback."
if /usr/bin/grep -Fq -- '--method DELETE' "$fake_gh_log"; then
    fail "A successful publication-draft transaction must not roll back."
fi
if /usr/bin/grep -Eq -- '--clobber|--method PATCH|make_latest=true|git/refs' \
    "$fake_gh_log"; then
    fail "A successful publication-draft transaction attempted a prohibited mutation."
fi

(
    readonly release_notes="$release_notes_path"
    readonly gh_binary="$fake_gh"
    run_transaction success \
        "$temporary_directory/transaction-readonly-caller.json"
)
[[ -f "$temporary_directory/transaction-readonly-caller.json" ]] || \
    fail "A readonly caller release-notes binding broke the draft transaction."

run_transaction ambiguous-create \
    "$temporary_directory/transaction-ambiguous-create.json"
if /usr/bin/grep -Fq -- '--method DELETE' "$fake_gh_log"; then
    fail "An exactly read-back ambiguous draft creation must not roll back."
fi
run_transaction ambiguous-upload \
    "$temporary_directory/transaction-ambiguous-upload.json"
if /usr/bin/grep -Fq -- '--method DELETE' "$fake_gh_log"; then
    fail "An exactly read-back ambiguous upload must not roll back."
fi

run_transaction preexisting-exact-draft \
    "$temporary_directory/transaction-preexisting-exact-draft.json"
[[ -f "$temporary_directory/transaction-preexisting-exact-draft.json" ]] || \
    fail "An exact pre-existing publication draft must be adopted on retry."
if /usr/bin/grep -Eq -- '--method POST|release upload|--method DELETE' "$fake_gh_log"; then
    fail "Adopting an exact pre-existing draft must perform no mutation."
fi

expect_failure "asset upload failed" \
    run_transaction ambiguous-create-upload-fail \
    "$temporary_directory/transaction-ambiguous-create-upload-fail.json"
if /usr/bin/grep -Fq -- '--method DELETE' "$fake_gh_log"; then
    fail "An ambiguously created draft must never be treated as transaction-owned."
fi

expect_failure "asset upload failed" \
    run_transaction upload-fail \
    "$temporary_directory/transaction-upload-fail.json"
/usr/bin/grep -Fq -- '--method DELETE repos/bennetthilberg/copylasso/releases/900' \
    "$fake_gh_log" || \
    fail "An incomplete newly created publication draft must be deleted."

expect_failure "not the exact resumable private draft" \
    run_transaction preexisting-invalid-draft \
    "$temporary_directory/transaction-preexisting-invalid-draft.json"
if /usr/bin/grep -Fq -- '--method POST' "$fake_gh_log"; then
    fail "An invalid pre-existing final release must prevent every mutation."
fi
for collision_mode in preexisting-tag; do
    expect_failure "already exists" \
        run_transaction "$collision_mode" \
        "$temporary_directory/transaction-$collision_mode.json"
    if /usr/bin/grep -Fq -- '--method POST' "$fake_gh_log"; then
        fail "A pre-existing final release or tag must prevent every mutation."
    fi
done
for lookup_error_mode in tag-lookup-error; do
    expect_failure "could not be checked" \
        run_transaction "$lookup_error_mode" \
        "$temporary_directory/transaction-$lookup_error_mode.json"
    if /usr/bin/grep -Fq -- '--method POST' "$fake_gh_log"; then
        fail "A failed final release or tag lookup must prevent every mutation."
    fi
done
expect_failure "existing-release listing is invalid" \
    run_transaction invalid-listing \
    "$temporary_directory/transaction-invalid-listing.json"
if /usr/bin/grep -Fq -- '--method POST' "$fake_gh_log"; then
    fail "An invalid release listing must prevent every mutation."
fi
expect_failure "no longer the latest public release" \
    run_transaction wrong-latest \
    "$temporary_directory/transaction-wrong-latest.json"
if /usr/bin/grep -Fq -- '--method POST' "$fake_gh_log"; then
    fail "A changed latest public release must prevent every mutation."
fi

unset FAKE_GH_MODE FAKE_GH_LOG FAKE_GH_LISTING_COUNT \
    FAKE_GH_CREATION_RECORD FAKE_GH_FINAL_RECORD FAKE_GH_PARTIAL_RECORD \
    FAKE_GH_LATEST_RECORD FAKE_GH_WRONG_LATEST_RECORD

echo "CopyLasso v0.2 publication tests passed."
