#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly project="$repository_root/CopyLasso.xcodeproj/project.pbxproj"
readonly package_lock="$repository_root/CopyLasso.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
readonly entitlements="$repository_root/CopyLasso/CopyLasso.entitlements"
readonly product_info="$repository_root/Configuration/CopyLasso-Info.plist"
readonly release_metadata="$repository_root/Configuration/ReleaseMetadata.xcconfig"
readonly notices="$repository_root/THIRD_PARTY_NOTICES.md"
readonly update_service="$repository_root/CopyLasso/Services/SparkleUpdateService.swift"
readonly update_session="$repository_root/CopyLasso/Services/SecureUpdateSession.swift"
readonly update_policy="$repository_root/CopyLasso/Models/SecureUpdatePolicy.swift"
readonly sparkle_license="$repository_root/CopyLasso/Resources/Sparkle-2.9.4-LICENSE.txt"

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
    "$repository_root/scripts/test-draft-appcast.sh" \
    "$repository_root/scripts/generate-draft-appcast.sh" \
    "$repository_root/scripts/build-private-update-fixture.sh" \
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
sparkle_pins="$(/usr/bin/jq -c \
    '.pins | map(select(.identity == "sparkle"))' \
    "$package_lock")" || fail "Package.resolved must be valid JSON."
if ! /usr/bin/jq -e '
    length == 1 and
    .[0].kind == "remoteSourceControl" and
    .[0].location == "https://github.com/sparkle-project/Sparkle" and
    .[0].state.revision == "b6496a74a087257ef5e6da1c5b29a447a60f5bd7" and
    .[0].state.version == "2.9.4"
    ' <<< "$sparkle_pins" >/dev/null; then
    fail "Package.resolved must lock the reviewed Sparkle identity, source, revision, and version."
fi

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
if ! /usr/bin/grep -Fq 'Sparkle' <<< "$app_target"; then
    fail "G36 must link the reviewed Sparkle product into CopyLasso."
fi
if ! /usr/bin/grep -Fq 'Sparkle' <<< "$test_target"; then
    fail "G36 must retain Sparkle in CopyLassoTests for the architecture proof."
fi

sparkle_imports="$({
    /usr/bin/grep -R -l --include='*.swift' '^import Sparkle$' \
        "$repository_root/CopyLasso" "$repository_root/CopyLassoTests" || true
})"
expected_sparkle_imports="$(/usr/bin/printf '%s\n%s' \
    "$update_service" \
    "$repository_root/CopyLassoTests/Update/SecureUpdateArchitectureProofTests.swift" | \
    LC_ALL=C /usr/bin/sort)"
if [[ "$(LC_ALL=C /usr/bin/sort <<< "$sparkle_imports")" != "$expected_sparkle_imports" ]]; then
    fail "Sparkle imports must remain confined to the production adapter and proof test."
fi

entitlements_json="$(/usr/bin/plutil -convert json -o - "$entitlements")" || \
    fail "The app entitlements are not a valid plist."
if ! /usr/bin/jq -e '
    (keys | sort) == [
        "com.apple.security.app-sandbox",
        "com.apple.security.network.client",
        "com.apple.security.temporary-exception.mach-lookup.global-name"
    ] and
    .["com.apple.security.app-sandbox"] == true and
    .["com.apple.security.network.client"] == true and
    .["com.apple.security.temporary-exception.mach-lookup.global-name"] == [
        "$(PRODUCT_BUNDLE_IDENTIFIER)-spks",
        "$(PRODUCT_BUNDLE_IDENTIFIER)-spki"
    ]
    ' <<< "$entitlements_json" >/dev/null; then
    fail "G36 must retain only App Sandbox, outbound networking, and Sparkle's two installer services."
fi

info_json="$(/usr/bin/plutil -convert json -o - "$product_info")" || \
    fail "The product Info.plist is invalid."
if ! /usr/bin/jq -e '
    .SUFeedURL == "https://updates.copylasso.com/appcast.xml" and
    .SUPublicEDKey == "oFKqdwUzCRsyJOW3F3UweNIf7S+IvqiJm3MWjJC3zCA=" and
    .SUEnableAutomaticChecks == true and
    .SUScheduledCheckInterval == 86400 and
    .SUAutomaticallyUpdate == false and
    .SUAllowsAutomaticUpdates == false and
    .SUEnableSystemProfiling == false and
    .SUVerifyUpdateBeforeExtraction == true and
    .SURequireSignedFeed == true and
    .SUSignedFeedFailureExpirationInterval == 0 and
    .SUEnableInstallerLauncherService == true and
    .SUEnableDownloaderService == false and
    ([keys[] | select(startswith("SU"))] | length) == 12
    ' <<< "$info_json" >/dev/null; then
    fail "The shipping Sparkle configuration differs from the reviewed fail-closed contract."
fi

for source in "$update_service" "$update_session" "$update_policy"; do
    [[ -f "$source" ]] || fail "A production secure-update source is missing: $(basename "$source")"
done
require_literal "$update_service" 'updater.clearFeedURLFromUserDefaults()' \
    "The production updater must clear legacy user-overridden feed URLs."
require_literal "$update_service" 'shouldDownloadReleaseNotesForUpdate' \
    "The production updater must disable separate release-note downloads."
require_literal "$update_service" 'request.httpShouldHandleCookies = false' \
    "The production updater must disable request cookies."
require_literal "$update_session" 'SecureUpdateDownloadBudget' \
    "The production session must enforce the signed streaming byte budget."
require_literal "$update_policy" 'url.path(percentEncoded: true) == expectedPath' \
    "The production policy must validate the exact percent-encoded enclosure path."
require_literal "$update_policy" '#if COPYLASSO_PRIVATE_UPDATE_FIXTURE' \
    "The private end-to-end origin must remain behind a nonshipping compile condition."
require_literal "$repository_root/CopyLasso/SharedUI/MenuBarLabelView.swift" \
    '#if COPYLASSO_PRIVATE_UPDATE_FIXTURE' \
    "The private end-to-end fixture must expose a visible Computer Use handle."
require_literal "$update_policy" 'url.host == "127.0.0.1"' \
    "The private end-to-end origin must remain loopback-only."
if /usr/bin/grep -R -nE \
    '^[[:space:]]*import[[:space:]]+(Network|WebKit)|URLSession|NWConnection|httpAdditionalHeaders|setValue\(|addValue\(|queryItems' \
    "$repository_root/CopyLasso"; then
    fail "CopyLasso must not add a second network stack, custom headers, or query data."
fi

require_literal "$notices" 'Sparkle 2.9.4' \
    "The shipping Sparkle dependency must be acknowledged."
[[ -f "$sparkle_license" ]] || fail "The complete shipping Sparkle license bundle is missing."
[[ "$(/usr/bin/shasum -a 256 "$sparkle_license" | /usr/bin/awk '{print $1}')" == \
    '389a4e4e9a32f059775b13a06e25a591445ba229d2838d26dd3e7c0c45127cfe' ]] || \
    fail "The shipped Sparkle 2.9.4 license bundle differs from the reviewed source."

for application in \
    "${COPYLASSO_SECURE_UPDATE_DEBUG_APP:-}" \
    "${COPYLASSO_SECURE_UPDATE_RELEASE_APP:-}"; do
    [[ -n "$application" ]] || continue
    [[ -d "$application" ]] || fail "The secure-update app audit requires a built application."
    executable="$application/Contents/MacOS/CopyLasso"
    [[ -x "$executable" ]] || fail "The secure-update app audit cannot find CopyLasso."
    link_binary="$executable"
    if [[ -f "$application/Contents/MacOS/CopyLasso.debug.dylib" ]]; then
        link_binary="$application/Contents/MacOS/CopyLasso.debug.dylib"
    fi
    sparkle_link_targets="$(/usr/bin/otool -L "$link_binary" | \
        /usr/bin/awk '/Sparkle\.framework/{print $1}' | LC_ALL=C /usr/bin/sort -u)"
    if [[ "$sparkle_link_targets" != '@rpath/Sparkle.framework/Versions/B/Sparkle' ]]; then
        fail "The G36 application executable must link exactly one Sparkle framework."
    fi
    [[ -d "$application/Contents/Frameworks/Sparkle.framework" ]] || \
        fail "The G36 application bundle is missing Sparkle.framework."
    [[ -f "$application/Contents/Resources/Sparkle-2.9.4-LICENSE.txt" ]] || \
        fail "The G36 application bundle is missing the complete Sparkle license."
    if /usr/bin/strings "$link_binary" | /usr/bin/grep -Fq '127.0.0.1'; then
        fail "A private update-fixture marker leaked into an ordinary application build."
    fi
    built_info_json="$(/usr/bin/plutil -convert json -o - "$application/Contents/Info.plist")" || \
        fail "The built G36 Info.plist is invalid."
    for key in SUFeedURL SUPublicEDKey SUEnableAutomaticChecks SUScheduledCheckInterval \
        SUAutomaticallyUpdate SUAllowsAutomaticUpdates SUEnableSystemProfiling \
        SUVerifyUpdateBeforeExtraction SURequireSignedFeed \
        SUSignedFeedFailureExpirationInterval SUEnableInstallerLauncherService \
        SUEnableDownloaderService; do
        [[ "$(/usr/bin/jq -c --arg key "$key" '.[$key]' <<< "$built_info_json")" == \
            "$(/usr/bin/jq -c --arg key "$key" '.[$key]' <<< "$info_json")" ]] || \
            fail "The built application changed secure-update setting $key."
    done
done

require_literal "$release_metadata" 'COPYLASSO_RELEASE_VERSION = 0.1.1' \
    "G36 must not change the released version."
require_literal "$release_metadata" 'COPYLASSO_RELEASE_BUILD = 2' \
    "G36 must not change the released build."

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
require_literal "$repository_root/README.md" \
    'The public CopyLasso 0.1.1 download still updates manually.' \
    "README must distinguish the current public artifact from the updater-enabled source."
require_literal "$repository_root/CHANGELOG.md" \
    'A user-controlled secure update path for the planned v0.2 release' \
    "The unreleased changelog must record the G36 update capability."
require_literal "$repository_root/PRIVACY.md" \
    'Update requests send no screen pixels' \
    "Privacy documentation must enumerate the update no-content-egress boundary."
require_literal "$repository_root/docs/security-and-privacy-review.md" \
    'Sparkle | Shipping application and tests' \
    "The dependency inventory must classify Sparkle as shipping."
require_literal "$repository_root/docs/architecture/overview.md" \
    'The update graph is a sibling of the capture graph.' \
    "The architecture overview must isolate updates from capture."
require_literal "$repository_root/docs/release-workflow.md" \
    'never uploaded among the four draft assets' \
    "The release workflow must keep the authenticated appcast private in G36."
require_literal "$repository_root/scripts/build-private-update-fixture.sh" \
    "fixture_bundle_identifier='io.github.bennetthilberg.copylasso.g36fixture'" \
    "The private end-to-end fixture must not reuse the production identity."
require_literal "$repository_root/scripts/build-private-update-fixture.sh" \
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG COPYLASSO_PRIVATE_UPDATE_FIXTURE' \
    "The private loopback policy must remain absent from ordinary builds."
require_literal "$repository_root/scripts/build-private-update-fixture.sh" \
    'account copylasso' \
    "The private fixture must read its signing seed from the dedicated Keychain identity."
require_literal "$repository_root/scripts/build-private-update-fixture.sh" \
    '/usr/bin/cmp -s' \
    "The private fixture must prove its deliberately invalid appcast changed."
require_literal "$repository_root/scripts/build-private-update-fixture.sh" \
    'appcast-rollback.xml' \
    "The private fixture must generate an authenticated downgrade candidate."
if /usr/bin/grep -Fq '/usr/bin/printf' "$repository_root/scripts/generate-draft-appcast.sh" || \
    /usr/bin/grep -Fq 'grep -Fq -- "$private_key"' \
        "$repository_root/scripts/generate-draft-appcast.sh"; then
    fail "The protected private key must not enter a child-process argument."
fi
if /usr/bin/grep -Fq 'private-key-pattern' \
    "$repository_root/scripts/generate-draft-appcast.sh"; then
    fail "The protected private key must not be written to a temporary file."
fi
require_literal "$repository_root/scripts/generate-draft-appcast.sh" \
    '/usr/bin/grep -Fq -f /dev/stdin "$generated_appcast"' \
    "The generated-metadata leak scan must read the private key only from standard input."
require_literal "$repository_root/scripts/generate-draft-appcast.sh" \
    'unset COPYLASSO_SPARKLE_PRIVATE_KEY' \
    "The protected private key must be removed from the child-process environment immediately."
require_literal "$repository_root/.github/workflows/release.yml" \
    'COPYLASSO_SPARKLE_PRIVATE_KEY: ${{ secrets.COPYLASSO_SPARKLE_PRIVATE_KEY }}' \
    "Only the protected workflow may inject the production Sparkle private key."

if /usr/bin/git -C "$repository_root" ls-files | \
    /usr/bin/grep -Eq '(^|/)(appcast[^/]*\.xml|[^/]*\.(pem|p12|key))$'; then
    fail "G36 must not track a public feed or signing-key material."
fi
private_key_marker='BEGIN '
private_key_marker+='(OPENSSH|EC|RSA|PRIVATE) PRIVATE KEY'
if /usr/bin/git -C "$repository_root" grep -nE \
    -- "$private_key_marker|sparkle:edSignature=\"[A-Za-z0-9+/=]{20,}\"" \
    -- ':!docs/**' ':!scripts/test-secure-update-signatures.sh'; then
    fail "G36 must not contain production private-key or signature material."
fi

echo "CopyLasso secure-update integration audit passed."
