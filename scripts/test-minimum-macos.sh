#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly app="${1:-}"
readonly expected_macos_major="${COPYLASSO_MINIMUM_OS_MAJOR:-14}"
readonly entitlements="$repository_root/CopyLasso/CopyLasso.entitlements"

if [[ -z "$app" ]] || [[ ! -d "$app" ]]; then
    echo "Usage: $0 <CopyLasso.app>" >&2
    exit 1
fi

readonly product_version="$(/usr/bin/sw_vers -productVersion)"
if [[ "$product_version" != "$expected_macos_major".* ]]; then
    echo "Minimum-OS smoke requires macOS $expected_macos_major.x; found $product_version." >&2
    exit 1
fi

readonly info_plist="$app/Contents/Info.plist"
readonly executable="$app/Contents/MacOS/CopyLasso"
if [[ ! -f "$info_plist" ]] || [[ ! -x "$executable" ]]; then
    echo "The Release application artifact is incomplete." >&2
    exit 1
fi

if [[ "$(/usr/bin/plutil -extract LSMinimumSystemVersion raw -o - "$info_plist")" != "14.0" ]] || \
    [[ "$(/usr/bin/plutil -extract LSUIElement raw -o - "$info_plist")" != "true" ]]; then
    echo "The runtime artifact must target macOS 14.0 and remain dockless." >&2
    exit 1
fi

readonly architectures="$(/usr/bin/lipo -archs "$executable")"
for architecture in arm64 x86_64; do
    if [[ " $architectures " != *" $architecture "* ]]; then
        echo "The runtime artifact is missing $architecture." >&2
        exit 1
    fi
    if [[ "$(/usr/bin/xcrun vtool -arch "$architecture" -show-build "$executable" | \
        /usr/bin/grep -c 'minos 14\.0')" != 1 ]]; then
        echo "The $architecture executable slice does not declare a macOS 14.0 minimum runtime." >&2
        exit 1
    fi
done

/usr/bin/codesign \
    --force \
    --deep \
    --sign - \
    --timestamp=none \
    --options runtime \
    --entitlements "$entitlements" \
    "$app"
/usr/bin/codesign --verify --deep --strict "$app"

readonly launch_log="$(/usr/bin/mktemp -t copylasso-minimum-os).log"
pid=""
cleanup() {
    if [[ -n "$pid" ]] && /bin/kill -0 "$pid" 2>/dev/null; then
        /bin/kill -TERM "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    fi
    /bin/rm -f "$launch_log"
}
trap cleanup EXIT

"$executable" > "$launch_log" 2>&1 &
pid="$!"

for _ in 1 2 3 4 5 6 7 8 9 10; do
    if ! /bin/kill -0 "$pid" 2>/dev/null; then
        echo "CopyLasso exited during minimum-OS startup." >&2
        /bin/cat "$launch_log" >&2
        exit 1
    fi
    /bin/sleep 0.2
done

/bin/kill -TERM "$pid"
set +e
wait "$pid" 2>/dev/null
termination_status="$?"
set -e
pid=""

if [[ "$termination_status" != 0 ]] && [[ "$termination_status" != 143 ]]; then
    echo "CopyLasso returned an unexpected status after the runtime smoke: $termination_status" >&2
    /bin/cat "$launch_log" >&2
    exit 1
fi

echo "CopyLasso launched on macOS $product_version and remained alive for the smoke interval."
