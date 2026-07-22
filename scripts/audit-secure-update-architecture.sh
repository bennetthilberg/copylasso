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
    "$repository_root/scripts/test-secure-update-signatures.sh" \
    "$repository_root/scripts/fixtures/run-secure-update-signatures.sh"; do
    [[ -x "$executable" ]] || fail "Missing executable secure-update proof: $(basename "$executable")"
done
[[ -f "$repository_root/scripts/fixtures/SignedAppcastParserProbe.m" ]] || \
    fail "The signed malformed-appcast parser probe is missing."

package_reference_block() {
    local repository_url="$1"
    /usr/bin/awk -v repository_url="$repository_url" '
        /\/\* Begin XCRemoteSwiftPackageReference section \*\// { in_section = 1; next }
        /\/\* End XCRemoteSwiftPackageReference section \*\// { in_section = 0 }
        in_section && /^\t\t[A-F0-9]+ \/\* .* \*\/ = \{$/ {
            capture = 1
            block = $0 ORS
            next
        }
        capture { block = block $0 ORS }
        capture && /^\t\t};$/ {
            if (index(block, "repositoryURL = \"" repository_url "\";") > 0) {
                printf "%s", block
                exit
            }
            capture = 0
            block = ""
        }
    ' "$project"
}

readonly sparkle_repository='https://github.com/sparkle-project/Sparkle'
if [[ "$(/usr/bin/grep -Fc "repositoryURL = \"$sparkle_repository\";" "$project")" != "1" ]]; then
    fail "The project must contain exactly one reviewed Sparkle package reference."
fi
sparkle_package_reference="$(package_reference_block "$sparkle_repository")"
[[ -n "$sparkle_package_reference" ]] || fail "The Sparkle package reference is missing."
if ! /usr/bin/grep -Fq $'\t\t\t\tkind = exactVersion;' <<< "$sparkle_package_reference"; then
    fail "Sparkle must use an exact version requirement."
fi
if ! /usr/bin/grep -Fq $'\t\t\t\tversion = 2.9.4;' <<< "$sparkle_package_reference"; then
    fail "Sparkle must remain pinned to 2.9.4."
fi
require_literal "$package_lock" '"identity" : "sparkle"' \
    "Package.resolved must include Sparkle."
require_literal "$package_lock" '"revision" : "b6496a74a087257ef5e6da1c5b29a447a60f5bd7"' \
    "Package.resolved must lock the reviewed Sparkle revision."
require_literal "$package_lock" '"version" : "2.9.4"' \
    "Package.resolved must lock Sparkle 2.9.4."

target_block() {
    local target_name="$1"
    /usr/bin/awk -v target_name="$target_name" '
        /\/\* Begin PBXNativeTarget section \*\// { in_section = 1; next }
        /\/\* End PBXNativeTarget section \*\// { in_section = 0 }
        in_section && /^\t\t[A-F0-9]+ \/\* .* \*\/ = \{$/ {
            capture = 1
            block = $0 ORS
            next
        }
        capture { block = block $0 ORS }
        capture && /^\t\t};$/ {
            if (block ~ "\\n\\t\\t\\tname = " target_name ";\\n") {
                printf "%s", block
                exit
            }
            capture = 0
            block = ""
        }
    ' "$project"
}

app_target="$(target_block CopyLasso)"
test_target="$(target_block CopyLassoTests)"
[[ -n "$app_target" ]] || fail "The secure-update audit could not resolve the CopyLasso target."
[[ -n "$test_target" ]] || fail "The secure-update audit could not resolve the CopyLassoTests target."
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

for application in \
    "${COPYLASSO_SECURE_UPDATE_DEBUG_APP:-}" \
    "${COPYLASSO_SECURE_UPDATE_RELEASE_APP:-}"; do
    [[ -n "$application" ]] || continue
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
        fail "The G35 built application must not configure an updater."
    fi
done

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
require_literal "$repository_root/docs/architecture/ADR-004-secure-updates.md" \
    'SUSignedFeedFailureExpirationInterval = 0' \
    "The ADR must retain Sparkle 2.9.4's fail-closed signed-feed expiration key."
require_literal "$repository_root/docs/architecture/ADR-004-secure-updates.md" \
    'no per-redirect decision hook' \
    "The ADR must retain Sparkle's actual redirect integration boundary."
require_literal "$repository_root/docs/architecture/ADR-004-secure-updates.md" \
    'showDownloadDidReceiveDataOfLength:' \
    "The ADR must bind the byte cap to Sparkle's streaming callback."
require_literal "$repository_root/docs/architecture/ADR-004-secure-updates.md" \
    'Release notes must be nonempty inline plain text in the signed appcast.' \
    "The ADR must reject unauthenticated external release notes."
require_literal "$repository_root/docs/secure-update-operations.md" \
    'An absent high-water record is initialized and persisted' \
    "Operations must define first-launch replay-state initialization."
if /usr/bin/grep -Fq 'allowsEnclosureRedirect' \
    "$repository_root/CopyLassoTests/Update/SecureUpdateArchitectureProofTests.swift"; then
    fail "The G35 proof must not claim an unconnected redirect guard."
fi
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
