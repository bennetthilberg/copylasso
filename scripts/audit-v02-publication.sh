#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
# shellcheck source=scripts/lib/v02-publication-verification.sh
source "$repository_root/scripts/lib/v02-publication-verification.sh"

usage() {
    cat >&2 <<'TEXT'
Usage: audit-v02-publication.sh
       audit-v02-publication.sh \
         --handoff /path/to/private-handoff \
         --candidate-dir /path/to/downloaded/G48/assets \
         --application /path/to/qualified/CopyLasso.app
TEXT
    exit 64
}

handoff=""
candidate_directory=""
application=""
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --handoff)
            [[ "$#" -ge 2 ]] || usage
            handoff="$2"
            shift 2
            ;;
        --candidate-dir)
            [[ "$#" -ge 2 ]] || usage
            candidate_directory="$2"
            shift 2
            ;;
        --application)
            [[ "$#" -ge 2 ]] || usage
            application="$2"
            shift 2
            ;;
        *) usage ;;
    esac
done
if [[ -n "$handoff" || -n "$candidate_directory" || -n "$application" ]]; then
    [[ -n "$handoff" && -n "$candidate_directory" && -n "$application" ]] || usage
fi

readonly workflow="$repository_root/.github/workflows/prepare-publication.yml"
readonly candidate_workflow="$repository_root/.github/workflows/release.yml"
readonly candidate_downloader="$repository_root/scripts/download-v02-candidate.sh"
readonly package_verifier="$repository_root/scripts/verify-v02-candidate-package.sh"
readonly appcast_generator="$repository_root/scripts/generate-release-appcast.sh"
readonly draft_creator="$repository_root/scripts/create-v02-publication-draft.sh"
readonly feed_preparer="$repository_root/scripts/prepare-update-feed.sh"
readonly verifier_library="$repository_root/scripts/lib/v02-publication-verification.sh"
readonly transaction_library="$repository_root/scripts/lib/v02-publication-transaction.sh"
readonly v021_package_metadata="$repository_root/scripts/lib/v021-release-package-metadata.sh"
readonly signature_verifier_source="$repository_root/scripts/lib/verify-sparkle-signatures.swift"
readonly focused_tests="$repository_root/scripts/test-v02-publication.sh"
readonly runbook="$repository_root/docs/v0.2-publication-runbook.md"
readonly release_workflow_documentation="$repository_root/docs/release-workflow.md"
readonly update_operations="$repository_root/docs/secure-update-operations.md"
readonly release_checklist="$repository_root/docs/release-checklist.md"
readonly notes="$repository_root/scripts/fixtures/v0.2.1-published-release-notes.md"

fail() {
    echo "$1" >&2
    exit 1
}

require_text() {
    local file="$1"
    local text="$2"

    /usr/bin/grep -Fq -- "$text" "$file" || \
        fail "G49 publication contract text is missing: $text"
}

for executable in \
    "$candidate_downloader" \
    "$package_verifier" \
    "$appcast_generator" \
    "$draft_creator" \
    "$feed_preparer" \
    "$focused_tests"; do
    [[ -x "$executable" ]] || \
        fail "G49 publication script is missing or not executable: $(/usr/bin/basename "$executable")"
done
for readable in \
    "$workflow" \
    "$candidate_workflow" \
    "$verifier_library" \
    "$transaction_library" \
    "$v021_package_metadata" \
    "$signature_verifier_source" \
    "$runbook" \
    "$release_workflow_documentation" \
    "$update_operations" \
    "$release_checklist" \
    "$notes"; do
    [[ -r "$readable" ]] || \
        fail "G49 publication contract file is missing: $(/usr/bin/basename "$readable")"
done

assert_v02_release_notes "$notes"
require_text "$verifier_library" \
    'COPYLASSO_V02_CANDIDATE_COMMIT="813de17c739097217aad55a5a35c04ea3c73d99f"'
require_text "$verifier_library" 'COPYLASSO_V02_CANDIDATE_RELEASE_ID="367523470"'
require_text "$verifier_library" 'COPYLASSO_V02_CANDIDATE_TAG="v0.2.1-rc.1"'
require_text "$verifier_library" 'COPYLASSO_V02_FINAL_TAG="v0.2.1"'
require_text "$verifier_library" \
    'COPYLASSO_V02_DMG_SHA256="05180caa3600bcd282246297a9172517136e43e55c6e8fa192b55ba44af4a017"'
require_text "$verifier_library" \
    'COPYLASSO_V02_CHECKSUM_SHA256="b9a85f82686dce479cb41247fe9fc025ec8a0d099bbc08028c4239899359b1c9"'
require_text "$verifier_library" \
    'COPYLASSO_V02_DSYM_SHA256="0301eecaccb9fac76c1e25d2ae1db2edc99ff42febe55bfcf6f07ef4ffcbd368"'
require_text "$verifier_library" \
    'COPYLASSO_V02_VERIFICATION_SHA256="689aad0296e90b9aab83e198eaef0524da907d1742fbeab8078bddc823a1b108"'

require_text "$workflow" 'repository_dispatch:'
require_text "$workflow" 'types: [copylasso_prepare_publication]'
require_text "$workflow" \
    "github.event_name == 'repository_dispatch' && github.event.action == 'copylasso_prepare_publication' && github.ref == 'refs/heads/main'"
if /usr/bin/grep -Fq '${{ github.event.client_payload.' "$workflow"; then
    fail "The G49 preparation workflow must not accept arbitrary dispatch inputs."
fi
for prohibited_trigger in \
    pull_request: \
    pull_request_target: \
    push: \
    workflow_dispatch: \
    workflow_run:; do
    if /usr/bin/grep -Eq "^[[:space:]]*${prohibited_trigger}[[:space:]]*$" "$workflow"; then
        fail "The G49 preparation workflow has a prohibited trigger: $prohibited_trigger"
    fi
done
require_text "$workflow" 'uses: ./.github/workflows/ci.yml'
require_text "$workflow" 'needs: quality-gate'
require_text "$workflow" 'environment:'
require_text "$workflow" 'name: release'
require_text "$workflow" 'cancel-in-progress: false'
require_text "$workflow" 'actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0'
require_text "$workflow" 'actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a'
require_text "$workflow" 'persist-credentials: false'
require_text "$workflow" 'fetch-depth: 0'
require_text "$workflow" './scripts/download-v02-candidate.sh'
require_text "$workflow" 'COPYLASSO_G49_CANDIDATE_TAG_READBACK'
require_text "$workflow" '--tag-readback "$COPYLASSO_G49_CANDIDATE_TAG_READBACK"'
require_text "$workflow" './scripts/verify-v02-candidate-package.sh'
require_text "$workflow" './scripts/generate-release-appcast.sh'
require_text "$workflow" './scripts/prepare-update-feed.sh'
require_text "$workflow" './scripts/create-v02-publication-draft.sh'
require_text "$workflow" './scripts/audit-v02-publication.sh'
require_text "$workflow" 'COPYLASSO_G49_HANDOFF'
require_text "$workflow" 'retention-days: 30'

contents_write_count="$(
    /usr/bin/grep -Ec '^[[:space:]]*contents: write[[:space:]]*$' "$workflow"
)"
[[ "$contents_write_count" == "1" ]] || \
    fail "Only the protected G49 preparation job may receive contents write permission."
sparkle_secret_count="$(
    /usr/bin/grep -Fc \
        'COPYLASSO_SPARKLE_PRIVATE_KEY: ${{ secrets.COPYLASSO_SPARKLE_PRIVATE_KEY }}' \
        "$workflow"
)"
[[ "$sparkle_secret_count" == "1" ]] || \
    fail "The Sparkle signing seed must enter exactly one narrow G49 step."
team_secret_count="$(
    /usr/bin/grep -Fc \
        'COPYLASSO_EXPECTED_TEAM_ID: ${{ secrets.COPYLASSO_EXPECTED_TEAM_ID }}' \
        "$workflow"
)"
[[ "$team_secret_count" == "1" ]] || \
    fail "The release team must enter exactly one package-verification step."
for prohibited_secret in \
    COPYLASSO_DEVELOPER_ID_P12_BASE64 \
    COPYLASSO_DEVELOPER_ID_P12_PASSWORD \
    COPYLASSO_NOTARY_KEY_BASE64 \
    COPYLASSO_NOTARY_KEY_ID \
    COPYLASSO_NOTARY_ISSUER_ID; do
    if /usr/bin/grep -Fq "secrets.$prohibited_secret" "$workflow"; then
        fail "G49 must not receive build, certificate, or notarization credentials."
    fi
done

while IFS= read -r action_target; do
    case "$action_target" in
        ./*) ;;
        *@????????????????????????????????????????) ;;
        *) fail "The privileged G49 workflow contains a mutable action reference: $action_target" ;;
    esac
done < <(/usr/bin/sed -nE \
    's/^[[:space:]]*uses:[[:space:]]*([^[:space:]]+).*$/\1/p' "$workflow")

if /usr/bin/grep -Eq \
    'build-release-candidate|xcodebuild[[:space:]]+(archive|-exportArchive)|notarytool[[:space:]]+submit|stapler[[:space:]]+staple' \
    "$workflow"; then
    fail "G49 must consume the approved candidate without rebuilding or renotarizing it."
fi
if /usr/bin/grep -Eiq \
    'release (publish|edit.+--draft=false)|make_latest=true|--method PATCH|--clobber|force=true|git push|git tag' \
    "$workflow" "$draft_creator" "$transaction_library"; then
    fail "Phase 1 must not publish, tag, overwrite, force-update, or promote a release."
fi
if /usr/bin/grep -Eiq \
    'cloudflare|wrangler|pages deploy|updates\.copylasso\.com.*(PUT|POST)' \
    "$workflow"; then
    fail "Phase 1 must not deploy the public updater feed."
fi
if /usr/bin/grep -Eq \
    '(^|[[:space:]])(publish|make_latest|draft:[[:space:]]*false)([[:space:]]|$)' \
    "$candidate_workflow"; then
    fail "The G48 candidate workflow must remain draft-only."
fi

for required_downloader_text in \
    'COPYLASSO_V02_CANDIDATE_RELEASE_ID' \
    'assert_v02_candidate_release_record' \
    '--tag-readback' \
    'assert_v02_candidate_tag_record' \
    'Accept: application/octet-stream' \
    'assert_v02_candidate_files'; do
    require_text "$candidate_downloader" "$required_downloader_text"
done
require_text "$candidate_downloader" \
    'scripts/fixtures/v0.2.1-published-release-notes.md'
require_text "$package_verifier" \
    'COPYLASSO_RELEASE_PACKAGE_METADATA_PROFILE=v0.2.1'
require_text "$v021_package_metadata" 'readonly COPYLASSO_RELEASE_VERSION="0.2.1"'
require_text "$v021_package_metadata" 'readonly COPYLASSO_RELEASE_BUILD="4"'
for required_generator_text in \
    'unset COPYLASSO_SPARKLE_PRIVATE_KEY' \
    'assert_v02_candidate_files' \
    'assert_v02_release_notes' \
    'COPYLASSO_V02_FINAL_TAG' \
    'sign_update" --verify' \
    'assert_v02_appcast_contract'; do
    require_text "$appcast_generator" "$required_generator_text"
done
for required_draft_text in \
    '--include' \
    'draft=true' \
    'prerelease=false' \
    'make_latest=false' \
    'release upload' \
    'assert_v02_publication_draft_record' \
    '--paginate' \
    '--slurp' \
    '--method DELETE'; do
    require_text "$transaction_library" "$required_draft_text"
done
require_text "$transaction_library" 'assert_v02_prepublication_latest_record'
require_text "$verifier_library" 'assert_v02_sparkle_signatures'
require_text "$verifier_library" 'verify-sparkle-signatures.swift'
require_text "$signature_verifier_source" 'Curve25519.Signing.PublicKey'
require_text "$signature_verifier_source" 'isValidSignature(feedSignature'
require_text "$signature_verifier_source" 'isValidSignature(enclosureSignature'
require_text "$workflow" '--candidate-dir "$COPYLASSO_G49_CANDIDATE"'
require_text "$workflow" '--application'
if /usr/bin/grep -Eq \
    'git/refs|--method PATCH|--clobber|make_latest=true|draft=false' \
    "$draft_creator" "$transaction_library"; then
    fail "The G49 draft helper must not create tags, publish, or replace public state."
fi

for required_runbook_text in \
    '## G49 v0.2.1 Patch Publication' \
    '### Phase 1 - Protected Preparation' \
    '### Phase 2 - Signed Tag And Publication' \
    'v0.2.1-rc.1' \
    '813de17c739097217aad55a5a35c04ea3c73d99f' \
    'updates.copylasso.com' \
    'Cloudflare Pages' \
    'Spaceship' \
    'Never move either tag' \
    'Never replace a public asset' \
    'Release-State Closure'; do
    require_text "$runbook" "$required_runbook_text"
done
require_text "$release_workflow_documentation" '## G49 Publication Preparation'
require_text "$update_operations" 'updates.copylasso.com'
require_text "$release_checklist" '## G49 - Publish CopyLasso v0.2.1'
require_text "$release_checklist" \
    '- [x] Phase 1: merge the green G49 publication-control PR before dispatching the protected preparation workflow.'

credential_marker='set -x|BEGIN '
credential_marker+='([A-Z ]+ )?PRIVATE KEY|[a-z]{4}-[a-z]{4}-[a-z]{4}-[a-z]{4}'
if /usr/bin/grep -Eq \
    "$credential_marker" \
    "$workflow" \
    "$candidate_downloader" \
    "$package_verifier" \
    "$appcast_generator" \
    "$draft_creator" \
    "$feed_preparer" \
    "$verifier_library" \
    "$transaction_library" \
    "$runbook"; then
    fail "G49 publication controls contain unsafe tracing or credential-like material."
fi

if [[ -n "$handoff" ]]; then
    [[ -d "$handoff" && ! -L "$handoff" ]] || \
        fail "The private G49 publication handoff is unavailable."
    expected_handoff_entries="$(printf '%s\n' \
        candidate-release.json \
        candidate-tag.json \
        feed \
        final-draft.json \
        publication-manifest.json | LC_ALL=C /usr/bin/sort)"
    actual_handoff_entries="$({
        /usr/bin/find "$handoff" -mindepth 1 -maxdepth 1 -print |
            while IFS= read -r entry; do /usr/bin/basename "$entry"; done |
            LC_ALL=C /usr/bin/sort
    })"
    [[ "$actual_handoff_entries" == "$expected_handoff_entries" ]] || \
        fail "The private G49 handoff contains an unexpected top-level entry."
    assert_v02_candidate_release_record \
        "$handoff/candidate-release.json" "$notes"
    assert_v02_candidate_tag_record "$handoff/candidate-tag.json"
    assert_v02_publication_draft_record \
        "$handoff/final-draft.json" "$notes"
    assert_v02_candidate_files "$candidate_directory"
    assert_v02_feed_bundle "$handoff/feed"
    assert_v02_appcast_contract \
        "$handoff/feed/$COPYLASSO_V02_PUBLIC_APPCAST_NAME" "$notes"
    assert_v02_sparkle_signatures \
        "$handoff/feed/$COPYLASSO_V02_PUBLIC_APPCAST_NAME" \
        "$candidate_directory/$COPYLASSO_RELEASE_DMG" \
        "$application"
    /usr/bin/jq -e \
        --arg candidate_commit "$COPYLASSO_V02_CANDIDATE_COMMIT" \
        --arg candidate_tag "$COPYLASSO_V02_CANDIDATE_TAG" \
        --arg final_tag "$COPYLASSO_V02_FINAL_TAG" \
        --arg dmg_sha256 "$COPYLASSO_V02_DMG_SHA256" \
        --arg appcast_sha256 "$(
            /usr/bin/shasum -a 256 \
                "$handoff/feed/$COPYLASSO_V02_PUBLIC_APPCAST_NAME" |
                /usr/bin/awk '{print $1}'
        )" \
        --argjson draft_id "$(
            /usr/bin/jq -er '.id' "$handoff/final-draft.json"
        )" '
        (.control_commit | test("^[0-9a-f]{40}$"))
        and .candidate_commit == $candidate_commit
        and .candidate_tag == $candidate_tag
        and .final_tag == $final_tag
        and .final_draft_id == $draft_id
        and .dmg_sha256 == $dmg_sha256
        and .appcast_sha256 == $appcast_sha256
        and (keys | sort) == [
            "appcast_sha256",
            "candidate_commit",
            "candidate_tag",
            "control_commit",
            "dmg_sha256",
            "final_draft_id",
            "final_tag"
        ]
    ' "$handoff/publication-manifest.json" >/dev/null || \
        fail "The private G49 publication manifest differs from the reviewed contract."
fi

echo "CopyLasso v0.2 publication audit passed."
