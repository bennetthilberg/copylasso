#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly workflow="$repository_root/.github/workflows/prepare-v030-publication.yml"
readonly verifier="$repository_root/scripts/lib/v02-publication-verification.sh"
readonly package_metadata="$repository_root/scripts/lib/v030-release-package-metadata.sh"
readonly notes="$repository_root/docs/release-notes/0.3.0.md"
readonly focused_tests="$repository_root/scripts/test-g56-publication.sh"
readonly runbook="$repository_root/docs/v0.3-publication-runbook.md"
readonly release_workflow="$repository_root/docs/release-workflow.md"
readonly operations="$repository_root/docs/secure-update-operations.md"
readonly checklist="$repository_root/docs/release-checklist.md"

export COPYLASSO_V02_PUBLICATION_PROFILE=v0.3.0
# shellcheck source=scripts/lib/v02-publication-verification.sh
source "$verifier"

usage() {
    cat >&2 <<'TEXT'
Usage: audit-g56-publication.sh
       audit-g56-publication.sh \
         --handoff /path/to/private-handoff \
         --candidate-dir /path/to/downloaded/candidate/assets \
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

fail() {
    echo "$1" >&2
    exit 1
}

require_text() {
    local file="$1"
    local required="$2"

    /usr/bin/grep -Fq -- "$required" "$file" || \
        fail "G56 publication control is missing: $required"
}

for required_file in \
    "$workflow" \
    "$verifier" \
    "$package_metadata" \
    "$notes" \
    "$focused_tests" \
    "$runbook" \
    "$release_workflow" \
    "$operations" \
    "$checklist"; do
    [[ -s "$required_file" ]] || \
        fail "Required G56 publication file is unavailable: $required_file"
done
[[ -x "$focused_tests" ]] || fail "The G56 publication test is not executable."

for pinned_value in \
    'v0.3.0)' \
    'COPYLASSO_V02_CANDIDATE_COMMIT="c99bec65be187c02b920b6519152ba935ec44253"' \
    'COPYLASSO_V02_CANDIDATE_RELEASE_ID="370037259"' \
    'COPYLASSO_V02_CANDIDATE_TAG="v0.3.0-rc.1"' \
    'COPYLASSO_V02_FINAL_TAG="v0.3.0"' \
    'COPYLASSO_V02_PREVIOUS_PUBLIC_TAG="v0.2.2"' \
    'COPYLASSO_V02_DMG_SHA256="96f07eff7719f6c5b4b819af846d9ac825e13d4959d6f45d14d19fffa943bb96"' \
    'COPYLASSO_V02_CHECKSUM_SHA256="81a83046e2dffce11f1af88f811ba87eff13ddd8cd93fde1eaddbbb5820fecd3"' \
    'COPYLASSO_V02_DSYM_SHA256="16498e46bef1bef9f47e3fbc39c4e70ef06fb49613713da60a172901ed9e8e0e"' \
    'COPYLASSO_V02_VERIFICATION_SHA256="a95bb561b7ff79af8badcb689b877b166ef05c420b85fcd2c091750fde60b8f9"' \
    'COPYLASSO_V02_CANDIDATE_APPCAST_SHA256="949b82f0c8168386f86ca149b302f3ab32df33ee856e4805de168e4f4faf5060"' \
    'COPYLASSO_V02_NOTES_SHA256="a8aa4e68c60cb001cadbdbeaf99966a331280eaff1acfc0becc28922f1dd28d0"'; do
    require_text "$verifier" "$pinned_value"
done

for workflow_text in \
    'types: [copylasso_prepare_v030_publication]' \
    "github.event.action == 'copylasso_prepare_v030_publication'" \
    'COPYLASSO_V02_PUBLICATION_PROFILE: v0.3.0' \
    'uses: ./.github/workflows/ci.yml' \
    'name: release' \
    'cancel-in-progress: false' \
    'persist-credentials: false' \
    './scripts/download-v02-candidate.sh' \
    './scripts/verify-v02-candidate-package.sh' \
    './scripts/generate-release-appcast.sh' \
    './scripts/prepare-update-feed.sh' \
    './scripts/create-v02-publication-draft.sh' \
    './scripts/audit-g56-publication.sh' \
    'copylasso-v0.3.0-publication'; do
    require_text "$workflow" "$workflow_text"
done

[[ "$(/usr/bin/grep -Ec '^[[:space:]]*contents: write[[:space:]]*$' "$workflow")" == "1" ]] || \
    fail "Only the protected G56 preparation job may receive contents write permission."
[[ "$(/usr/bin/grep -Fc 'COPYLASSO_SPARKLE_PRIVATE_KEY: ${{ secrets.COPYLASSO_SPARKLE_PRIVATE_KEY }}' "$workflow")" == "1" ]] || \
    fail "The Sparkle seed must enter exactly one narrow G56 step."
[[ "$(/usr/bin/grep -Fc 'COPYLASSO_EXPECTED_TEAM_ID: ${{ secrets.COPYLASSO_EXPECTED_TEAM_ID }}' "$workflow")" == "1" ]] || \
    fail "The release team must enter exactly one G56 verification step."
for prohibited_secret in \
    COPYLASSO_DEVELOPER_ID_P12_BASE64 \
    COPYLASSO_DEVELOPER_ID_P12_PASSWORD \
    COPYLASSO_NOTARY_KEY_BASE64 \
    COPYLASSO_NOTARY_KEY_ID \
    COPYLASSO_NOTARY_ISSUER_ID; do
    if /usr/bin/grep -Fq "secrets.$prohibited_secret" "$workflow"; then
        fail "G56 publication preparation must not receive build credentials."
    fi
done

while IFS= read -r action_target; do
    case "$action_target" in
        ./*) ;;
        *@????????????????????????????????????????) ;;
        *) fail "The G56 workflow contains a mutable action reference: $action_target" ;;
    esac
done < <(/usr/bin/sed -nE \
    's/^[[:space:]]*uses:[[:space:]]*([^[:space:]]+).*$/\1/p' "$workflow")

if /usr/bin/grep -Fq '${{ github.event.client_payload.' "$workflow"; then
    fail "G56 publication preparation must accept no dispatch payload."
fi
if /usr/bin/grep -Eq \
    'build-release-candidate|xcodebuild[[:space:]]+(archive|-exportArchive)|notarytool[[:space:]]+submit|stapler[[:space:]]+staple' \
    "$workflow"; then
    fail "G56 publication preparation must consume the candidate without rebuilding."
fi
if /usr/bin/grep -Eiq \
    'release (publish|edit.+--draft=false)|make_latest=true|--clobber|force=true|git push|git tag|wrangler|pages deploy' \
    "$workflow"; then
    fail "Phase 1 must not publish, tag, replace, or deploy."
fi

for documentation_guard in \
    '## G56 v0.3.0 Publication' \
    'without rebuilding' \
    'signed annotated `v0.3.0` tag' \
    'accepted macOS 14 and direct high-water readback gaps' \
    'G57'; do
    require_text "$runbook" "$documentation_guard"
done
require_text "$release_workflow" '## G56 Publication Preparation'
require_text "$operations" '## G56 v0.3.0 Publication Boundary'
require_text "$checklist" '## G56 - Publish CopyLasso v0.3.0'

credential_marker='set -x|BEGIN '
credential_marker+='([A-Z ]+ )?PRIVATE KEY|[a-z]{4}-[a-z]{4}-[a-z]{4}-[a-z]{4}'
if /usr/bin/grep -Eq "$credential_marker" \
    "$workflow" "$verifier" "$runbook" "$operations"; then
    fail "G56 publication controls contain unsafe tracing or credential-like material."
fi

assert_v02_release_notes "$notes"
if [[ -n "$handoff" ]]; then
    [[ -d "$handoff" && ! -L "$handoff" ]] || \
        fail "The private G56 publication handoff is unavailable."
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
        fail "The private G56 handoff contains an unexpected top-level entry."

    assert_v02_candidate_release_record "$handoff/candidate-release.json" "$notes"
    assert_v02_candidate_tag_record "$handoff/candidate-tag.json"
    assert_v02_publication_draft_record "$handoff/final-draft.json" "$notes"
    assert_v02_candidate_files "$candidate_directory"
    assert_v02_feed_bundle "$handoff/feed"
    assert_v02_appcast_contract "$handoff/feed/appcast.xml" "$notes"
    assert_v02_sparkle_signatures \
        "$handoff/feed/appcast.xml" \
        "$candidate_directory/$COPYLASSO_RELEASE_DMG" \
        "$application"

    /usr/bin/jq -e \
        --arg candidate_commit "$COPYLASSO_V02_CANDIDATE_COMMIT" \
        --arg candidate_tag "$COPYLASSO_V02_CANDIDATE_TAG" \
        --arg final_tag "$COPYLASSO_V02_FINAL_TAG" \
        --arg dmg_sha256 "$COPYLASSO_V02_DMG_SHA256" \
        --arg appcast_sha256 "$(
            /usr/bin/shasum -a 256 "$handoff/feed/appcast.xml" |
                /usr/bin/awk '{print $1}'
        )" \
        --argjson draft_id "$(/usr/bin/jq -er '.id' "$handoff/final-draft.json")" '
        (.control_commit | test("^[0-9a-f]{40}$"))
        and .candidate_commit == $candidate_commit
        and .candidate_tag == $candidate_tag
        and .final_tag == $final_tag
        and .final_draft_id == $draft_id
        and .dmg_sha256 == $dmg_sha256
        and .appcast_sha256 == $appcast_sha256
        and (keys | sort) == [
            "appcast_sha256", "candidate_commit", "candidate_tag",
            "control_commit", "dmg_sha256", "final_draft_id", "final_tag"
        ]
    ' "$handoff/publication-manifest.json" >/dev/null || \
        fail "The private G56 publication manifest is invalid."
fi

echo "CopyLasso G56 publication-control audit passed."
