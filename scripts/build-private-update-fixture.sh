#!/bin/bash

set -euo pipefail
umask 077

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly fixture_root="$repository_root/.build/g36-private-update"
readonly package_root="$repository_root/.build/g36-private-update-packages"
readonly sparkle_tools="${COPYLASSO_SPARKLE_TOOLS_DIR:-}"
readonly fixture_port="${COPYLASSO_PRIVATE_UPDATE_PORT:-58361}"
readonly fixture_bundle_identifier='io.github.bennetthilberg.copylasso.g36fixture'
readonly installed_version='0.1.1'
readonly installed_build='2'
readonly update_version='0.2.0'
readonly update_build='3'
readonly feed_url="http://127.0.0.1:$fixture_port/appcast.xml"
readonly archive_name="CopyLasso-$update_version.zip"
readonly rollback_archive_name="CopyLasso-$installed_version.zip"

fail() {
  echo "$1" >&2
  exit 1
}

[[ "$fixture_port" =~ ^[0-9]+$ ]] && \
  ((fixture_port >= 1024 && fixture_port <= 65535)) || \
  fail "COPYLASSO_PRIVATE_UPDATE_PORT must be a nonprivileged TCP port."
[[ -x "$sparkle_tools/generate_appcast" ]] || \
  fail "Set COPYLASSO_SPARKLE_TOOLS_DIR to the pinned Sparkle 2.9.4 tools."
[[ ! -L "$fixture_root" ]] || fail "The private fixture root must not be a symbolic link."

/bin/rm -rf "$fixture_root"
/bin/mkdir -p "$fixture_root/config" "$fixture_root/serve" "$fixture_root/installed"
/bin/cp "$repository_root/Configuration/CopyLasso-Info.plist" \
  "$fixture_root/config/CopyLasso-Info.plist"
/usr/libexec/PlistBuddy -c "Set :SUFeedURL $feed_url" \
  "$fixture_root/config/CopyLasso-Info.plist"
/usr/libexec/PlistBuddy -c 'Add :NSAppTransportSecurity dict' \
  "$fixture_root/config/CopyLasso-Info.plist"
/usr/libexec/PlistBuddy -c 'Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true' \
  "$fixture_root/config/CopyLasso-Info.plist"

build_fixture() {
  local version="$1"
  local build="$2"
  local derived_data="$3"

  xcodebuild build \
    -project "$repository_root/CopyLasso.xcodeproj" \
    -scheme CopyLasso \
    -configuration Debug \
    -derivedDataPath "$derived_data" \
    -clonedSourcePackagesDirPath "$package_root" \
    -destination 'platform=macOS,arch=arm64' \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=YES \
    "INFOPLIST_FILE=$fixture_root/config/CopyLasso-Info.plist" \
    "PRODUCT_BUNDLE_IDENTIFIER=$fixture_bundle_identifier" \
    "MARKETING_VERSION=$version" \
    "CURRENT_PROJECT_VERSION=$build" \
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG COPYLASSO_PRIVATE_UPDATE_FIXTURE' \
    CODE_SIGN_STYLE=Automatic \
    -quiet
}

build_fixture "$installed_version" "$installed_build" "$fixture_root/old"
build_fixture "$update_version" "$update_build" "$fixture_root/new"

readonly old_app="$fixture_root/old/Build/Products/Debug/CopyLasso.app"
readonly new_app="$fixture_root/new/Build/Products/Debug/CopyLasso.app"
for application in "$old_app" "$new_app"; do
  [[ -d "$application" ]] || fail "A private update fixture application is missing."
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$application" >/dev/null
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$application/Contents/Info.plist")" == \
      "$fixture_bundle_identifier" ]] || fail "A private update fixture has the wrong identity."
done
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$old_app/Contents/Info.plist")" == \
    "$installed_build" ]] || fail "The private installed fixture has the wrong build."
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$new_app/Contents/Info.plist")" == \
    "$update_build" ]] || fail "The private update fixture has the wrong build."

/usr/bin/ditto "$old_app" "$fixture_root/installed/CopyLasso.app"
/usr/bin/ditto -c -k --keepParent "$new_app" "$fixture_root/serve/$archive_name"
/usr/bin/printf '%s\n' \
  'Private G36 fixture: verify user-controlled download, install, relaunch, and state retention.' \
  > "$fixture_root/serve/CopyLasso-$update_version.txt"

"$sparkle_tools/generate_appcast" \
  --account copylasso \
  --embed-release-notes \
  --disable-signing-warning \
  --download-url-prefix "http://127.0.0.1:$fixture_port/" \
  --versions "$update_build" \
  --maximum-deltas 0 \
  --maximum-versions 1 \
  -o "$fixture_root/serve/appcast.xml" \
  "$fixture_root/serve" >/dev/null

/usr/bin/ditto -c -k --keepParent \
  "$old_app" \
  "$fixture_root/serve/$rollback_archive_name"
/usr/bin/printf '%s\n' \
  'Private G36 rollback fixture: the installed newer build must reject this candidate.' \
  > "$fixture_root/serve/CopyLasso-$installed_version.txt"
"$sparkle_tools/generate_appcast" \
  --account copylasso \
  --embed-release-notes \
  --disable-signing-warning \
  --download-url-prefix "http://127.0.0.1:$fixture_port/" \
  --versions "$installed_build" \
  --maximum-deltas 0 \
  --maximum-versions 1 \
  -o "$fixture_root/serve/appcast-rollback.xml" \
  "$fixture_root/serve" >/dev/null

/usr/bin/xmllint --nonet --noout "$fixture_root/serve/appcast.xml"
/usr/bin/xmllint --nonet --noout "$fixture_root/serve/appcast-rollback.xml"
/bin/cp "$fixture_root/serve/appcast.xml" "$fixture_root/serve/appcast-valid.xml"
/usr/bin/sed 's/Private G36 fixture/Private G36 invalid/' \
  "$fixture_root/serve/appcast-valid.xml" > "$fixture_root/serve/appcast-invalid.xml"
/usr/bin/cmp -s \
  "$fixture_root/serve/appcast-valid.xml" \
  "$fixture_root/serve/appcast-invalid.xml" && \
  fail "The deliberately invalid private appcast was not mutated."
/bin/cp "$fixture_root/serve/appcast-invalid.xml" "$fixture_root/serve/appcast.xml"

cat <<EOF
Private G36 update fixture is ready.
Installed app: $fixture_root/installed/CopyLasso.app
Loopback directory: $fixture_root/serve
Initial feed: intentionally signature-invalid
Valid feed: $fixture_root/serve/appcast-valid.xml
Signed rollback feed: $fixture_root/serve/appcast-rollback.xml
Port: $fixture_port
EOF
