#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly package="$repository_root/Tools/LaTeXFeasibility"
readonly scratch="$repository_root/.build/g39-latex-feasibility-tests"

[[ -f "$package/Package.swift" ]] || {
    echo "The isolated LaTeX feasibility package is missing." >&2
    exit 1
}

CLANG_MODULE_CACHE_PATH="$scratch/clang-module-cache" \
SWIFT_MODULE_CACHE_PATH="$scratch/swift-module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$scratch/swiftpm-module-cache" \
    /usr/bin/xcrun swift test \
    --package-path "$package" \
    --scratch-path "$scratch" \
    --disable-sandbox

"$scratch/debug/latex-feasibility" validate-protocol \
    "$repository_root/docs/latex-feasibility/protocol.json"
