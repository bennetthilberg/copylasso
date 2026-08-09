#!/bin/bash

set -euo pipefail
umask 077

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
# shellcheck source=scripts/lib/v02-publication-verification.sh
source "$repository_root/scripts/lib/v02-publication-verification.sh"

usage() {
    cat >&2 <<'TEXT'
Usage: prepare-update-feed.sh \
  --appcast /path/to/appcast.xml \
  --release-notes /path/to/0.2.1.md \
  --output-dir /path/to/new-feed-directory
TEXT
    exit 64
}

appcast=""
release_notes=""
output_directory=""
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --appcast)
            [[ "$#" -ge 2 ]] || usage
            appcast="$2"
            shift 2
            ;;
        --release-notes)
            [[ "$#" -ge 2 ]] || usage
            release_notes="$2"
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
[[ -n "$appcast" && -n "$release_notes" && -n "$output_directory" ]] || usage

assert_v02_appcast_contract "$appcast" "$release_notes"
[[ ! -e "$output_directory" && ! -L "$output_directory" ]] || \
    v02_publication_fail "The updater feed destination already exists."
readonly output_parent="$(/usr/bin/dirname "$output_directory")"
[[ -d "$output_parent" && ! -L "$output_parent" ]] || \
    v02_publication_fail "The updater feed parent is unavailable."

readonly temporary_directory="$(/usr/bin/mktemp -d \
    "$output_parent/.copylasso-v02-feed.XXXXXX")"
committed="false"
cleanup() {
    if [[ "$committed" != "true" ]]; then
        /bin/rm -rf "$output_directory"
    fi
    /bin/rm -rf "$temporary_directory"
}
trap cleanup EXIT

/bin/cp "$appcast" "$temporary_directory/$COPYLASSO_V02_PUBLIC_APPCAST_NAME"
/usr/bin/printf '%s\n' \
    '/appcast.xml' \
    '  Cache-Control: public, max-age=300, must-revalidate, no-transform' \
    '  Content-Type: application/xml; charset=utf-8' \
    '  X-Content-Type-Options: nosniff' \
    > "$temporary_directory/_headers"
/bin/chmod 644 \
    "$temporary_directory/$COPYLASSO_V02_PUBLIC_APPCAST_NAME" \
    "$temporary_directory/_headers"
assert_v02_feed_bundle "$temporary_directory"

/bin/mv "$temporary_directory" "$output_directory"
committed="true"
trap - EXIT

echo "Authenticated updater feed deployment bundle prepared."
