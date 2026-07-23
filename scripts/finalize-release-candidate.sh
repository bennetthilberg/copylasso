#!/bin/bash

set -euo pipefail
umask 077

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/release-workflow-verification.sh
source "$repository_root/scripts/lib/release-workflow-verification.sh"
# shellcheck source=scripts/lib/release-package-verification.sh
source "$repository_root/scripts/lib/release-package-verification.sh"

usage() {
    cat >&2 <<'TEXT'
Usage: finalize-release-candidate.sh \
  --source-commit <40-character-commit> \
  --handoff /path/under/RUNNER_TEMP/<commit> \
  --output-dir /path/to/repository/dist/<release-mode>/<commit>/run
TEXT
    exit 64
}

source_commit=""
handoff_candidate=""
output_directory=""
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --source-commit)
            [[ "$#" -ge 2 ]] || usage
            source_commit="$2"
            shift 2
            ;;
        --handoff)
            [[ "$#" -ge 2 ]] || usage
            handoff_candidate="$2"
            shift 2
            ;;
        --output-dir)
            [[ "$#" -ge 2 ]] || usage
            output_directory="$2"
            shift 2
            ;;
        *) usage ;;
    esac
done
[[ -n "$source_commit" && -n "$handoff_candidate" && -n "$output_directory" ]] || usage

sparkle_private_key="${COPYLASSO_SPARKLE_PRIVATE_KEY:-}"
unset COPYLASSO_SPARKLE_PRIVATE_KEY
[[ -n "$sparkle_private_key" ]] || \
    protected_release_fail "The protected Sparkle signing secret is unavailable."

assert_full_release_commit "$source_commit"
assert_release_source_state \
    "$repository_root" \
    "${GITHUB_REF:-refs/heads/main}" \
    "$source_commit"
assert_release_state_directory "$handoff_candidate"
[[ "$(basename "$handoff_candidate")" == "$source_commit" ]] || \
    protected_release_fail "The release handoff must be named for the exact protected commit."
[[ -d "$handoff_candidate" && ! -L "$handoff_candidate" ]] || \
    protected_release_fail "The protected release handoff is unavailable."
[[ -d "$output_directory" && ! -L "$output_directory" ]] || \
    protected_release_fail "The protected release output is unavailable."

readonly application="$handoff_candidate/export/CopyLasso.app"
readonly source_packages="$handoff_candidate/SourcePackages"
readonly verification_bundle="$output_directory/$COPYLASSO_G28_VERIFICATION"
[[ -d "$application" && ! -L "$application" ]] || \
    protected_release_fail "The protected CopyLasso application is unavailable."
[[ ! -e "$verification_bundle" && ! -L "$verification_bundle" ]] || \
    protected_release_fail "The protected verification bundle already exists."

readonly sparkle_generate_appcast="$(/usr/bin/find "$source_packages/artifacts" \
    -type f -path '*/bin/generate_appcast' -print -quit)"
[[ -n "$sparkle_generate_appcast" ]] || \
    protected_release_fail "The reviewed Sparkle appcast tool is unavailable."
readonly verification_staging="$(mktemp -d "${TMPDIR:-/tmp}/copylasso-g36-verification.XXXXXX")"
cleanup_verification_staging() {
    /bin/rm -rf "$verification_staging"
}
trap cleanup_verification_staging EXIT

/bin/mkdir -p \
    "$verification_staging/payload/$source_commit/export" \
    "$verification_staging/run"
/usr/bin/ditto \
    "$application" \
    "$verification_staging/payload/$source_commit/export/CopyLasso.app"
for evidence_file in \
    notary-submission.json \
    notary-log.json \
    release-evidence.txt \
    payload-manifest.txt; do
    /bin/cp "$output_directory/$evidence_file" "$verification_staging/run/$evidence_file"
done
COPYLASSO_SPARKLE_PRIVATE_KEY="$sparkle_private_key" \
    "$repository_root/scripts/generate-draft-appcast.sh" \
        --application "$application" \
        --dmg "$output_directory/$COPYLASSO_G28_DMG" \
        --release-notes "$repository_root/docs/release-notes/$COPYLASSO_RELEASE_VERSION.md" \
        --output "$verification_staging/run/$COPYLASSO_RELEASE_APPCAST" \
        --sparkle-tools-dir "$(/usr/bin/dirname "$sparkle_generate_appcast")"
unset sparkle_private_key

printf 'payload_commit=%s\npackaging_commit=%s\n' \
    "$source_commit" "$source_commit" \
    > "$verification_staging/verification-layout.txt"
if ! /usr/bin/ditto -c -k --norsrc --noextattr \
    "$verification_staging" "$verification_bundle"; then
    protected_release_fail "The protected local-verification bundle could not be created."
fi
if [[ "$(/usr/bin/unzip -Z1 "$verification_bundle" | \
    /usr/bin/grep -Ec "(^|/)run/$COPYLASSO_RELEASE_APPCAST$")" != "1" ]]; then
    protected_release_fail \
        "The private verification bundle is missing authenticated draft update metadata."
fi

assert_release_workflow_assets "$output_directory" "$verification_bundle"
cleanup_verification_staging
trap - EXIT

echo "Protected release candidate update metadata created and verified."
