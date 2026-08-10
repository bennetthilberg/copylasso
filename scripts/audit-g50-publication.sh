#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly workflow="$repository_root/.github/workflows/prepare-v022-publication.yml"
readonly verifier="$repository_root/scripts/lib/v02-publication-verification.sh"
readonly package_metadata="$repository_root/scripts/lib/v022-release-package-metadata.sh"
readonly notes="$repository_root/scripts/fixtures/v0.2.2-published-release-notes.md"
readonly focused_tests="$repository_root/scripts/test-g50-publication.sh"
readonly runbook="$repository_root/docs/v0.2-publication-runbook.md"
readonly release_workflow="$repository_root/docs/release-workflow.md"
readonly operations="$repository_root/docs/secure-update-operations.md"
readonly checklist="$repository_root/docs/release-checklist.md"

export COPYLASSO_V02_PUBLICATION_PROFILE=v0.2.2
# shellcheck source=scripts/lib/v02-publication-verification.sh
source "$verifier"

usage() {
    cat >&2 <<'TEXT'
Usage: audit-g50-publication.sh
       audit-g50-publication.sh \
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
        fail "G50 publication control is missing: $required"
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
        fail "Required G50 publication file is unavailable: $required_file"
done

for executable in "$focused_tests"; do
    [[ -x "$executable" ]] || \
        fail "Required G50 publication test is not executable: $executable"
done

require_text "$verifier" 'COPYLASSO_V02_PUBLICATION_PROFILE:-v0.2.1'
require_text "$verifier" 'v0.2.2)'
require_text "$verifier" 'COPYLASSO_V02_CANDIDATE_COMMIT="81016fe43ee617b5f251564b03904137a4447266"'
require_text "$verifier" 'COPYLASSO_V02_CANDIDATE_RELEASE_ID="367632598"'
require_text "$verifier" 'COPYLASSO_V02_CANDIDATE_TAG="v0.2.2-rc.1"'
require_text "$verifier" 'COPYLASSO_V02_FINAL_TAG="v0.2.2"'
require_text "$verifier" 'COPYLASSO_V02_PREVIOUS_PUBLIC_TAG="v0.2.1"'
require_text "$verifier" 'COPYLASSO_V02_DMG_SHA256="9ac432f956418dd37e04de014867a7fc20d1daeecc80f6fe1db1e9c53b19de2a"'
require_text "$verifier" 'COPYLASSO_V02_CHECKSUM_SHA256="346605180b76d4959736267158138018b869d62b552b089fefdbe7aafa3031ca"'
require_text "$verifier" 'COPYLASSO_V02_DSYM_SHA256="a797d0053209ab4d60a8c1d25cd9f384709c9282336c84c0d291e5c187811dd8"'
require_text "$verifier" 'COPYLASSO_V02_VERIFICATION_SHA256="657be6e3fffb0439e82b865713269300bc1177eb49cca7d0c321be15e977991d"'
require_text "$verifier" 'COPYLASSO_V02_CANDIDATE_APPCAST_SHA256="d929a6dc7bc70667af0072f684cfcdf6eea79b15f3614e6ed36c1f88f3d0c27b"'
require_text "$verifier" 'COPYLASSO_V02_NOTES_SHA256="df42f13d9ba08fba153b3d7d7d52f828cf9874ea52eec930f249ac7566115af7"'
require_text "$verifier" 'COPYLASSO_V02_RELEASE_PACKAGE_PROFILE="v0.2.2"'
require_text "$verifier" 'scripts/fixtures/v0.2.2-published-release-notes.md'

require_text "$workflow" 'types: [copylasso_prepare_v022_publication]'
require_text "$workflow" "github.event.action == 'copylasso_prepare_v022_publication'"
require_text "$workflow" 'COPYLASSO_V02_PUBLICATION_PROFILE: v0.2.2'
require_text "$workflow" 'uses: ./.github/workflows/ci.yml'
require_text "$workflow" 'name: release'
require_text "$workflow" 'cancel-in-progress: false'
require_text "$workflow" 'persist-credentials: false'
require_text "$workflow" './scripts/download-v02-candidate.sh'
require_text "$workflow" './scripts/verify-v02-candidate-package.sh'
require_text "$workflow" './scripts/generate-release-appcast.sh'
require_text "$workflow" './scripts/prepare-update-feed.sh'
require_text "$workflow" './scripts/create-v02-publication-draft.sh'
require_text "$workflow" './scripts/audit-g50-publication.sh'
require_text "$workflow" 'copylasso-v0.2.2-publication'

[[ "$(/usr/bin/grep -Ec '^[[:space:]]*contents: write[[:space:]]*$' "$workflow")" == "1" ]] || \
    fail "Only the protected G50 preparation job may receive contents write permission."
[[ "$(/usr/bin/grep -Fc 'COPYLASSO_SPARKLE_PRIVATE_KEY: ${{ secrets.COPYLASSO_SPARKLE_PRIVATE_KEY }}' "$workflow")" == "1" ]] || \
    fail "The Sparkle seed must enter exactly one narrow G50 step."
[[ "$(/usr/bin/grep -Fc 'COPYLASSO_EXPECTED_TEAM_ID: ${{ secrets.COPYLASSO_EXPECTED_TEAM_ID }}' "$workflow")" == "1" ]] || \
    fail "The release team must enter exactly one G50 verification step."
for prohibited_secret in \
    COPYLASSO_DEVELOPER_ID_P12_BASE64 \
    COPYLASSO_DEVELOPER_ID_P12_PASSWORD \
    COPYLASSO_NOTARY_KEY_BASE64 \
    COPYLASSO_NOTARY_KEY_ID \
    COPYLASSO_NOTARY_ISSUER_ID; do
    if /usr/bin/grep -Fq "secrets.$prohibited_secret" "$workflow"; then
        fail "G50 publication preparation must not receive build credentials."
    fi
done
while IFS= read -r action_target; do
    case "$action_target" in
        ./*) ;;
        *@????????????????????????????????????????) ;;
        *) fail "The G50 workflow contains a mutable action reference: $action_target" ;;
    esac
done < <(/usr/bin/sed -nE \
    's/^[[:space:]]*uses:[[:space:]]*([^[:space:]]+).*$/\1/p' "$workflow")

if /usr/bin/grep -Fq '${{ github.event.client_payload.' "$workflow"; then
    fail "G50 publication preparation must accept no dispatch payload."
fi
if /usr/bin/grep -Eq \
    'build-release-candidate|xcodebuild[[:space:]]+(archive|-exportArchive)|notarytool[[:space:]]+submit|stapler[[:space:]]+staple' \
    "$workflow"; then
    fail "G50 publication preparation must consume the candidate without rebuilding."
fi
if /usr/bin/grep -Eiq \
    'release (publish|edit.+--draft=false)|make_latest=true|--clobber|force=true|git push|git tag|wrangler|pages deploy' \
    "$workflow"; then
    fail "G50 publication preparation must not publish, tag, replace, or deploy."
fi

require_text "$runbook" '## G50 v0.2.2 Security-Hotfix Publication'
require_text "$release_workflow" '## G50 Publication Preparation'
require_text "$operations" '## G50 v0.2.2 Publication Boundary'
require_text "$checklist" '## G50 - Patch Sparkle Security Advisory'

credential_marker='set -x|BEGIN '
credential_marker+='([A-Z ]+ )?PRIVATE KEY|[a-z]{4}-[a-z]{4}-[a-z]{4}-[a-z]{4}'
if /usr/bin/grep -Eq "$credential_marker" \
    "$workflow" "$verifier" "$runbook" "$operations"; then
    fail "G50 publication controls contain unsafe tracing or credential-like material."
fi

assert_v02_release_notes "$notes"
if [[ -n "$handoff" ]]; then
    [[ -d "$handoff" && ! -L "$handoff" ]] || \
        fail "The private G50 publication handoff is unavailable."
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
        fail "The private G50 handoff contains an unexpected top-level entry."

    assert_v02_candidate_release_record "$handoff/candidate-release.json" "$notes"
    assert_v02_candidate_tag_record "$handoff/candidate-tag.json"
    assert_v02_publication_draft_record "$handoff/final-draft.json" "$notes"
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
        --argjson draft_id "$(/usr/bin/jq -er '.id' "$handoff/final-draft.json")" '
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
        fail "The private G50 publication manifest differs from the reviewed contract."
fi

echo "CopyLasso G50 publication-control audit passed."
