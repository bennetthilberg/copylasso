import XCTest

@testable import CopyLasso

@MainActor
final class CaptureCoordinatorTests: XCTestCase {
  func testCompleteLegalTransitionChainReturnsToIdle() {
    let coordinator = CaptureCoordinator()
    let transitions: [(CaptureEvent, CaptureState)] = [
      (.requestCapture, .requestingPermission),
      (.permissionGranted, .selecting),
      (.selectionCompleted, .capturing),
      (.captureCompleted, .recognizing),
      (.recognitionCompleted, .completing),
      (.completionFinished, .idle),
    ]

    for (event, expectedState) in transitions {
      let previousState = coordinator.state
      XCTAssertEqual(
        coordinator.handle(event),
        .transitioned(from: previousState, to: expectedState)
      )
      XCTAssertEqual(coordinator.state, expectedState)
    }
  }

  func testCaptureRequestIsRejectedFromEveryNonIdleState() {
    for state in CaptureState.nonIdleTestCases {
      let coordinator = CaptureCoordinator(initialState: state)

      XCTAssertEqual(
        coordinator.handle(.requestCapture),
        .rejectedBusy(currentState: state)
      )
      XCTAssertEqual(coordinator.state, state)
    }
  }

  func testCancellationFromEveryActiveStateIsTerminalAndNotFailure() {
    for state in CaptureState.activeTestCases {
      for reason in CaptureCancellationReason.allTestCases {
        let coordinator = CaptureCoordinator(initialState: state)

        XCTAssertEqual(
          coordinator.handle(.cancel(reason)),
          .transitioned(from: state, to: .cancelled(reason))
        )
        XCTAssertEqual(coordinator.state, .cancelled(reason))
        XCTAssertEqual(
          coordinator.handle(.cancel(.user)),
          .rejectedInvalidTransition(currentState: .cancelled(reason), event: .cancel(.user))
        )
        XCTAssertEqual(coordinator.state, .cancelled(reason))
      }
    }
  }

  func testFailureFromEveryActiveStateRecordsOnlyTheStage() {
    for state in CaptureState.activeTestCases {
      for stage in CaptureFailureStage.allTestCases {
        let coordinator = CaptureCoordinator(initialState: state)

        XCTAssertEqual(
          coordinator.handle(.fail(stage)),
          .transitioned(from: state, to: .failed(stage))
        )
        XCTAssertEqual(coordinator.state, .failed(stage))
      }
    }
  }

  func testExplicitResetMovesTerminalStatesToIdle() {
    for state in [
      CaptureState.cancelled(.selectionTooSmall),
      CaptureState.failed(.recognition),
    ] {
      let coordinator = CaptureCoordinator(initialState: state)

      XCTAssertEqual(
        coordinator.handle(.reset),
        .transitioned(from: state, to: .idle)
      )
      XCTAssertEqual(coordinator.state, .idle)
    }
  }

  func testEveryUndefinedTransitionIsRejectedWithoutMutation() {
    for state in CaptureState.allTestCases {
      for event in CaptureEvent.allTestCases where !Self.isLegal(event, from: state) {
        let coordinator = CaptureCoordinator(initialState: state)
        let expected: CaptureTransitionResult =
          event == .requestCapture && state != .idle
          ? .rejectedBusy(currentState: state)
          : .rejectedInvalidTransition(currentState: state, event: event)

        XCTAssertEqual(coordinator.handle(event), expected, "State: \(state), event: \(event)")
        XCTAssertEqual(coordinator.state, state, "State: \(state), event: \(event)")
      }
    }
  }

  func testAcceptedEventsCannotMutateStateTwice() {
    let cases: [(CaptureState, CaptureEvent)] = [
      (.idle, .requestCapture),
      (.requestingPermission, .permissionGranted),
      (.selecting, .selectionCompleted),
      (.capturing, .captureCompleted),
      (.recognizing, .recognitionCompleted),
      (.completing, .completionFinished),
      (.selecting, .cancel(.user)),
      (.capturing, .fail(.capture)),
      (.cancelled(.user), .reset),
      (.failed(.internal), .reset),
    ]

    for (state, event) in cases {
      let coordinator = CaptureCoordinator(initialState: state)
      guard case .transitioned = coordinator.handle(event) else {
        return XCTFail("Expected first transition from \(state) with \(event)")
      }
      let stateAfterFirstTransition = coordinator.state

      guard case .transitioned = coordinator.handle(event) else {
        XCTAssertEqual(coordinator.state, stateAfterFirstTransition)
        continue
      }
      XCTFail("Event mutated state twice: \(state), \(event)")
    }
  }

  func testBusyIsFalseOnlyWhileIdle() {
    XCTAssertFalse(CaptureCoordinator().isBusy)

    for state in CaptureState.nonIdleTestCases {
      XCTAssertTrue(CaptureCoordinator(initialState: state).isBusy)
    }
  }

  private static func isLegal(_ event: CaptureEvent, from state: CaptureState) -> Bool {
    switch (state, event) {
    case (.idle, .requestCapture),
      (.requestingPermission, .permissionGranted),
      (.selecting, .selectionCompleted),
      (.capturing, .captureCompleted),
      (.recognizing, .recognitionCompleted),
      (.completing, .completionFinished),
      (.cancelled, .reset),
      (.failed, .reset):
      true
    case (let state, .cancel), (let state, .fail):
      state.isActiveTestCase
    default:
      false
    }
  }
}

extension CaptureState {
  fileprivate static let activeTestCases: [CaptureState] = [
    .requestingPermission,
    .selecting,
    .capturing,
    .recognizing,
    .completing,
  ]

  fileprivate static let nonIdleTestCases: [CaptureState] =
    activeTestCases + [.cancelled(.user), .failed(.internal)]

  fileprivate static let allTestCases: [CaptureState] = [.idle] + nonIdleTestCases

  fileprivate var isActiveTestCase: Bool {
    Self.activeTestCases.contains(self)
  }
}

extension CaptureEvent {
  fileprivate static let allTestCases: [CaptureEvent] = [
    .requestCapture,
    .permissionGranted,
    .selectionCompleted,
    .captureCompleted,
    .recognitionCompleted,
    .completionFinished,
    .cancel(.user),
    .fail(.internal),
    .reset,
  ]
}

extension CaptureCancellationReason {
  fileprivate static let allTestCases: [CaptureCancellationReason] = [
    .user,
    .selectionTooSmall,
    .displayChanged,
    .applicationTerminated,
  ]
}

extension CaptureFailureStage {
  fileprivate static let allTestCases: [CaptureFailureStage] = [
    .permission,
    .selection,
    .capture,
    .recognition,
    .formatting,
    .clipboard,
    .feedback,
    .internal,
  ]
}
