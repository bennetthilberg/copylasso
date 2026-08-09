#!/bin/bash

set -euo pipefail
umask 077

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
# shellcheck source=scripts/lib/v02-publication-verification.sh
source "$repository_root/scripts/lib/v02-publication-verification.sh"

usage() {
    cat >&2 <<'TEXT'
Usage: verify-v02-candidate-package.sh \
  --candidate-dir /path/to/downloaded/G48/assets \
  --work-dir /path/to/new-verification-directory
TEXT
    exit 64
}

candidate_directory=""
work_directory=""
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --candidate-dir)
            [[ "$#" -ge 2 ]] || usage
            candidate_directory="$2"
            shift 2
            ;;
        --work-dir)
            [[ "$#" -ge 2 ]] || usage
            work_directory="$2"
            shift 2
            ;;
        *) usage ;;
    esac
done
[[ -n "$candidate_directory" && -n "$work_directory" ]] || usage

assert_v02_candidate_files "$candidate_directory"
[[ ! -e "$work_directory" && ! -L "$work_directory" ]] || \
    v02_publication_fail "The G49 verification work directory already exists."
readonly work_parent="$(/usr/bin/dirname "$work_directory")"
[[ -d "$work_parent" && ! -L "$work_parent" ]] || \
    v02_publication_fail "The G49 verification work parent is unavailable."
[[ "${COPYLASSO_EXPECTED_TEAM_ID:-}" =~ ^[A-Z0-9]{10}$ ]] || \
    v02_publication_fail "The approved release team is unavailable for package verification."

readonly temporary_directory="$(/usr/bin/mktemp -d \
    "$work_parent/.copylasso-v02-verification.XXXXXX")"
committed="false"
cleanup() {
    if [[ "$committed" != "true" ]]; then
        /bin/rm -rf "$work_directory"
    fi
    /bin/rm -rf "$temporary_directory"
}
trap cleanup EXIT
readonly extracted="$temporary_directory/extracted"
readonly verification_run="$temporary_directory/run"
/bin/mkdir "$extracted" "$verification_run"
if ! /usr/bin/ditto -x -k \
    "$candidate_directory/$COPYLASSO_RELEASE_VERIFICATION" "$extracted"; then
    v02_publication_fail "The restricted candidate verification bundle could not be expanded."
fi

readonly layout="$extracted/verification-layout.txt"
readonly application="$extracted/payload/$COPYLASSO_V02_CANDIDATE_COMMIT/export/CopyLasso.app"
readonly private_appcast="$extracted/run/$COPYLASSO_RELEASE_APPCAST"
[[ -f "$layout" && ! -L "$layout" ]] || \
    v02_publication_fail "The candidate verification layout record is missing."
readonly expected_layout="$(
    /usr/bin/printf 'payload_commit=%s\npackaging_commit=%s' \
        "$COPYLASSO_V02_CANDIDATE_COMMIT" "$COPYLASSO_V02_CANDIDATE_COMMIT"
)"
[[ "$(/bin/cat "$layout")" == "$expected_layout" ]] || \
    v02_publication_fail "The candidate verification layout identifies the wrong source."
[[ -d "$application" && ! -L "$application" ]] || \
    v02_publication_fail "The qualified candidate application is missing."
[[ -f "$private_appcast" && ! -L "$private_appcast" ]] || \
    v02_publication_fail "The restricted candidate appcast is missing."
private_appcast_digest="$(
    /usr/bin/shasum -a 256 "$private_appcast" | /usr/bin/awk '{print $1}'
)"
[[ "$private_appcast_digest" == "$COPYLASSO_V02_CANDIDATE_APPCAST_SHA256" ]] || \
    v02_publication_fail "The restricted candidate appcast differs from G48 evidence."

for asset in \
    "$COPYLASSO_RELEASE_DMG" \
    "$COPYLASSO_RELEASE_CHECKSUM" \
    "$COPYLASSO_RELEASE_DSYM"; do
    /bin/cp "$candidate_directory/$asset" "$verification_run/$asset"
done
for evidence in \
    notary-submission.json \
    notary-log.json \
    release-evidence.txt \
    payload-manifest.txt; do
    [[ -f "$extracted/run/$evidence" && ! -L "$extracted/run/$evidence" ]] || \
        v02_publication_fail "The candidate verification record is missing: $evidence"
    /bin/cp "$extracted/run/$evidence" "$verification_run/$evidence"
done

"$repository_root/scripts/verify-release-package.sh" \
    --release-metadata-profile v0.2.1 \
    --payload-app "$application" \
    --payload-commit "$COPYLASSO_V02_CANDIDATE_COMMIT" \
    --packaging-commit "$COPYLASSO_V02_CANDIDATE_COMMIT" \
    "$verification_run"

/bin/mv "$temporary_directory" "$work_directory"
committed="true"
trap - EXIT

echo "Approved G48 candidate package reverified without rebuilding."
