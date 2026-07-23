#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly entitlements="$repository_root/CopyLasso/CopyLasso.entitlements"

cd "$repository_root"

if [[ ! -f "$entitlements" ]]; then
    echo "CopyLasso must declare a tracked, reviewable entitlements file." >&2
    exit 1
fi

entitlements_json="$(/usr/bin/plutil -convert json -o - "$entitlements")"
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
    echo "The product must retain only App Sandbox, outbound updates, and Sparkle installer services." >&2
    exit 1
fi

if [[ "$(/usr/bin/grep -c 'CODE_SIGN_ENTITLEMENTS = CopyLasso/CopyLasso.entitlements;' \
    CopyLasso.xcodeproj/project.pbxproj)" != 2 ]]; then
    echo "Debug and Release must both use the reviewed app entitlements." >&2
    exit 1
fi

if [[ "$(/usr/bin/grep -c 'ENABLE_HARDENED_RUNTIME = YES;' \
    CopyLasso.xcodeproj/project.pbxproj)" != 2 ]]; then
    echo "Debug and Release must both enable Hardened Runtime." >&2
    exit 1
fi

readonly prohibited_network_pattern='URLSession|NSURLSession|URLRequest|NSURLRequest|import[[:space:]]+Network|NWConnection|NWListener|CFNetwork|CFSocket|GCDAsyncSocket|WebKit|WKWebView|socket\('
if /usr/bin/grep -R -nE --include='*.swift' \
    --exclude='SparkleUpdateService.swift' "$prohibited_network_pattern" CopyLasso; then
    echo "Application networking must remain confined to the reviewed Sparkle adapter." >&2
    exit 1
fi
if /usr/bin/grep -nE \
    'URLSession|NSURLSession|import[[:space:]]+Network|NWConnection|NWListener|httpAdditionalHeaders|queryItems' \
    CopyLasso/Services/SparkleUpdateService.swift; then
    echo "The Sparkle adapter must not add a second network stack or request metadata." >&2
    exit 1
fi

readonly prohibited_content_persistence_pattern='CGImageDestination|NSBitmapImageRep|representation\(using:|pngRepresentation|jpegRepresentation|CIContext.*write|Data.*write\(to:|FileManager|NSFileHandle|FileHandle'
if /usr/bin/grep -R -nE "$prohibited_content_persistence_pattern" CopyLasso; then
    echo "The application target must not encode or persist captured content." >&2
    exit 1
fi

logging_files="$({ /usr/bin/grep -R -lE \
    '^[[:space:]]*import[[:space:]]+OSLog|=[[:space:]]*Logger\(' CopyLasso || true; })"
if [[ "$logging_files" != "CopyLasso/Services/CaptureLifecycleLogger.swift" ]] || \
    /usr/bin/grep -F -q '\(' CopyLasso/Services/CaptureLifecycleLogger.swift; then
    echo "Logging must remain confined to fixed, non-interpolated lifecycle messages." >&2
    exit 1
fi

tracked_sensitive_files="$({ git ls-files | /usr/bin/grep -Ei \
    '\.(p12|pfx|cer|crt|der|key|pem|mobileprovision|provisionprofile)$' || true; })"
if [[ -n "$tracked_sensitive_files" ]]; then
    echo "A credential, certificate, key, or provisioning asset is tracked." >&2
    exit 1
fi

readonly high_confidence_secret_pattern='BEGIN .*(PRIVATE KEY)|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|xox[baprs]-[A-Za-z0-9-]{20,}'
if git grep -n -I -E "$high_confidence_secret_pattern" -- \
    . ':(exclude)scripts/audit-privacy-security.sh'; then
    echo "A high-confidence secret marker is present in tracked text." >&2
    exit 1
fi

if git grep -n -I -E '/Users/[^ /]+' -- \
    . ':(exclude)scripts/audit-privacy-security.sh'; then
    echo "A local user path is present in tracked text." >&2
    exit 1
fi

readonly package_resolved='CopyLasso.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'
if [[ "$(/usr/bin/grep -c '"identity"' "$package_resolved")" != 2 ]] || \
    ! /usr/bin/grep -q '"version" : "3.0.1"' "$package_resolved" || \
    ! /usr/bin/grep -q '"revision" : "49c3fc04ea827f816df67843bfcc57286b47ff06"' "$package_resolved" || \
    ! /usr/bin/grep -q '"version" : "2.9.4"' "$package_resolved" || \
    ! /usr/bin/grep -q '"revision" : "b6496a74a087257ef5e6da1c5b29a447a60f5bd7"' "$package_resolved" || \
    ! /usr/bin/grep -q 'KeyboardShortcuts 3.0.1' THIRD_PARTY_NOTICES.md || \
    ! /usr/bin/grep -q 'Sparkle 2.9.4' THIRD_PARTY_NOTICES.md || \
    ! /usr/bin/grep -q 'License: MIT' THIRD_PARTY_NOTICES.md || \
    ! /usr/bin/grep -q 'Justification:' THIRD_PARTY_NOTICES.md || \
    ! /usr/bin/grep -Fq 'Sparkle imports must remain confined to the production adapter and proof test.' \
        scripts/audit-secure-update-architecture.sh; then
    echo "Shipping dependencies must be pinned, scoped, licensed, and justified." >&2
    exit 1
fi

if [[ ! -x scripts/test-offline.sh ]] || \
    ! /usr/bin/grep -F -q '(deny network*)' scripts/test-offline.sh; then
    echo "The complete built unit suite must retain its network-denied runner." >&2
    exit 1
fi

tracked_binary_dependencies="$({ git ls-files CopyLasso | /usr/bin/grep -Ei \
    '\.(framework|dylib|a)$' || true; })"
if [[ -n "$tracked_binary_dependencies" ]]; then
    echo "Unexpected prebuilt dependency binary is tracked in the app target." >&2
    exit 1
fi

echo "CopyLasso privacy and security source audit passed."
