#!/bin/bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && /bin/pwd -P)"
readonly tool_root="$repository_root/Tools/LaTeXFeasibility"
readonly evidence_root="$repository_root/docs/latex-feasibility"
readonly protocol="$evidence_root/protocol.json"
readonly summary="$evidence_root/summary.json"
readonly development_results="$evidence_root/development-results.json"
readonly production_manifest="$evidence_root/g38-production-tree.manifest"
readonly expected_production_digest='f274c68f08d2c87b282b532f0babf7219ff1b725eb25594e81c44dcdac5ea262'
readonly expected_production_commit='ffbd81521855ec0e72bfc8cc6c26476229a76a98'

fail() {
    echo "$1" >&2
    exit 1
}

for required_file in \
    "$tool_root/Package.swift" \
    "$tool_root/Sources/LaTeXFeasibility/main.swift" \
    "$tool_root/Sources/LaTeXFeasibilityCore/Feasibility.swift" \
    "$tool_root/Tests/LaTeXFeasibilityCoreTests/LaTeXFeasibilityCoreTests.swift" \
    "$repository_root/scripts/test-latex-feasibility.sh" \
    "$protocol" \
    "$summary" \
    "$development_results" \
    "$production_manifest" \
    "$evidence_root/candidate-screening.md" \
    "$evidence_root/runtime-screening.md" \
    "$evidence_root/development-comparison.md" \
    "$repository_root/docs/architecture/ADR-005-offline-latex-recognition.md"; do
    [[ -f "$required_file" ]] || fail "Required G39 feasibility file is missing: $required_file"
done

[[ -x "$repository_root/scripts/test-latex-feasibility.sh" ]] || \
    fail "The focused LaTeX feasibility test script must be executable."

/usr/bin/jq -e \
    --arg expected_production_digest "$expected_production_digest" \
    --arg expected_production_commit "$expected_production_commit" '
    .schema_version == 1 and
    .study == "CopyLasso G39 offline LaTeX feasibility" and
    .decision == "no_go" and
    .blind_evaluation.candidate_frozen == false and
    .blind_evaluation.corpus_created_or_unblinded == false and
    .blind_evaluation.status ==
        "not_started_no_candidate_survived_preblind_hard_gates" and
    .physical_reference_hardware.arm64_base_m1_8_gb_macos_14_measured == false and
    .physical_reference_hardware.intel_2018_macbook_air_8_gb_macos_14_measured == false and
    .production_boundary.application_source_changed == false and
    .production_boundary.dependency_or_model_shipped == false and
    .production_boundary.entitlements_changed == false and
    .production_boundary.version_or_build_changed == false and
    .production_boundary.production_tree_commit == $expected_production_commit and
    .production_boundary.production_tree_digest == $expected_production_digest and
    .production_boundary.production_tree_manifest == "g38-production-tree.manifest" and
    ([.candidate_results[].candidate] | sort) == [
        "LaTeX_OCR_rec",
        "MixTex ZhEn-LaTeX-OCR",
        "PP-FormulaNet-S",
        "Texo ONNX FP32"
    ] and
    all(.candidate_results[]; .status == "no_go") and
    .core_ml_evaluation.runtime_status == "preferred_but_not_required" and
    .core_ml_evaluation.conversion_attempted == false and
    .development_comparison.aggregate_record == "development-results.json" and
    .development_comparison.blind_gate_credit == false
    ' "$summary" >/dev/null || fail "The G39 summary does not record the approved no-go."

LC_ALL=C /usr/bin/sort -cu "$production_manifest" || \
    fail "The historical G38 production manifest must be sorted and unique."
if /usr/bin/grep -Ev \
    $'^(100644|100755) [0-9a-f]{40} 0\t(CopyLasso/|CopyLassoTests/|CopyLassoUITests/|CopyLasso\\.xcodeproj/|Configuration/|THIRD_PARTY_NOTICES\\.md$)' \
    "$production_manifest"; then
    fail "The historical G38 production manifest contains an invalid entry."
fi
recorded_production_digest="$(
    /usr/bin/shasum -a 256 "$production_manifest" |
        /usr/bin/awk '{print $1}'
)"
[[ "$recorded_production_digest" == "$expected_production_digest" ]] || \
    fail "The historical G38 production manifest no longer matches its reviewed digest."

/usr/bin/jq -e '
    .schema_version == 1 and
    .blind_evaluation.candidate_limit == 1 and
    .blind_evaluation.corpus.minimum_samples == 300 and
    .blind_evaluation.corpus.minimum_positive_samples == 200 and
    .blind_evaluation.corpus.minimum_negative_samples == 100 and
    .blind_evaluation.corpus.required_positive_classes.clean_common == 100 and
    .blind_evaluation.semantic_corpus_review.before_unblinding == true and
    .blind_evaluation.semantic_corpus_review.independent_reviewer_required == true and
    .blind_evaluation.semantic_corpus_review.class_tags_are_mechanical_claims_not_semantic_proof == true and
    all(
        .blind_evaluation.corpus.required_positive_classes
        | to_entries[]
        | select(.key != "clean_common");
        .value >= 15
    ) and
    .gate_thresholds.accuracy.clean_common_structural_minimum == 0.95 and
    .gate_thresholds.accuracy.overall_positive_exact_minimum == 0.85 and
    .gate_thresholds.accuracy.each_positive_class_exact_minimum == 0.7 and
    .gate_thresholds.accuracy.negative_false_success_maximum == 0.01 and
    .gate_thresholds.latency.arm64_warm_p95_maximum_milliseconds == 2000 and
    .gate_thresholds.latency.intel_warm_p95_maximum_milliseconds == 4000 and
    .gate_thresholds.peak_memory_growth_maximum_bytes == 786432000 and
    .gate_thresholds.installed_growth_maximum_bytes == 209715200 and
    .development_comparison.core_ml_preference == true and
    .development_comparison.non_core_ml_meaningful_win.requires_every_absolute_gate == true and
    .development_comparison.non_core_ml_meaningful_win.accuracy.predefined_difficult_classes == [
        "aligned_equations",
        "degraded",
        "low_resolution",
        "matrices"
    ] and
    .development_comparison.non_core_ml_meaningful_win.accuracy.paired_confidence_method ==
        "normal_approximation_of_paired_binary_differences" and
    .scorer_contract.comparison_reports_bind_candidate_runtime_and_common_corpus_label_scorer_protocol_digests == true and
    .scorer_contract.artifact_manifest_binds_complete_file_and_directory_set == true and
    .scorer_contract.derives_paired_confidence_interval_from_bound_sample_outcomes == true and
    .scorer_contract.recomputes_supplied_artifact_digests == true and
    .scorer_contract.validates_parsed_protocol_against_compiled_thresholds == true and
    .scorer_contract.mechanical_class_counts_require_independent_semantic_review == true and
    .scorer_contract.no_qualified_runtime_is_distinct_from_core_ml_preference == true and
    .scorer_contract.requires_independent_review_of_physical_and_legal_evidence == true and
    .scorer_contract.failed_gate_exit_code == 2
    ' "$protocol" >/dev/null || fail "The G39 protocol no longer matches the approved gates."

/usr/bin/jq -e '
    .schema_version == 1 and
    .study == "CopyLasso G39 public development comparison" and
    .measurement_protocol.blind_gate_credit == false and
    .measurement_protocol.networking_denied == true and
    .host.qualifies_for_blind_gate == false and
    .fixture_binding.positive_count == 100 and
    .fixture_binding.negative_count == 100 and
    .fixture_binding.positive_source_revision ==
        "5de97cfad9a424827e93e07d9d190fe999d038dd" and
    .fixture_binding.positive_image_manifest_sha256 ==
        "6b3feb60faf660a4176092fc28e58985d2d0d372c48707ad008b8671fe2db640" and
    .fixture_binding.negative_manifest_sha256 ==
        "22d3d58935c6ca0634f69c2dc65fc64fdf5b3074083eeab69e9e49610292a62e" and
    ([.candidates[].candidate] | sort) == [
        "LaTeX_OCR_rec",
        "MixTex ZhEn-LaTeX-OCR",
        "PP-FormulaNet-S",
        "Texo ONNX FP32"
    ] and
    ([.candidates[] | select(.status == "measured") | .candidate] | sort) == [
        "MixTex ZhEn-LaTeX-OCR",
        "PP-FormulaNet-S",
        "Texo ONNX FP32"
    ] and
    all(
        .candidates[] | select(.status == "measured");
        .positive.count == 100 and
        .positive.nonempty_count == 100 and
        .negative.count == 100 and
        .negative.false_success_count == 100 and
        (.positive.warm_p50_milliseconds | numbers) and
        (.positive.warm_p95_milliseconds | numbers) and
        .positive.warm_p50_milliseconds >= 0 and
        .positive.warm_p95_milliseconds >= .positive.warm_p50_milliseconds
    ) and
    (.candidates[] | select(.candidate == "Texo ONNX FP32")
        | .positive.normalized_exact_count) == 50 and
    (.candidates[] | select(.candidate == "PP-FormulaNet-S")
        | .positive.normalized_exact_count) == 12 and
    (.candidates[] | select(.candidate == "MixTex ZhEn-LaTeX-OCR")
        | .positive.normalized_exact_count) == 0 and
    (.candidates[] | select(.candidate == "LaTeX_OCR_rec")
        | .status) == "runtime_blocked"
    ' "$development_results" >/dev/null || \
    fail "The content-free G39 development aggregate is incomplete or inconsistent."

/usr/bin/jq -e --slurpfile development "$development_results" '
    ($development[0]) as $development_results |
    all(
        .candidate_results[];
        . as $screened |
        any(
            $development_results.candidates[];
            .candidate == $screened.candidate and
            .model_revision == $screened.model_revision and
            .artifact_bytes ==
                ($screened.model_artifact_bytes // $screened.deployable_model_bytes)
        )
    )
    ' "$summary" >/dev/null || \
    fail "The G39 screening summary and development aggregate describe different artifacts."

readonly core="$tool_root/Sources/LaTeXFeasibilityCore/Feasibility.swift"
readonly command="$tool_root/Sources/LaTeXFeasibility/main.swift"
for required_source in \
    'public var candidate: CandidateDesignFreeze' \
    'validateBinding(' \
    'validateImages(' \
    'ArtifactManifestValidator' \
    'sha256Tree(directoryURL:' \
    'records.append("\(relativePath)/\t-\n")' \
    'artifactPaths(under:' \
    'ArtifactDigest.sha256' \
    'manifest.systemRuntimeIdentifier == "com.apple.CoreML"' \
    '!roles.contains(.runtime)' \
    'case .nonCoreML, .reference:' \
    'string(root, "normalization", "unicode_normalization") == "NFC"' \
    'supportedProtocolCanonicalSHA256' \
    'enclosesWholeExpression' \
    'CFGetTypeID(number) != CFBooleanGetTypeID()' \
    'Int(exactly: numericValue)' \
    'warmP50Milliseconds' \
    'ClassAccuracyMetrics' \
    'RuntimeComparisonEvaluator' \
    'coreMLReport.freeze.candidate.runtimeKind == .coreML' \
    'challengerReport.freeze.candidate.runtimeKind == .nonCoreML' \
    'private static let difficultClassMetrics' \
    'recommendedRuntime: RuntimeRecommendation' \
    'change.improvement >= 0.20' \
    'change.saved >= 100' \
    'otherChange.regression <= 0.10' \
    'interval.improvement >= requiredImprovement' \
    'normalApproximation95' \
    'interval.lower95ConfidenceBound > 0' \
    'candidate.runtimeKind != .reference' \
    'recommendation = .none'; do
    /usr/bin/grep -Fq "$required_source" "$core" || \
        fail "The G39 scorer is missing its reviewed contract: $required_source"
done

for required_command in \
    'case "validate-protocol":' \
    '_NSGetExecutablePath' \
    'CorpusValidator.validateImages' \
    'ProtocolValidator.validateSupported' \
    'ArtifactManifestValidator.validate' \
    'corpusManifestSHA256: ArtifactDigest.sha256(corpusData)' \
    'scorerSHA256: try ArtifactDigest.sha256(fileURL: executableURL)' \
    'protocolSHA256: ArtifactDigest.sha256(protocolData)' \
    'artifactManifestSHA256: ArtifactDigest.sha256(artifactManifestData)' \
    'if !report.passed' \
    'exit(2)'; do
    /usr/bin/grep -Fq "$required_command" "$command" || \
        fail "The G39 CLI is missing its reviewed fail-closed behavior: $required_command"
done

/usr/bin/grep -Fq '"$scratch/debug/latex-feasibility" validate-protocol' \
    "$repository_root/scripts/test-latex-feasibility.sh" || \
    fail "The focused suite must validate the tracked protocol with the production CLI."

if /usr/bin/grep -R -nE \
    'https?://|URLSession|Network\.framework|import[[:space:]]+(CoreML|Vision|AppKit|SwiftUI)' \
    "$tool_root"; then
    fail "The isolated feasibility scorer must have no network, model runtime, or application UI dependency."
fi

if /usr/bin/grep -R -nE \
    'TODO|FIXME|example\.com|/Users[/]|file://' \
    "$tool_root" "$evidence_root" \
    "$repository_root/docs/architecture/ADR-005-offline-latex-recognition.md"; then
    fail "G39 evidence contains a placeholder or local path."
fi

for extension in mlmodel mlmodelc mlpackage onnx pt pth safetensors gguf ckpt framework dylib a; do
    if /usr/bin/find "$tool_root" "$evidence_root" -iname "*.$extension" -print -quit | \
        /usr/bin/grep -q .; then
        fail "G39 must not track model or runtime binary files (*.$extension)."
    fi
done

if /usr/bin/grep -R -nEi \
    'LaTeXFeasibility|latex-feasibility|capture[ _-]?latex|latex[ _-]?recognition|onnxruntime|paddlepaddle|coremltools' \
    "$repository_root/CopyLasso" \
    "$repository_root/CopyLassoTests" \
    "$repository_root/CopyLassoUITests" \
    "$repository_root/CopyLasso.xcodeproj" \
    "$repository_root/Configuration" \
    "$repository_root/THIRD_PARTY_NOTICES.md"; then
    fail "The G39 scorer, model runtimes, and LaTeX capture path must remain outside shipping targets."
fi

if git -C "$repository_root" ls-files | \
    /usr/bin/grep -Ei \
        '\.(mlmodel|mlmodelc|mlpackage|onnx|pt|pth|safetensors|gguf|ckpt|framework|dylib|a)$' \
        >/dev/null; then
    fail "G39 must not track model or runtime binary files anywhere in the repository."
fi

for documentation_contract in \
    "$repository_root/docs/testing.md:## G39 Offline LaTeX Feasibility" \
    "$repository_root/docs/security-and-privacy-review.md:## G39 Offline LaTeX Feasibility Review" \
    "$repository_root/docs/architecture/overview.md:G39 records a no-go for offline LaTeX recognition" \
    "$repository_root/docs/architecture/ADR-005-offline-latex-recognition.md:Do not implement G40" \
    "$repository_root/docs/v0.2-product-contract.md:G39 recommends no-go for offline LaTeX recognition" \
    "$repository_root/docs/v0.2-product-contract.md:A G39 study applies the gates sequentially."; do
    documentation_file="${documentation_contract%%:*}"
    required_text="${documentation_contract#*:}"
    /usr/bin/grep -Fq "$required_text" "$documentation_file" || \
        fail "G39 documentation is missing: $required_text"
done

echo "CopyLasso offline LaTeX feasibility audit passed."
