#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly audit_script="$repository_root/scripts/audit-secure-update-architecture.sh"
readonly fixture_script="$repository_root/scripts/test-secure-update-signatures.sh"
readonly architecture_decision="$repository_root/docs/architecture/ADR-004-secure-updates.md"
readonly threat_model="$repository_root/docs/secure-update-threat-model.md"
readonly operations="$repository_root/docs/secure-update-operations.md"

fail() {
    echo "$1" >&2
    exit 1
}

for executable in "$audit_script" "$fixture_script"; do
    [[ -x "$executable" ]] || fail "Secure-update proof executable is missing: $(basename "$executable")"
done

for document in "$architecture_decision" "$threat_model" "$operations"; do
    [[ -f "$document" ]] || fail "Secure-update proof document is missing: $(basename "$document")"
done

[[ -f "$repository_root/CopyLassoTests/Update/SecureUpdateArchitectureProofTests.swift" ]] || \
    fail "Secure-update behavior proof tests are missing."

if ! /usr/bin/grep -Fq 'sparkle_package_reference="$(package_reference_block' \
    "$audit_script"; then
    fail "The audit must scope Sparkle's exact requirement to its package-reference block."
fi

ambient_marker_output="$({
    COPYLASSO_SECURE_UPDATE_FIXTURE_INNER=1 \
        COPYLASSO_SPARKLE_TOOLS_DIR=/private/tmp/copylasso-invalid-sparkle-tools \
        "$fixture_script" 2>&1
} || true)"
if [[ "$ambient_marker_output" != *'COPYLASSO_SECURE_UPDATE_FIXTURE_INNER must not be preset.'* ]]; then
    fail "The signature proof must reject an ambient inner-process marker."
fi

echo "CopyLasso secure-update architecture contract passed."
