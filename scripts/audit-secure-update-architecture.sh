#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly project="$repository_root/CopyLasso.xcodeproj/project.pbxproj"
readonly package_lock="$repository_root/CopyLasso.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
readonly entitlements="$repository_root/CopyLasso/CopyLasso.entitlements"
readonly product_info="$repository_root/Configuration/CopyLasso-Info.plist"
readonly release_metadata="$repository_root/Configuration/ReleaseMetadata.xcconfig"
readonly notices="$repository_root/THIRD_PARTY_NOTICES.md"

fail() {
    echo "$1" >&2
    exit 1
}

require_literal() {
    local file="$1"
    local literal="$2"
    local message="$3"
    /usr/bin/grep -Fq "$literal" "$file" || fail "$message"
}

for document in \
    "$repository_root/docs/architecture/ADR-004-secure-updates.md" \
    "$repository_root/docs/secure-update-threat-model.md" \
    "$repository_root/docs/secure-update-operations.md"; do
    [[ -f "$document" ]] || fail "Missing secure-update architecture document: $(basename "$document")"
done

for executable in \
    "$repository_root/scripts/test-secure-update-architecture.sh" \
    "$repository_root/scripts/test-secure-update-signatures.sh"; do
    [[ -x "$executable" ]] || fail "Missing executable secure-update proof: $(basename "$executable")"
done
[[ -f "$repository_root/scripts/fixtures/SignedAppcastParserProbe.m" ]] || \
    fail "The signed malformed-appcast parser probe is missing."

require_literal "$project" 'repositoryURL = "https://github.com/sparkle-project/Sparkle";' \
    "Sparkle must come from the reviewed upstream repository."
require_literal "$project" 'kind = exactVersion;' \
    "Swift packages must retain exact version requirements."
require_literal "$project" 'version = 2.9.4;' \
    "Sparkle must remain pinned to 2.9.4."
require_literal "$package_lock" '"identity" : "sparkle"' \
    "Package.resolved must include Sparkle."
require_literal "$package_lock" '"revision" : "b6496a74a087257ef5e6da1c5b29a447a60f5bd7"' \
    "Package.resolved must lock the reviewed Sparkle revision."
require_literal "$package_lock" '"version" : "2.9.4"' \
    "Package.resolved must lock Sparkle 2.9.4."

app_target="$(/usr/bin/awk '
    /^\t\tAACED2EA30004BEB001F9909 \/\* CopyLasso \*\/ = \{$/ { capture = 1 }
    capture { print }
    capture && /^\t\t};$/ { exit }
' "$project")"
test_target="$(/usr/bin/awk '
    /^\t\tAACED2F730004BEC001F9909 \/\* CopyLassoTests \*\/ = \{$/ { capture = 1 }
    capture { print }
    capture && /^\t\t};$/ { exit }
' "$project")"
if /usr/bin/grep -Fq 'Sparkle' <<< "$app_target"; then
    fail "G35 must not link Sparkle into the CopyLasso application target."
fi
if ! /usr/bin/grep -Fq 'Sparkle' <<< "$test_target"; then
    fail "G35 must link Sparkle into CopyLassoTests for the architecture proof."
fi

sparkle_imports="$({
    /usr/bin/grep -R -l --include='*.swift' '^import Sparkle$' \
        "$repository_root/CopyLasso" "$repository_root/CopyLassoTests" || true
})"
if [[ "$sparkle_imports" != "$repository_root/CopyLassoTests/Update/SecureUpdateArchitectureProofTests.swift" ]]; then
    fail "Sparkle imports must remain confined to the G35 proof test."
fi

if /usr/bin/grep -Eq 'com\.apple\.security\.network\.client|mach-lookup' "$entitlements"; then
    fail "G35 must not change the shipping sandbox or networking entitlements."
fi
if /usr/bin/grep -Eq '<key>SU[A-Za-z]+' "$product_info"; then
    fail "G35 must not configure a shipping updater."
fi
if /usr/bin/grep -Fqi 'Sparkle' "$notices"; then
    fail "Test-only Sparkle must not be represented as a shipped dependency in G35."
fi

if [[ -n "${COPYLASSO_SECURE_UPDATE_APP:-}" ]]; then
    application="$COPYLASSO_SECURE_UPDATE_APP"
    [[ -d "$application" ]] || fail "The secure-update app audit requires a built application."
    if /usr/bin/find "$application" -iname '*Sparkle*' -print -quit | \
        /usr/bin/grep -q .; then
        fail "The G35 application bundle must not contain Sparkle."
    fi
    executable="$application/Contents/MacOS/CopyLasso"
    [[ -x "$executable" ]] || fail "The secure-update app audit cannot find CopyLasso."
    if /usr/bin/otool -L "$executable" | /usr/bin/grep -Fqi 'Sparkle'; then
        fail "The G35 application executable must not link Sparkle."
    fi
    if /usr/bin/plutil -p "$application/Contents/Info.plist" | \
        /usr/bin/grep -Eq '"SU[A-Za-z]+'; then
        fail "The G35 built application must not configure Sparkle."
    fi
fi

require_literal "$release_metadata" 'COPYLASSO_RELEASE_VERSION = 0.1.1' \
    "G35 must not change the released version."
require_literal "$release_metadata" 'COPYLASSO_RELEASE_BUILD = 2' \
    "G35 must not change the released build."

require_literal "$repository_root/docs/architecture/ADR-004-secure-updates.md" \
    'https://updates.copylasso.com/appcast.xml' \
    "The ADR must lock the future feed endpoint."
require_literal "$repository_root/docs/architecture/ADR-004-secure-updates.md" \
    'cb6fdbdc8884f15d62a616e79face92b08322410fd2d425edc6596ccbf4ba3b0' \
    "The ADR must record the official Sparkle artifact checksum."
require_literal "$repository_root/docs/secure-update-threat-model.md" \
    'highest authenticated build' \
    "The threat model must cover authenticated rollback state."
require_literal "$repository_root/docs/secure-update-operations.md" \
    '0.1.x contains no updater' \
    "Operations must explain the manual 0.1.x bootstrap."

if /usr/bin/git -C "$repository_root" ls-files | \
    /usr/bin/grep -Eq '(^|/)(appcast[^/]*\.xml|[^/]*\.(pem|p12|key))$'; then
    fail "G35 must not track a public feed or signing-key material."
fi
private_key_marker='BEGIN '
private_key_marker+='(OPENSSH|EC|RSA|PRIVATE) PRIVATE KEY'
if /usr/bin/git -C "$repository_root" grep -nE \
    -- "$private_key_marker|sparkle:edSignature=\"[A-Za-z0-9+/=]{20,}\"" \
    -- ':!docs/**' ':!scripts/test-secure-update-signatures.sh'; then
    fail "G35 must not contain production key or signature material."
fi

echo "CopyLasso secure-update architecture audit passed."
