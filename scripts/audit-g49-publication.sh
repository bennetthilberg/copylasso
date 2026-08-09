#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly metadata="$repository_root/Configuration/ReleaseMetadata.xcconfig"
readonly notes="$repository_root/docs/release-notes/0.2.1.md"
readonly workflow="$repository_root/.github/workflows/prepare-publication.yml"
readonly verifier="$repository_root/scripts/lib/v02-publication-verification.sh"
readonly publication_audit="$repository_root/scripts/audit-v02-publication.sh"
readonly publication_test="$repository_root/scripts/test-v02-publication.sh"
readonly candidate_workflow="$repository_root/.github/workflows/release.yml"
readonly checklist="$repository_root/docs/release-checklist.md"
readonly runbook="$repository_root/docs/v0.2-publication-runbook.md"

fail() {
    echo "$1" >&2
    exit 1
}

require_text() {
    local file="$1"
    local required="$2"

    /usr/bin/grep -Fq -- "$required" "$file" || \
        fail "G49 publication control is missing: $required"
}

for required_file in \
    "$metadata" \
    "$notes" \
    "$workflow" \
    "$verifier" \
    "$publication_audit" \
    "$publication_test" \
    "$candidate_workflow" \
    "$checklist" \
    "$runbook"; do
    [[ -s "$required_file" ]] || fail "Required G49 file is unavailable: $required_file"
done

require_text "$metadata" 'COPYLASSO_RELEASE_VERSION = 0.2.1'
require_text "$metadata" 'COPYLASSO_RELEASE_BUILD = 4'
require_text "$verifier" 'COPYLASSO_RELEASE_VERSION="0.2.1"'
require_text "$verifier" 'COPYLASSO_RELEASE_BUILD="4"'
require_text "$verifier" \
    'COPYLASSO_V02_CANDIDATE_COMMIT="813de17c739097217aad55a5a35c04ea3c73d99f"'
require_text "$verifier" 'COPYLASSO_V02_CANDIDATE_RELEASE_ID="367523470"'
require_text "$verifier" 'COPYLASSO_V02_CANDIDATE_TAG="v0.2.1-rc.1"'
require_text "$verifier" 'COPYLASSO_V02_FINAL_TAG="v0.2.1"'
require_text "$verifier" 'COPYLASSO_V02_PREVIOUS_PUBLIC_TAG="v0.2.0"'
require_text "$verifier" \
    'COPYLASSO_V02_NOTES_SHA256="24dd1c6c235ba0e0d0bf433e07d6b1ddd5a8c2425fa368a4fa16926eb016b503"'
require_text "$verifier" \
    'COPYLASSO_V02_CANDIDATE_APPCAST_SHA256="ef48b25ed3527416ba2242cae4bf3975b3c61d21790e24e0b31669a1082bf779"'
require_text "$verifier" \
    'COPYLASSO_V02_DMG_SHA256="05180caa3600bcd282246297a9172517136e43e55c6e8fa192b55ba44af4a017"'
require_text "$verifier" \
    'COPYLASSO_V02_CHECKSUM_SHA256="b9a85f82686dce479cb41247fe9fc025ec8a0d099bbc08028c4239899359b1c9"'
require_text "$verifier" \
    'COPYLASSO_V02_DSYM_SHA256="0301eecaccb9fac76c1e25d2ae1db2edc99ff42febe55bfcf6f07ef4ffcbd368"'
require_text "$verifier" \
    'COPYLASSO_V02_VERIFICATION_SHA256="689aad0296e90b9aab83e198eaef0524da907d1742fbeab8078bddc823a1b108"'

require_text "$workflow" 'types: [copylasso_prepare_publication]'
require_text "$workflow" \
    "github.event_name == 'repository_dispatch' && github.event.action == 'copylasso_prepare_publication' && github.ref == 'refs/heads/main'"
require_text "$workflow" 'uses: ./.github/workflows/ci.yml'
require_text "$workflow" 'environment:'
require_text "$workflow" 'name: release'
require_text "$workflow" 'cancel-in-progress: false'
require_text "$workflow" 'persist-credentials: false'
require_text "$workflow" './scripts/download-v02-candidate.sh'
require_text "$workflow" './scripts/verify-v02-candidate-package.sh'
require_text "$workflow" './scripts/generate-release-appcast.sh'
require_text "$workflow" './scripts/prepare-update-feed.sh'
require_text "$workflow" './scripts/create-v02-publication-draft.sh'
require_text "$workflow" './scripts/audit-v02-publication.sh'
require_text "$workflow" 'copylasso-v0.2.1-publication'

if /usr/bin/grep -Fq '${{ github.event.client_payload.' "$workflow"; then
    fail "G49 publication preparation must accept no dispatch payload."
fi
if /usr/bin/grep -Eq \
    'build-release-candidate|xcodebuild[[:space:]]+(archive|-exportArchive)|notarytool[[:space:]]+submit|stapler[[:space:]]+staple' \
    "$workflow"; then
    fail "G49 must consume the immutable candidate without rebuilding or renotarizing it."
fi
if /usr/bin/grep -Eiq \
    'release (publish|edit.+--draft=false)|make_latest=true|--clobber|force=true|git push|git tag|wrangler|pages deploy' \
    "$workflow"; then
    fail "G49 Phase 1 must not publish, tag, overwrite, or deploy."
fi
if /usr/bin/grep -Eq \
    '(^|[[:space:]])(publish|make_latest|draft:[[:space:]]*false)([[:space:]]|$)' \
    "$candidate_workflow"; then
    fail "The approved G48 candidate workflow must remain draft-only."
fi

require_text "$checklist" '## G49 - Publish CopyLasso v0.2.1'
require_text "$runbook" '## G49 v0.2.1 Patch Publication'
require_text "$runbook" 'Never rebuild the G48 candidate'
require_text "$runbook" 'Never move either tag'
require_text "$runbook" 'Never replace a public asset'

echo "CopyLasso G49 publication audit passed."
