#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly ci_script="$repository_root/scripts/ci.sh"
readonly workflow="$repository_root/.github/workflows/ci.yml"
readonly cleanup_library="$repository_root/scripts/lib/launch-services-cleanup.sh"
readonly cleanup_runner="$repository_root/scripts/run-with-generated-app-cleanup.sh"
readonly ordinary_release_cleanup="$repository_root/scripts/unregister-generated-release.sh"
readonly runtime_smoke="$repository_root/scripts/test-minimum-macos.sh"
readonly shared_scheme="$repository_root/CopyLasso.xcodeproj/xcshareddata/xcschemes/CopyLasso.xcscheme"

fail() {
    echo "$1" >&2
    exit 1
}

[[ -r "$cleanup_library" ]] || fail "Launch Services cleanup library is missing."
[[ -x "$cleanup_runner" ]] || fail "Generated-app cleanup runner is missing."
[[ -x "$ordinary_release_cleanup" ]] || fail "Ordinary Release cleanup is missing."
[[ -x "$runtime_smoke" ]] || fail "Maintained runtime smoke is missing."

/usr/bin/grep -Fq '/Applications/*)' "$cleanup_library" || \
    fail "Generated-product cleanup must explicitly refuse installed applications."
/usr/bin/grep -Fq 'Build/Products/[^/]+/CopyLasso\.app' "$cleanup_library" || \
    fail "Generated-product cleanup must accept only direct Xcode build products."
/usr/bin/grep -Fq 'io.github.bennetthilberg.copylasso' "$cleanup_library" || \
    fail "Generated-product cleanup must validate the production bundle identity."

cleanup_runner_invocations="$({
    /usr/bin/grep -Ec \
        '^[[:space:]]*\./scripts/run-with-generated-app-cleanup\.sh[[:space:]]*\\$' \
        "$ci_script" || true
})"
[[ "$cleanup_runner_invocations" == "1" ]] || \
    fail "Canonical CI must wrap its generated Release build cleanup exactly once."
/usr/bin/grep -Fq 'COPYLASSO_GENERATED_CLEANUP_WRAPPED=1' "$ci_script" || \
    fail "Canonical CI must prevent duplicate scheme cleanup beneath its failure-safe wrapper."
[[ "$(/usr/bin/grep -Fc 'scripts/unregister-generated-release.sh' "$shared_scheme")" == "1" ]] || \
    fail "The shared scheme must clean ordinary Release registrations exactly once."
/usr/bin/grep -Fq '[[ "${ACTION:-build}" != "build" ]]' "$ordinary_release_cleanup" || \
    fail "Ordinary cleanup must preserve protected archive actions."

if /usr/bin/grep -Eq 'runs-on:[[:space:]]*macos-14([[:space:]]|$)' "$workflow"; then
    fail "Canonical hosted runtime smoke must not use the retired macOS 14 image."
fi
/usr/bin/grep -Fq 'runs-on: macos-15' "$workflow" || \
    fail "Canonical hosted runtime smoke must use the maintained macOS 15 image."
/usr/bin/grep -Fq 'COPYLASSO_MINIMUM_OS_MAJOR: "15"' "$workflow" || \
    fail "The maintained runtime smoke must expect its macOS 15 host."
/usr/bin/grep -Fq './scripts/test-minimum-macos.sh' "$workflow" || \
    fail "The maintained hosted smoke must retain deployment-target verification."
/usr/bin/grep -Fq 'for architecture in arm64 x86_64; do' "$runtime_smoke" || \
    fail "The runtime smoke must validate every Universal 2 executable slice."
/usr/bin/grep -Fq 'vtool -arch "$architecture" -show-build' "$runtime_smoke" || \
    fail "The runtime smoke must inspect minimum-version metadata per architecture."

for document in \
    "$repository_root/docs/architecture/build-configuration.md" \
    "$repository_root/docs/coverage-review.md"; do
    /usr/bin/grep -Fq 'macOS 15 arm64' "$document" || \
        fail "Maintained-runtime documentation is stale: ${document#"$repository_root/"}"
    if /usr/bin/grep -Fq 'macOS 14 arm64 runner' "$document"; then
        fail "Retired hosted macOS 14 wording remains: ${document#"$repository_root/"}"
    fi
done

for required_contract in \
    'A macOS 15 hosted smoke does not qualify macOS 14 behavior.' \
    'Real macOS 14 qualification remains a manual release gate.' \
    'freshly recreated disposable local macOS user'; do
    /usr/bin/grep -R -Fq "$required_contract" \
        "$repository_root/docs/v0.1-product-contract.md" \
        "$repository_root/docs/testing.md" \
        "$repository_root/docs/development-environment.md" \
        "$repository_root/docs/clean-install-testing.md" || \
        fail "Platform qualification documentation is missing: $required_contract"
done

echo "CopyLasso platform qualification audit passed."
