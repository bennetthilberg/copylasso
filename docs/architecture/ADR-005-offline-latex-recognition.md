# ADR-005: Offline LaTeX Recognition Is Deferred

- **Status:** No-go recorded by G39
- **Date:** July 24, 2026
- **Scope:** Non-production feasibility study only

## Context

The v0.2 product contract permits a LaTeX capture feature only after one
reproducible design clears every approved accuracy, false-success, latency,
memory, installed-size, privacy, license, macOS 14, physical-hardware, App
Sandbox, and Universal 2 gate. G39 is not authorization to ship a recognizer or
to narrow those gates.

Core ML is preferred because it is part of macOS and adds no third-party
inference runtime. The preference is not a requirement: a non-Core-ML design
may be selected when it provides the preregistered meaningful accuracy or
latency improvement and independently clears every absolute gate.

The study screened ten current model families, compared four maintained
reference paths on public development data, and evaluated direct Core ML and
custom Universal 2 ONNX Runtime deployment architectures. The detailed
evidence is in:

- [candidate screening](../latex-feasibility/candidate-screening.md);
- [runtime screening](../latex-feasibility/runtime-screening.md);
- [development comparison](../latex-feasibility/development-comparison.md);
- the fixed [protocol](../latex-feasibility/protocol.json); and
- the machine-readable [summary](../latex-feasibility/summary.json).

## Options considered

| Design | Strength | Terminal issue |
| --- | --- | --- |
| Direct Core ML ML Program | Native macOS runtime, Intel and Apple silicon support, no bundled executable dependency | MixTex supplied a structurally plausible compact conversion source, but its conflicting license surfaces and incomplete training-data provenance failed before conversion; macOS 14 also requires explicit decoder-state input/output |
| Custom Universal 2 ONNX Runtime CPU | Maintained MIT runtime, explicit cache tensors, selective operator builds, both required architectures | The one compact tested model is AGPL; the permissive models exceed the installed-size gate or lack a working maintained reference path |
| PaddlePaddle/PaddleOCR reference | Current upstream implementation for PP-FormulaNet models | The installed runtime is larger than the entire feature budget, PP-FormulaNet-S model data already exceeds 200 MiB, and LaTeX_OCR_rec cannot initialize on arm64 |
| PyTorch reference | Maintained behavior oracle for several models | Current macOS x86 support ended after PyTorch 2.2; it is not a maintained Universal 2 shipping runtime |
| MLX or ExecuTorch | Attractive deployment runtimes on Apple silicon | Current support does not establish the required maintained Intel macOS path |
| Optional model download | Keeps the default app and DMG small | It does not relax the 200 MiB installed-growth gate and cannot download executable runtime code after signing |

## Decision

Do not implement G40 and do not ship LaTeX recognition in the planned v0.2
release.

No candidate survived the preblind hard gates:

- PP-FormulaNet-S and every larger permissive candidate exceed the 200 MiB
  installed-growth limit before a shipping runtime is included.
- LaTeX_OCR_rec is smaller, but its maintained Paddle path fails during arm64
  construction and the Paddle distribution alone exceeds the feature budget.
- MixTex fits as source model data and has a conventional Swin/RoBERTa
  encoder-decoder shape, but its model metadata, linked AGPL reference source,
  and unreleased training-data record do not establish reproducible,
  compatible provenance. Its diagnostic reference run also returned output for
  every negative and matched none of the candidate-owned positive labels.
- Texo is compact and had the lowest positive p50 on the development host, but
  AGPL-3.0 is not compatible with CopyLasso's approved MIT distribution
  contract. It also returned a formula for every ordinary-text negative.
- pix2tex weights and Surya's model license are not compatible with the
  approved redistribution boundary.
- No candidate has qualifying physical results on both a base M1 8 GB Mac and
  a 2018 Intel MacBook Air, or demonstrably slower supported systems running a
  pinned macOS 14 maintenance release.

The blind 300-sample corpus was not created, inspected, or unsealed. Spending an
unseen corpus on a design that already cannot receive a go recommendation
would provide no decision value and would consume the corpus's blindness. The
tracked scorer validates the approved thresholds and future freeze mechanics,
but a mathematically passing report never substitutes for independent review
of licenses, artifact bytes, executable slices, sandbox behavior, or physical
hardware.

## Security and privacy findings

A future proposal must address these boundaries before unblinding:

- **Model provenance:** weights, tokenizer, preprocessing, and dataset-derived
  artifacts need compatible licenses, immutable revisions, byte lengths, and
  SHA-256 digests. A permissive source-code license does not establish a
  checkpoint's redistribution rights.
- **Unsafe formats:** Python pickle checkpoints are research inputs only. A
  shipping path must use a non-executable model format and convert in an
  isolated, digest-pinned environment.
- **Model loading:** ONNX external-data paths, malformed graphs, Core ML
  compilation caches, and unexpected model versions must fail closed without
  path traversal, unsigned executable loading, or user-content persistence.
- **Resource exhaustion:** constrain source image dimensions, retained tensor
  sizes, token count, decoder iterations, cancellation, memory arenas, and
  compilation disk use before processing untrusted screen pixels.
- **Output handling:** generated LaTeX is untrusted inert clipboard text. It
  must never be rendered, compiled, executed, opened, logged, uploaded, or
  interpreted as an action.
- **Networking:** package managers, model hubs, and even preprocessing
  libraries may perform version checks. Production recognition must work with
  networking denied and contain no telemetry, analytics, or cloud fallback.
- **Optional delivery:** only authenticated model/tokenizer data may be
  downloaded. Any runtime framework, dynamic library, helper, or executable
  must be present when the app is signed and notarized.
- **Architecture and sandboxing:** the exact shipping runtime must have
  `arm64` and `x86_64` executable support, require no JIT or unsigned executable
  memory, and add no entitlement beyond the separately reviewed product
  contract.

## Reconsideration gate

Reopen the decision only when a maintained candidate first demonstrates all of
the following without changing the current product contract:

1. compatible model, data, tokenizer, and runtime licenses with reproducible
   provenance;
2. complete installed growth at or below 209,715,200 bytes;
3. a maintained native path for macOS 14 on both Intel and Apple silicon;
4. offline, sandbox-compatible inference with bounded input, output, memory,
   and cancellation behavior; and
5. access to both required physical performance systems before the unseen
   corpus is unsealed.

At that point, compare direct Core ML and the best credible non-Core-ML path
using the fixed meaningful-win rule. Select exactly one design, commit the
freeze, scorer, parsed protocol, and complete file/directory artifact-manifest
digests, and only then run a fresh blind evaluation. Runtime comparison derives
paired accuracy intervals from the two candidates' bound per-sample outcomes;
it does not accept caller-supplied confidence bounds. The parsed protocol must
exactly match the scorer's complete semantic contract, including physical,
privacy, platform, comparison, and normalization behavior. Normalization strips
an outer delimiter only when its first unescaped closing delimiter ends the
whole expression. Artifact-tree digests include directory entries, including
empty directories. A Core ML freeze must name Apple's system runtime and
contain no bundled runtime role, while reference-only runtimes remain
ineligible for blind gate scoring.

## Consequences

G39 adds no application source, shipping dependency, entitlement, model,
resource, version, or build change. The benchmark package remains an isolated
development scorer. Large artifacts and runtime experiments stay outside Git
and are removed after evidence capture. Issue #49 remains open as a deferred
enhancement rather than being closed as implemented. The reviewed G38
production boundary is retained as an immutable manifest and digest; canonical
CI validates that historical record without requiring future product commits to
reproduce the old tree.
