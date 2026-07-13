import Observation

enum CaptureCancellationReason: Equatable, Sendable {
  case user
  case selectionTooSmall
  case displayChanged
  case systemInterrupted
  case applicationTerminated
}

enum CaptureFailureStage: Equatable, Sendable {
  case permission
  case selection
  case capture
  case recognition
  case formatting
  case clipboard
  case feedback
  case `internal`
}

enum CaptureState: Equatable, Sendable {
  case idle
  case requestingPermission
  case selecting
  case capturing
  case recognizing
  case completing
  case cancelled(CaptureCancellationReason)
  case failed(CaptureFailureStage)

  fileprivate var isActive: Bool {
    switch self {
    case .requestingPermission, .selecting, .capturing, .recognizing, .completing:
      true
    case .idle, .cancelled, .failed:
      false
    }
  }
}

enum CaptureEvent: Equatable, Sendable {
  case requestCapture
  case permissionGranted
  case selectionCompleted
  case captureCompleted
  case recognitionCompleted
  case feedbackBegan
  case completionFinished
  case cancel(CaptureCancellationReason)
  case fail(CaptureFailureStage)
  case reset
}

enum CaptureTransitionResult: Equatable, Sendable {
  case transitioned(from: CaptureState, to: CaptureState)
  case rejectedBusy(currentState: CaptureState)
  case rejectedInvalidTransition(currentState: CaptureState, event: CaptureEvent)
}

@MainActor
@Observable
final class CaptureCoordinator {
  private(set) var state: CaptureState

  var isBusy: Bool {
    state != .idle
  }

  init(initialState: CaptureState = .idle) {
    state = initialState
  }

  @discardableResult
  func handle(_ event: CaptureEvent) -> CaptureTransitionResult {
    let previousState = state

    if event == .requestCapture,
      previousState != .idle,
      previousState != .completing
    {
      return .rejectedBusy(currentState: previousState)
    }

    let nextState: CaptureState
    switch (previousState, event) {
    case (.idle, .requestCapture):
      nextState = .requestingPermission
    case (.completing, .requestCapture):
      nextState = .requestingPermission
    case (.requestingPermission, .permissionGranted):
      nextState = .selecting
    case (.selecting, .selectionCompleted):
      nextState = .capturing
    case (.capturing, .captureCompleted):
      nextState = .recognizing
    case (.recognizing, .recognitionCompleted):
      nextState = .completing
    case (.selecting, .feedbackBegan),
      (.capturing, .feedbackBegan),
      (.recognizing, .feedbackBegan):
      nextState = .completing
    case (.completing, .completionFinished):
      nextState = .idle
    case (let currentState, .cancel(let reason)) where currentState.isActive:
      nextState = .cancelled(reason)
    case (let currentState, .fail(let stage)) where currentState.isActive:
      nextState = .failed(stage)
    case (.cancelled, .reset), (.failed, .reset):
      nextState = .idle
    default:
      return .rejectedInvalidTransition(currentState: previousState, event: event)
    }

    state = nextState
    return .transitioned(from: previousState, to: nextState)
  }
}
