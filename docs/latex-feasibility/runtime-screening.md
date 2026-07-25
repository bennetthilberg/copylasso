# G39 LaTeX Runtime Screening

**Status:** Final feasibility evidence. This document narrows the runtime
comparison for G39; it does not approve a production dependency, model
download, or LaTeX feature.

## Decision frame

CopyLasso's shipping target remains macOS 14 or newer and a Universal 2
application containing both `arm64` and `x86_64`. Core ML is the preferred
shipping runtime because it is supplied by macOS and can use the compute
resources available on each Mac without adding a third-party inference runtime
to the application. It is a preference, not a feasibility requirement.

A non-Core-ML design may be recommended when measured end-to-end speed or
accuracy is meaningfully better under the preregistered rule below and the same
design independently clears every accuracy, latency, memory, installed-size,
privacy, licensing, macOS 14, App Sandbox, Developer ID, and Universal 2 gate.
The comparison must separate gains from a model checkpoint from gains caused by
its runtime.

## Runtime shortlist

| Runtime path | macOS 14 and Universal 2 | Autoregressive fit | G39 disposition |
| --- | --- | --- | --- |
| Direct Core ML `mlprogram` | Strong. ML Programs support macOS 12 or newer, and Core ML runs on Intel and Apple silicon. | Viable with a host-controlled decoder. macOS 14 cannot use Core ML state objects, so decoder cache must be explicit input and output or the model must recompute prior tokens. | Preferred shipping baseline. Compare full-precision, half-precision, and only the macOS-14-compatible compression variants needed to test the size gate. |
| Custom ONNX Runtime CPU Execution Provider | Strong. The maintained macOS build supports a 13.3 deployment floor and documents `x86_64`, `arm64`, and combined fat binaries. | Viable with a long-lived session, explicit past/present tensors, and a host-controlled deterministic decoder. | Primary non-Core-ML challenger. Build from a pinned release with only required operators and measure the resulting macOS binary rather than extrapolating another platform's size. |
| ONNX Runtime Core ML Execution Provider | Technically supports macOS and can accept dynamic shapes or selected control-flow subgraphs. | Possible, but execution may split between Core ML and the CPU provider, and a complex graph can add runtime compilation and cache costs. | Conversion and placement diagnostic only. It is not an independent non-Core-ML result and adds ONNX Runtime overhead to Core ML. |
| PyTorch / LibTorch | Current PyTorch does not provide the required maintained matrix: PyTorch 2.2.x was the final macOS x86 release. | The maintained reference implementation is the accuracy and behavior oracle for many candidate models. | Development reference only, not a shipping candidate. |
| ExecuTorch with XNNPACK | Current documentation lists macOS XNNPACK for ARM64, while its x86 and x86-64 targets list Windows, Linux, and Android rather than macOS. | Deployment-oriented export, selective kernels, and cache-aware transformer examples make it technically interesting. | Not qualified for G39's shipping matrix unless the exact pinned release first produces and runs maintained `arm64` and `x86_64` macOS slices. |
| MLX / MLX Swift | Official installation requires Apple silicon. | Strong dynamic transformer support on Apple silicon. | Disqualified by the Intel requirement; it may not support a go recommendation. |

## Core ML baseline

The current Core ML model format can represent an ML Program on CopyLasso's
macOS 14 floor. Core ML Tools converts PyTorch graphs directly, but its stable
and more performant capture path remains `torch.jit.trace`. Tracing does not
preserve data-dependent control flow, while the newer `torch.export` conversion
path is documented as beta with incomplete operator translation. Each candidate
therefore needs a real conversion attempt and reference-output comparison; a
successful conversion command alone is not sufficient evidence.

The baseline should separate the image encoder from a one-token decoder step and
run deterministic token selection in a small host loop. Input shapes should be
fixed or bounded wherever the candidate permits it. Core ML documents better
optimization opportunities for enumerated or bounded shapes than for highly
dynamic shapes.

Core ML's stateful-model API begins with macOS 15. On macOS 14, a decoder that
uses a key/value cache must expose that cache as ordinary input and output
tensors. Recomputing the complete prefix remains a valid measurement variant
but cannot substitute for a cache-aware comparison if it fails the latency
gate. G39 must record cache tensor sizes, copies, allocation behavior, and
per-token latency on both reference architectures.

Core ML Tools produces FP16 ML Programs by default and also permits FP32.
Because small numerical changes can alter an autoregressive token choice, G39
must compare the decoded output and logits of both forms with the maintained
reference implementation. Compression availability and acceleration vary by
OS and compute unit, so only modes supported by macOS 14 may contribute to a
shipping recommendation.

Direct Core ML adds no third-party executable runtime to the application.
However, G39 must count the retained compiled model, caches, and any source model
that remains after compilation. The absence of runtime bytes does not exempt
the model from the installed-size or peak-memory gates.

## ONNX Runtime CPU challenger

ONNX Runtime is a maintained MIT-licensed runtime with C, C++, and Objective-C
interfaces. Its macOS build documentation provides a combined
`x86_64;arm64` build and a deployment floor below CopyLasso's. A shipping spike
must use native C-family integration rather than embedding Python.

The CPU Execution Provider is the portable comparison target. It avoids making
an Apple-silicon-only accelerator part of the feasibility claim and permits the
same graph and host decoder to run on both required architectures. ONNX
Runtime's transformer tooling recognizes past-state transformer graphs and
provides graph optimization and source-runtime comparison utilities. Those
utilities are aids, not proof that an image-to-LaTeX model exports accurately.

The runtime may be built with a model-derived operator list, reduced type
support, and ORT-format models to reduce executable size. G39 must retain normal
error handling: ONNX Runtime documents that disabling exceptions changes error
paths to process termination, which is incompatible with CopyLasso's safe
handling of malformed or corrupt model data. The actual Universal 2 executable,
model, allocator behavior, and memory arena must be measured together.

The ONNX Runtime Core ML Execution Provider may reveal whether runtime graph
partitioning converts a candidate that direct Core ML Tools does not. It does
not establish a non-Core-ML advantage because accepted subgraphs still execute
through Core ML. Dynamic shapes can reduce performance, control-flow subgraphs
require an explicit option, and model caching requires lifecycle management.

The preview ONNX Runtime Generate API is not the baseline. Its published model
types do not establish generic image-to-LaTeX encoder-decoder support, and an
additional generation layer is unnecessary when the selected recognizer can
use a small deterministic host loop.

## Reference-only and rejected runtimes

PyTorch remains useful for loading the maintained checkpoint, freezing
preprocessing and decoding, and producing reference outputs on the development
corpus. It is not a viable maintained Universal 2 dependency because PyTorch
ended macOS x86 support after its 2.2 series. The broad LibTorch surface and
runtime footprint would also require independent proof against the 200 MiB
installed-growth gate.

ExecuTorch is a more deployment-oriented PyTorch path and permits selectively
linked runtimes and backends. Its current platform matrix does not establish a
maintained macOS x86 XNNPACK target, and its Apple GPU backends do not solve the
Intel slice. It should enter the measured matrix only after architecture
readback and physical execution prove both slices for the exact pinned release.

MLX is designed for Apple silicon and its official installation requirements
exclude Intel Macs. Its performance cannot compensate for failing a required
architecture, so it is outside the go/no-go comparison.

## Packaging, sandbox, and signing constraints

Optional installation is compatible with either serious runtime path, but only
model and tokenizer data may be downloaded. A third-party runtime, dynamic
library, helper, or executable must be present when the application is signed
and notarized; G39 must not depend on post-install executable-code delivery.

Apple explicitly supports downloading and compiling Core ML models on a user's
device. A future implementation could verify a pinned source artifact, compile
it asynchronously, atomically retain the compiled model in the application
container, and discard redundant source bytes. G39 records source download
size, transient compilation space, retained compiled size, compilation time,
and removal behavior without implementing that installer.

An ONNX design similarly treats the model as untrusted data consumed by an
already bundled and signed runtime. The spike must use a pinned digest and
length, reject unexpected external-data paths and model versions, constrain
input dimensions and output length, and fail closed on load or inference
errors. A bundled dynamic library or framework must be nested and signed
correctly; static linkage may simplify that surface but is not selected in G39.

Neither shortlisted CPU/Core ML path should require JIT, unsigned executable
memory, disabled library validation, or a new entitlement. The exact signed
artifact must prove that assumption under Hardened Runtime, App Sandbox,
Developer ID validation, notarization, networking-denied execution, and both
architectures. Recognition remains offline after any optional model
installation.

Optional delivery keeps the default application download small, but it does not
relax the product contract. The application plus every runtime and model file
required by a user who enables LaTeX recognition must remain within the
200 MiB installed-growth limit.

## Comparison and meaningful-win rule

Candidate comparison uses a labeled development corpus. For each credible
checkpoint, G39 freezes identical image preprocessing, tokenizer data, maximum
generation length, end-token behavior, deterministic decoding, and output
normalization before comparing runtime variants. It records which differences
come from model availability, numerical precision, quantization, conversion,
operator placement, or the inference runtime itself.

The measured matrix includes, where reproducible:

1. maintained PyTorch FP32 reference output, used only for development;
2. direct Core ML FP32 with explicit decoder cache;
3. direct Core ML FP16 with explicit decoder cache;
4. one macOS-14-compatible compressed Core ML form if needed for the size gate;
5. custom Universal 2 ONNX Runtime CPU FP32 with explicit decoder cache;
6. one ONNX quantized form if needed for size or latency;
7. ONNX Runtime with the Core ML Execution Provider as a placement diagnostic;
8. ExecuTorch only after its architecture precondition is proved.

For each variant, record exact model and runtime identifiers and digests,
conversion parameters, supported and fallback operators, reference-output
agreement, cold load and compilation time, warm end-to-end p50 and p95 latency,
encoder and per-token decoder latency, peak memory above the OCR baseline,
runtime and model bytes, retained compiled/cache bytes, both executable slices,
entitlements, signatures, offline behavior, cancellation, and malformed-input
behavior.

Core ML wins a practical tie. A non-Core-ML design is meaningfully better only
if it satisfies at least one of these preregistered conditions while still
passing every product-contract gate:

- **Latency:** warm end-to-end p95 is both at least 20% and at least 100 ms
  lower on one required architecture, with no more than a 10% p95 regression on
  the other architecture. Both architectures must still pass their absolute
  latency thresholds.
- **Accuracy:** normalized exact match is at least 3 percentage points higher
  overall, or at least 5 percentage points higher in a predefined difficult
  class, and the 95% normal-approximation interval computed from the bound
  paired binary sample outcomes excludes zero. No reported class may fall below
  its absolute accuracy threshold.

Runtime size or maintenance simplicity may break a result that does not cross a
meaningful speed or accuracy threshold, in which case the Core ML preference
controls. A model available only through a non-Core-ML runtime may be compared
as a complete design, but the record must say that the accuracy difference
comes from model availability rather than attributing it to the runtime.

After comparison on development data, G39 selects and freezes at most one
complete model/runtime design, preprocessing, decoder, normalization, and
scoring implementation before inspecting the blind evaluation corpus. The
freeze includes a digest-checked manifest covering retained files and compiled
directories, including a third-party runtime or the explicit system Core ML
identifier. A change after unblinding requires a fresh unseen corpus under the
product contract.

## G39 disposition

No runtime was selected. The maintained reference comparisons found no model
that first survived license, complete installed-size, provenance, arm64, and
Intel requirements. MixTex's standard Swin/RoBERTa encoder-decoder was a
plausible direct-conversion source, but its conflicting license surfaces and
incomplete training-data provenance failed before conversion. A Core ML
conversion would therefore have produced a new artifact from a candidate that
was already unable to receive a go recommendation, while the compact Texo ONNX
reference was license-incompatible.
Neither required physical reference Mac was available. G39 records a no-go and
preserves the blind corpus for a future candidate that can pass these preflight
screens.

## Primary sources

- Apple, [Core ML](https://developer.apple.com/documentation/coreml/)
- Apple, [Core ML on Intel and Apple silicon Macs](https://developer.apple.com/videos/play/wwdc2020/10686/?time=140)
- Apple Core ML Tools,
  [ML Program format and deployment floors](https://apple.github.io/coremltools/docs-guides/source/convert-to-ml-program.html)
- Apple Core ML Tools,
  [PyTorch conversion workflow](https://apple.github.io/coremltools/docs-guides/source/convert-pytorch-workflow.html)
- Apple Core ML Tools,
  [Flexible input shapes](https://apple.github.io/coremltools/docs-guides/source/flexible-inputs.html)
- Apple Core ML Tools,
  [Stateful models and explicit state input/output](https://apple.github.io/coremltools/docs-guides/source/stateful-models.html)
- Apple Core ML Tools,
  [macOS availability of model optimizations](https://apple.github.io/coremltools/docs-guides/source/opt-whats-new.html)
- Apple,
  [Downloading and compiling models to reduce app size](https://developer.apple.com/documentation/coreml/reducing-the-size-of-your-core-ml-app)
- Apple,
  [Hardened Runtime](https://developer.apple.com/documentation/security/hardened-runtime)
- Apple,
  [Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- Microsoft,
  [ONNX Runtime macOS builds](https://onnxruntime.ai/docs/build/inferencing.html)
- Microsoft,
  [ONNX Runtime custom and minimal builds](https://onnxruntime.ai/docs/build/custom.html)
- Microsoft,
  [ONNX Runtime transformer optimization](https://onnxruntime.ai/docs/performance/transformers-optimization.html)
- Microsoft,
  [ONNX Runtime Core ML Execution Provider](https://onnxruntime.ai/docs/execution-providers/CoreML-ExecutionProvider.html)
- Microsoft,
  [ONNX Runtime license](https://github.com/microsoft/onnxruntime/blob/main/LICENSE)
- PyTorch,
  [PyTorch 2.2 and macOS x86 deprecation](https://docs.pytorch.org/blog/pytorch2-2/)
- PyTorch,
  [ExecuTorch XNNPACK target requirements](https://docs.pytorch.org/executorch/stable/ios-xnnpack.html)
- Apple Machine Learning Research,
  [MLX installation requirements](https://ml-explore.github.io/mlx/build/html/install.html)
