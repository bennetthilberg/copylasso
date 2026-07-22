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

echo "CopyLasso secure-update architecture contract passed."
