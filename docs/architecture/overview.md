# Architecture Overview

CopyLasso currently provides a production-neutral architecture and supporting menu-bar shell, not an end-to-end capture workflow. The application launches as a dockless status item with reopenable Settings and About windows. Feasibility evidence from G05-G07 is retained in the ADRs, while production platform adapters are added incrementally in G12-G17 and connected in G18.

## Components and Dependency Direction

```mermaid
flowchart LR
  App["App and Shared UI"] --> Coordinator["CaptureCoordinator"]
  Coordinator --> Contracts["Service contracts"]
  Coordinator --> Models["Neutral models"]
  Contracts --> Models
  Settings["Settings contracts"] --> Models
  Adapters["Future platform adapters G12-G17"] -. conform .-> Contracts
```

- `App` owns the dockless process, scene lifecycle, menu command routing, and application termination boundary. `SharedUI` contains the menu and auxiliary-window presentation.
- `CaptureWorkflow` owns phase transitions and busy-state policy. It does not call platform APIs in G08.
- `Services` declares narrow permission, selection, capture, OCR, clipboard, and feedback boundaries.
- `Models` contains geometry, observations, authorization observations, and feedback values without AppKit, SwiftUI, ScreenCaptureKit, or Vision dependencies.
- `Settings` currently contains only permission-history state and its persistence contract. It does not implement `UserDefaults` or onboarding.

Dependencies point toward contracts and neutral models. UI and future adapters may depend on them; models and workflow state must never depend on UI or live platform frameworks.

## Future Data Flow

```mermaid
flowchart LR
  Request["Menu or shortcut request"] --> Permission["Permission service"]
  Permission --> Selection["Region selection service"]
  Selection --> Capture["Screen capture service"]
  Capture --> OCR["OCR service"]
  OCR --> Format["Pure text assembly"]
  Format --> Clipboard["Clipboard service"]
  Clipboard --> Feedback["Feedback service"]
  Feedback --> Idle["Idle"]
```

The coordinator models the corresponding phases: idle, requesting permission, selecting, capturing, recognizing, completing, cancelled, and failed. It carries no image or recognized-text payload in observable state. The G09 Capture Text command reaches the same coordinator request boundary reserved for the G11 shortcut, then a no-side-effect stub completes the legal transitions back to idle. G18 will replace that stub with the private transient operation context and real service invocation.

Cancellation is a normal result. It enters an explicit cancelled state and returns to idle only after a reset acknowledging cleanup. Failure records only the responsible stage, never captured content, recognized text, raw platform errors, or user data. A request received outside idle is rejected without changing state.

## Concurrency and Lifetime

- `CaptureCoordinator`, permission, selection, clipboard, and feedback contracts are main-actor isolated because they coordinate application or UI state.
- Capture and OCR contracts are asynchronous and `Sendable`. Their future adapters must not block the main actor.
- The production Vision adapter introduced in G15 will perform user-initiated recognition away from the main actor, following ADR-001.
- Geometry and future text assembly remain pure and independent of AppKit UI objects and Vision framework types.
- Images, recognized observations, assembled text, clipboard text, and feedback previews remain private transient values. They must be released after the active operation and must never be logged, persisted, or placed in observable coordinator state.

## Goal Ownership

| Goal | Responsibility |
| --- | --- |
| G09 | Dockless menu-bar shell and shared Capture Text command |
| G10 | First-run state, real settings content, and Launch at Login |
| G11 | Persistent global shortcut invoking the shared capture command |
| G12 | Production permission service and recovery UI |
| G13 | Production AppKit selection adapter |
| G14 | Production ScreenCaptureKit region capture adapter |
| G15 | Production Vision OCR adapter |
| G16 | Pure observation-to-text assembly |
| G17 | Clipboard and nonactivating feedback adapters |
| G18 | End-to-end service orchestration, cleanup, and integration tests |

Until the owning goal is implemented, its service has only a contract and test double. G08 intentionally introduces no dependency container, live adapter, or hidden workflow.
