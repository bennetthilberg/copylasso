# G39 LaTeX Recognizer Candidate Screening

**Status:** Final feasibility evidence, inspected July 24, 2026. This screen
does not select a model, approve a production dependency, or count upstream
claims as CopyLasso benchmark evidence.

## Screening rules

This first pass applies only facts that can be established before running the
controlled G39 benchmark. A published candidate is screened out when its
required model data alone exceeds the 200 MiB installed-growth limit, or when
its published license is incompatible with CopyLasso's MIT source and direct
Developer ID distribution. An optimized or converted artifact is a different
candidate: it needs a frozen digest, complete provenance, reference-output
comparison, and its own size, memory, latency, architecture, and accuracy
evidence.

The hard shipping gates remain:

- macOS 14 or newer and executable support for both `arm64` and `x86_64`;
- no more than 200 MiB (209,715,200 bytes) of installed growth for the model
  and every required runtime component;
- no more than 750 MiB of added peak memory;
- fully offline execution with no persistence, telemetry, or cloud fallback;
- clear redistributable licenses and provenance for code, weights, tokenizers,
  and dataset-derived artifacts; and
- the preregistered CopyLasso accuracy and latency thresholds on both reference
  Macs.

File sizes below are repository metadata, not estimates from parameter counts.
MiB values use 1,048,576 bytes.

## Candidate disposition

| Candidate | Exact upstream revision | License and provenance | Published payload and maintained runtime | Maintenance and platform constraints | Hard-gate disposition |
| --- | --- | --- | --- | --- | --- |
| PP-FormulaNet-S | [PaddleOCR `2661c7c`](https://github.com/PaddlePaddle/PaddleOCR/tree/2661c7c0ef5c613e8f93c6e93b2e052399f0f854), committed July 22, 2026; [model `0572450`](https://huggingface.co/PaddlePaddle/PP-FormulaNet-S/tree/0572450e501be9eb1b1cdb7e00fccf4b22fab4df), last modified July 22, 2025 | [Code](https://github.com/PaddlePaddle/PaddleOCR/blob/2661c7c0ef5c613e8f93c6e93b2e052399f0f854/LICENSE) and model metadata are Apache-2.0. The pinned documentation does not provide a complete source-by-source license inventory for the training corpus, so dataset provenance remains unresolved. | The primary `inference.pdiparams` is 231,675,001 bytes (220.94 MiB); the model repository totals 238,397,573 bytes (227.35 MiB). The reference path uses PaddleOCR and PaddlePaddle. | PaddleOCR is active and released v3.7.0 on June 11, 2026. Current PaddlePaddle pages give conflicting binary support statements: the [general guide](https://www.paddlepaddle.org.cn/documentation/docs/en/install/index_en.html) says arm64 is unsupported, while the [macOS pip guide](https://www.paddlepaddle.org.cn/documentation/docs/en/install/pip/macos-pip.html) describes arm64 and says x86_64 is no longer supported. The [source-build guide](https://www.paddlepaddle.org.cn/documentation/docs/en/install/compile/macos-compile-make_en.html) treats Intel and Apple silicon as separate CPU builds. None establishes a maintained Universal 2 application runtime. | **Screen out as published:** the weight file alone exceeds 200 MiB. License provenance, Universal 2 integration, peak memory, and CopyLasso-corpus results also remain unproved. |
| PP-FormulaNet_plus-S | Same [PaddleOCR revision](https://github.com/PaddlePaddle/PaddleOCR/tree/2661c7c0ef5c613e8f93c6e93b2e052399f0f854); [model `3d46f55`](https://huggingface.co/PaddlePaddle/PP-FormulaNet_plus-S/tree/3d46f557e3a1752f4bf81202395af3b5ecfadfd2), last modified July 22, 2025 | Code and model metadata are Apache-2.0. The [pinned model documentation](https://github.com/PaddlePaddle/PaddleOCR/blob/2661c7c0ef5c613e8f93c6e93b2e052399f0f854/docs/version3.x/module_usage/formula_recognition.en.md) names broad source classes, including dissertations, books, exams, and journals, but does not provide a complete license inventory. | `inference.pdiparams` is 256,845,006 bytes (244.95 MiB); the repository totals 263,570,334 bytes (251.36 MiB). It uses the same PaddleOCR/PaddlePaddle path. | Same active project and unresolved Universal 2 runtime matrix as PP-FormulaNet-S. | **Screen out as published:** the weight file alone exceeds 200 MiB. Provenance, architecture, memory, and CopyLasso benchmark gates remain unproved. |
| LaTeX_OCR_rec | Same [PaddleOCR revision](https://github.com/PaddlePaddle/PaddleOCR/tree/2661c7c0ef5c613e8f93c6e93b2e052399f0f854); [model `563fb02`](https://huggingface.co/PaddlePaddle/LaTeX_OCR_rec/tree/563fb029dfdf5fc847d0677f3870039960e3a801), last modified July 22, 2025 | Code and model metadata are Apache-2.0. The model card does not provide a complete source-by-source license inventory for the training corpus, so dataset provenance remains unresolved. | `inference.pdiparams` is 102,384,761 bytes (97.64 MiB); the model repository totals 103,756,168 bytes (98.95 MiB). The maintained PaddlePaddle 3.2.2 distribution installed for the reference attempt contains 399,923,873 bytes before this model or Python support. | The maintained PaddleX CPU construction path enables MKL-DNN and fails on arm64 macOS with `MKL-DNN is not available`. No third-party runtime source was patched, because that would create a distinct candidate. | **Screen out as maintained:** the reference path cannot initialize on a required architecture, and its runtime alone exceeds the complete installed-growth limit. Provenance, Universal 2, memory, accuracy, and physical performance remain unproved. |
| UniMERNet-tiny | [UniMERNet `5a2c80d`](https://github.com/opendatalab/UniMERNet/tree/5a2c80d96b1d2dba447ff18d873e5fb73ba03c35), committed September 28, 2025; [model `3f09ac4`](https://huggingface.co/wanderkid/unimernet_tiny/tree/3f09ac4b1cd583be47ea20a7d7daef839473028a), last modified September 2, 2024 | [Code](https://github.com/opendatalab/UniMERNet/blob/5a2c80d96b1d2dba447ff18d873e5fb73ba03c35/LICENSE), model metadata, and the [published UniMER dataset](https://huggingface.co/datasets/wanderkid/UniMER_Dataset) are Apache-2.0. The checkpoint is a PyTorch pickle file and therefore requires isolated, digest-pinned handling during research. | `unimernet_tiny.pth` is 430,075,701 bytes (410.15 MiB); the model repository totals 432,228,313 bytes (412.21 MiB). The [reference manifest](https://github.com/opendatalab/UniMERNet/blob/5a2c80d96b1d2dba447ff18d873e5fb73ba03c35/pyproject.toml) requires Python 3.10+, PyTorch 2.2.2, torchvision 0.17.2+, Transformers 4.42.4, OpenCV, timm, and additional packages. | The repository is not archived; its latest inspected commit is from September 2025 and release 0.2.3 is from December 2024. Upstream supplies no native macOS, Core ML, or Universal 2 integration. PyTorch 2.2 is the final macOS x86 release line, making the pinned reference useful for research but not a maintained shipping runtime. | **Screen out as published:** the checkpoint is more than twice the installed-growth limit. |
| pix2tex / LaTeX-OCR | [Source `5c1ac92`](https://github.com/lukas-blecher/LaTeX-OCR/tree/5c1ac929bd19a7ecf86d5fb8d94771c8969fcb80), committed January 18, 2025; weights from [release `v0.0.1`](https://github.com/lukas-blecher/LaTeX-OCR/releases/tag/v0.0.1) | [Source code](https://github.com/lukas-blecher/LaTeX-OCR/blob/5c1ac929bd19a7ecf86d5fb8d94771c8969fcb80/LICENSE) is MIT. The weight release explicitly applies CC BY-NC-SA 4.0 because the model was trained on arXiv data. | `weights.pth` is 102,113,875 bytes and optional `image_resizer.pth` is 19,441,973 bytes, totaling 121,555,848 bytes (115.92 MiB). The [reference package](https://github.com/lukas-blecher/LaTeX-OCR/blob/5c1ac929bd19a7ecf86d5fb8d94771c8969fcb80/setup.py) uses Python, PyTorch, Transformers, tokenizers, OpenCV, timm, x-transformers, and other packages. | The latest inspected source commit is from January 2025; the published weights date to 2021. Upstream supplies no native macOS, Core ML, or Universal 2 runtime. | **Screen out:** the noncommercial, share-alike weight license does not satisfy the approved redistribution gate. The model bytes fitting under 200 MiB does not cure that failure or establish runtime size, memory, or architecture support. |
| MixTex ZhEn-LaTeX-OCR | [Model `37da049`](https://huggingface.co/MixTex/ZhEn-Latex-OCR/tree/37da0497956ac97f0a81f4da001f000d5295b77c), last modified July 30, 2024; linked [reference source `845d0d7`](https://github.com/RQLuo/MixTeX-Latex-OCR/tree/845d0d75b5f55185ee088cf68dc57d5eb3d0f10b), committed April 24, 2025 | The model card declares Apache-2.0 metadata but contains no license file and says only that a portion of its largely synthetic training data and collection methods may be released later. The linked reference source is AGPL-3.0. That conflict and the absent source-by-source training-data record leave the weight and dataset provenance insufficient for the approved redistribution gate. | The required model, tokenizer, processor, and configuration files total 172,793,301 bytes (164.79 MiB); `model.safetensors` is 172,074,974 bytes with SHA-256 `cb737c91081caf47666e4d64c1e62d715c8c63727c1c7a6b4204214c8a7e930c`. The unrelated 249,242,181-byte Windows bundle is not counted. The reference is an 85.9M-parameter Swin encoder plus four-layer RoBERTa decoder through Transformers and PyTorch. | The model has not changed since 2024, the reference project targets Windows CPU inference, and no native macOS or Universal 2 integration is published. A standard graph makes Core ML or ONNX research plausible, but the retained compiled model/runtime bytes and Intel path are unproved. | **Screen out before conversion:** provenance and conflicting license surfaces fail the preblind gate. The model bytes leave only 35.21 MiB for any compiled-size growth and required non-system data. Its bounded reference run is retained only as diagnostic comparison evidence. |
| SmolVLM-LaTeX 256M | [Model `cceb214`](https://huggingface.co/Teen-Different/smolvlm-256m-latex/tree/cceb214f8dadbf9d4f4f7a2f1c8d2e02b39b2150), last modified January 9, 2026 | Model metadata declares Apache-2.0 and identifies the FineVision dataset and SmolVLM-256M-Instruct base. The card describes an in-progress experimental fine-tune and does not publish a CopyLasso-comparable evaluation. | `model.safetensors` is 513,028,808 bytes (489.26 MiB); the complete repository is 517,892,990 bytes (493.90 MiB). Its maintained example uses Transformers and PyTorch with a conversational image prompt. | The card says training is still in progress and its usage “might not work properly.” No native macOS, Core ML, or Universal 2 integration is supplied. | **Screen out as published:** the model alone is more than twice the complete installed-growth limit. |
| Texo | [Source `5de97cf`](https://github.com/alephpi/Texo/tree/5de97cfad9a424827e93e07d9d190fe999d038dd), committed July 10, 2026; [model `63e04c8`](https://huggingface.co/alephpi/FormulaNet/tree/63e04c86fc96c2324811114351eeea8118bf6b28), last modified January 20, 2026 | Source and model metadata are AGPL-3.0. The [upstream authorization](https://github.com/alephpi/Texo/blob/5de97cfad9a424827e93e07d9d190fe999d038dd/README.md#license) grants a different license only to one named application; it does not grant CopyLasso an exception. The model is distilled from PP-FormulaNet-S and fine-tuned on UniMER-1M. | The single `model.safetensors` is 80,238,928 bytes (76.52 MiB). The supplied ONNX encoder plus merged decoder total 80,114,829 bytes (76.40 MiB); the 898,532,850-byte repository also contains alternate checkpoints and exports that would not all be required together. The [manifest](https://github.com/alephpi/Texo/blob/5de97cfad9a424827e93e07d9d190fe999d038dd/pyproject.toml) requires Python 3.11+, PyTorch 2.7, Transformers, and ONNX Runtime tooling. | Active as of July 2026. A browser demo exists, but upstream does not provide a native, signed Universal 2 macOS integration. | **Screen out:** AGPL-3.0 does not satisfy the approved MIT distribution contract. Published payload size is not the blocking gate, and no inference is made about unmeasured memory or latency. |
| TexTeller | [Source `9b88cec`](https://github.com/OleehyO/TexTeller/tree/9b88cec77bda735aa16f9fc7e4ccb4eb1500a8b2), committed August 22, 2025; [model `7b96df0`](https://huggingface.co/OleehyO/TexTeller/tree/7b96df06b9d81cdb129c3bef68b7250bc3e2b0ea), last modified June 22, 2024 | [Code](https://github.com/OleehyO/TexTeller/blob/9b88cec77bda735aa16f9fc7e4ccb4eb1500a8b2/LICENSE) and model metadata are Apache-2.0. The model card points to `OleehyO/latex-formulas`, whose current metadata is OpenRAIL, while the current project says the model was trained on 80 million pairs without publishing a complete source-and-license inventory. Training provenance therefore remains unresolved. | One `model.safetensors` is 1,192,464,688 bytes (1,137.22 MiB). The ONNX encoder plus merged decoder total 1,252,740,783 bytes (1,194.71 MiB); the repository totals 5,381,444,856 bytes because it contains several full formats. The [manifest](https://github.com/OleehyO/TexTeller/blob/9b88cec77bda735aa16f9fc7e4ccb4eb1500a8b2/pyproject.toml) requires Python 3.10+, PyTorch 2.6+, Transformers 4.47, ONNX Runtime tooling, OpenCV, and additional server/UI dependencies. | Source activity continued through August 2025; package 1.0.2 was published in April 2025, but the model revision is from 2024. PyTorch 2.6 does not provide the required maintained Intel macOS path, and upstream supplies no native Universal 2 integration. | **Screen out as published:** every complete model form exceeds 200 MiB by a wide margin. Dataset provenance, architecture, memory, and CopyLasso benchmark gates also remain unproved. |
| Surya OCR 2 | [Source `f2c45da`](https://github.com/datalab-to/surya/tree/f2c45daaf67be28dfe09c602eb62a0df99a022a8), committed July 23, 2026; [model `6a3a4c3`](https://huggingface.co/datalab-to/surya-ocr-2-gguf/tree/6a3a4c30e5e74446d4f8b6afd05b2f2da970f470), last modified May 27, 2026 | [Code](https://github.com/datalab-to/surya/blob/f2c45daaf67be28dfe09c602eb62a0df99a022a8/LICENSE) is Apache-2.0. The [model license](https://huggingface.co/datalab-to/surya-ocr-2-gguf/blob/6a3a4c30e5e74446d4f8b6afd05b2f2da970f470/LICENSE) is a modified OpenRAIL license with revenue/funding and competitive-use restrictions, and states that training data is not licensed under it. | `surya-2.gguf` is 1,266,400,864 bytes and the required multimodal projector is 204,986,688 bytes, totaling 1,471,387,552 bytes (1,403.22 MiB). The maintained paths use vLLM for NVIDIA GPUs or llama.cpp for CPU and Apple silicon. | Active; the latest inspected release is v0.22.1 from July 20, 2026. Upstream mentions Apple silicon but does not establish the required Intel macOS application path or a Universal 2 integration. Its output is full-page structured OCR with math embedded in HTML, not a dedicated crop-to-LaTeX contract. | **Screen out:** both the model license and required payload fail hard gates. |

## Published metrics are context, not gate evidence

The candidates publish results against different datasets, normalizers,
languages, image classes, hardware, and output contracts:

- [PaddleOCR's pinned table](https://github.com/PaddlePaddle/PaddleOCR/blob/2661c7c0ef5c613e8f93c6e93b2e052399f0f854/docs/version3.x/module_usage/formula_recognition.en.md)
  reports English BLEU of 87.00 for PP-FormulaNet-S and 88.71 for
  PP-FormulaNet_plus-S. Its reported CPU times are model-only measurements on
  PaddleOCR's environment and exclude preprocessing and postprocessing.
- [UniMERNet](https://github.com/opendatalab/UniMERNet/blob/5a2c80d96b1d2dba447ff18d873e5fb73ba03c35/README.md)
  reports BLEU and CDM over UniMER-Test's simple print, complex print, screen
  capture, and handwritten categories.
- [pix2tex](https://github.com/lukas-blecher/LaTeX-OCR/blob/5c1ac929bd19a7ecf86d5fb8d94771c8969fcb80/README.md)
  reports BLEU, normalized edit distance, and token accuracy on its formula
  evaluation data.
- [MixTex](https://huggingface.co/MixTex/ZhEn-Latex-OCR/tree/37da0497956ac97f0a81f4da001f000d5295b77c)
  publishes two examples and qualitative guidance, but no numeric model result
  comparable with CopyLasso's exact, structural, or rejection gates.
- [SmolVLM-LaTeX](https://huggingface.co/Teen-Different/smolvlm-256m-latex/tree/cceb214f8dadbf9d4f4f7a2f1c8d2e02b39b2150)
  calls itself an in-progress experimental fine-tune and publishes no
  CopyLasso-comparable evaluation.
- [Texo](https://github.com/alephpi/Texo/blob/5de97cfad9a424827e93e07d9d190fe999d038dd/README.md#performance)
  reports UniMER-Test BLEU and edit distance, and explicitly notes that results
  using its custom tokenizer are not directly comparable with results using the
  inherited tokenizer.
- [TexTeller](https://github.com/OleehyO/TexTeller/blob/9b88cec77bda735aa16f9fc7e4ccb4eb1500a8b2/README.md)
  makes qualitative coverage claims and publishes examples, but the inspected
  project documentation does not provide a numeric result that matches
  CopyLasso's accuracy definition.
- [Surya OCR 2](https://huggingface.co/datalab-to/surya-ocr-2-gguf/blob/6a3a4c30e5e74446d4f8b6afd05b2f2da970f470/README.md)
  reports full-document OCR benchmarks rather than normalized exact match for
  selected mathematical expressions.

None of those results counts toward G39's accuracy, false-success, latency,
memory, installed-size, offline, or architecture gates. Only the frozen
CopyLasso design measured on the preregistered corpus and reference Macs can
supply that evidence.

## Screening boundary

This document records only published-form screening. It does not conclude
whether a separately converted, compressed, or retrained artifact could pass
G39, and it does not authorize inspecting the blind corpus, adding a production
runtime, downloading a model into the application, or implementing Capture
LaTeX.
