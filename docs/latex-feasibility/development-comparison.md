# G39 LaTeX Development Comparison

**Status:** Final development evidence, July 24, 2026. These measurements screen
technical behavior only. They are not the blind CopyLasso gate, do not qualify
reference hardware, and cannot override a license, size, provenance, platform,
or architecture failure.

## Fixed development set and common boundary

The comparison used the first 100 image/label pairs in Texo's public
`data/dataset/simple` fixture at source revision
`5de97cfad9a424827e93e07d9d190fe999d038dd`. Those images are candidate-owned
development data, so their results are not independent and receive no G39
accuracy-gate credit.

The negative set contained 100 generated 720-by-128 RGB white images. Pillow
12.3.0 used the pinned macOS Arial font bytes to draw the black sentence
`Copy visible text locally sample NNN`. This simple set asks whether a
formula-only recognizer has built-in rejection behavior. It is not a substitute
for the blind negative corpus.

Every measured path:

- processed the identical image files one at a time on CPU after three
  warm-up recognitions;
- used its maintained preprocessing and deterministic greedy generation;
- timed file opening, preprocessing, generation, and decoding with one
  monotonic-clock boundary;
- applied the same NFC, line-ending, complete outer-math-delimiter, and
  Unicode-whitespace normalization after timing;
- ran from local pinned artifacts with outbound networking denied;
- retained no image, expected expression, or decoded output in tracked
  evidence; and
- recorded only counts, aggregate timings, artifact manifests, and process
  high-water memory in
  [the content-free result record](development-results.json).

The fixture record binds the public source revision, positive image/label
prefixes, negative generator, font bytes, and generated negative image
manifest. The disposable adapters had SHA-256
`c9e03ec615e428f68c486b03f72daa6e1fdaf0517b016163beed60be32004ad7`
for Texo,
`0f10725bf6f60e6aa08a36c01e7d1cdf60cb0d9af35a82a85faef63164c2b2f5`
for both Paddle models, and
`e5137536b70c995374e694fff59a9bec16d85775cba5561ce11488f9e81bfa8b`
for MixTex. The adapters and model/runtime environments were removed after
these aggregates were captured; they are not shipping or tracked code.

## Environment

The available host was a `Mac17,9` MacBook Pro with an Apple M5 Pro, 24 GB of
memory, arm64, and macOS 26.5.2 build `25F84`. It is newer and substantially
faster than the required base M1 reference system and does not run macOS 14.
There was no qualifying Intel Mac available. Consequently, all timing and
memory numbers below are diagnostic only.

Texo used ONNX Runtime 1.27.0, Optimum 2.1.0, Optimum ONNX 0.1.0, and
Transformers 4.40.0. MixTex used PyTorch 2.7.0 and Transformers 4.40.0.
Both completed inside a macOS sandbox profile containing `(deny network*)`.
The Paddle paths used native arm64 PaddlePaddle 3.2.2, PaddleOCR 3.3.2,
PaddleX 3.3.13, and `ftfy` 6.3.1. Model-source checks were disabled after the
pinned artifacts were downloaded, and the restricted execution environment
denied outbound networking.

## Results

| Measurement | Texo ONNX FP32 | PP-FormulaNet-S Paddle CPU | MixTex Transformers CPU | LaTeX_OCR_rec Paddle CPU |
| --- | ---: | ---: | ---: | ---: |
| Model revision | `63e04c8` | `0572450` | `37da049` | `563fb02` |
| Required model data | 80,114,829 bytes | 238,397,573 bytes | 172,793,301 bytes | 103,756,168 bytes |
| Load | 494.602 ms | 3,186.203 ms | 1,017.843 ms | Failed after 1,193.579 ms |
| Positive nonempty | 100 / 100 | 100 / 100 | 100 / 100 | Not measured |
| Positive normalized exact | 50 / 100 | 12 / 100 | 0 / 100 | Not measured |
| Positive warm p50 | 64.569 ms | 155.904 ms | 332.241 ms | Not measured |
| Positive warm p95 | 821.892 ms | 606.260 ms | 1,343.060 ms | Not measured |
| Negative false success | 100 / 100 | 100 / 100 | 100 / 100 | Not measured |
| Negative warm p50 | 58.968 ms | 223.355 ms | 181.255 ms | Not measured |
| Negative warm p95 | 882.396 ms | 260.470 ms | 193.078 ms | Not measured |
| Process peak RSS | 672,579,584 bytes | 1,082,097,664 bytes | 922,746,880 bytes | 484,982,784 bytes at failure |
| Observed added peak RSS | Not isolated | 784,334,848 bytes | 655,212,544 bytes | Not applicable |
| Terminal result | License and rejection fail | Size gate fails | Provenance, license surface, and rejection fail | Maintained arm64 initialization fails |

Texo produced 38 more exact matches than PP-FormulaNet-S and 50 more than
MixTex on this candidate-owned distribution. That difference belongs to the
complete model-plus-runtime designs; it is not attributable to ONNX Runtime,
Paddle, PyTorch, or Core ML in isolation. Texo had the lowest positive p50, but
PP-FormulaNet-S had the lowest positive p95. No measured design therefore
established the preregistered non-Core-ML latency rule, and no paired confidence
interval was calculated because every design had already failed an absolute
gate.

All three measured recognizers returned nonempty output for all 100 ordinary
text negatives. A separate math detector might change that behavior, but it
would be a different complete design with additional model/runtime bytes and
its own freeze, licensing, accuracy, memory, latency, and architecture record.

LaTeX_OCR_rec's maintained construction path requested MKL-DNN on arm64 and
raised `ValueError: MKL-DNN is not available`. The experiment did not patch
PaddleX internals, because a patched runtime would likewise be a distinct
candidate.

## Why comparison stopped before conversion

None of the four attempted designs survived the sequential preblind hard gates:

- Texo's compact ONNX form is not license-compatible.
- PP-FormulaNet-S exceeds 200 MiB before any runtime is included.
- MixTex fits as source model data, but its Apache model metadata conflicts
  with linked AGPL reference code and supplies no complete training-data
  provenance. Its reference behavior also missed every positive exact result
  and every negative rejection in this diagnostic set.
- LaTeX_OCR_rec fits as model data, but the maintained runtime fails arm64 and
  the installed Paddle distribution alone exceeds 200 MiB.

The other screened models fail license, provenance, or model-size gates even
earlier. Converting or quantizing a terminally disqualified checkpoint would
create a distinct artifact without repairing its source license/provenance or
supplying the missing physical Intel and base-M1 evidence. Under the approved
sequential rule, G39 therefore preserved the unseen corpus and stopped before
conversion.
