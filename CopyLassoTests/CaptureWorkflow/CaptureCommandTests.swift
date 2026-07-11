import XCTest

@testable import CopyLasso

@MainActor
final class CaptureCommandTests: XCTestCase {
  func testAcceptedRequestWaitsForScheduledStubCompletion() async {
    let coordinator = CaptureCoordinator()
    let scheduler = ManualCaptureCompletionScheduler()
    let command = makeTestCaptureCommand(
      coordinator: coordinator,
      scheduleWork: scheduler.schedule
    )

    XCTAssertTrue(command.isEnabled)
    XCTAssertEqual(
      command.perform(),
      .transitioned(from: .idle, to: .requestingPermission)
    )
    XCTAssertEqual(coordinator.state, .requestingPermission)
    XCTAssertFalse(command.isEnabled)
    XCTAssertEqual(scheduler.scheduledCompletionCount, 1)

    await scheduler.runNext()

    XCTAssertEqual(coordinator.state, .idle)
    XCTAssertTrue(command.isEnabled)
  }

  func testConcurrentRequestIsRejectedWithoutSchedulingAnotherCompletion() {
    let coordinator = CaptureCoordinator()
    let scheduler = ManualCaptureCompletionScheduler()
    let command = makeTestCaptureCommand(
      coordinator: coordinator,
      scheduleWork: scheduler.schedule
    )

    XCTAssertEqual(
      command.perform(),
      .transitioned(from: .idle, to: .requestingPermission)
    )
    XCTAssertEqual(
      command.perform(),
      .rejectedBusy(currentState: .requestingPermission)
    )
    XCTAssertEqual(coordinator.state, .requestingPermission)
    XCTAssertEqual(scheduler.scheduledCompletionCount, 1)
  }

  func testEveryNonIdleStateIsDisabledAndRejectedWithoutMutation() {
    for state in CaptureState.nonIdleCaptureCommandTestCases {
      let coordinator = CaptureCoordinator(initialState: state)
      let scheduler = ManualCaptureCompletionScheduler()
      let command = makeTestCaptureCommand(
        coordinator: coordinator,
        scheduleWork: scheduler.schedule
      )

      XCTAssertFalse(command.isEnabled)
      XCTAssertEqual(command.perform(), .rejectedBusy(currentState: state))
      XCTAssertEqual(coordinator.state, state)
      XCTAssertEqual(scheduler.scheduledCompletionCount, 0)
    }
  }

  func testCaptureCommandCanCompleteThreeSequentialRequests() async {
    let coordinator = CaptureCoordinator()
    let scheduler = ManualCaptureCompletionScheduler()
    let command = makeTestCaptureCommand(
      coordinator: coordinator,
      scheduleWork: scheduler.schedule
    )

    for _ in 0..<3 {
      XCTAssertEqual(
        command.perform(),
        .transitioned(from: .idle, to: .requestingPermission)
      )
      await scheduler.runNext()
      XCTAssertEqual(coordinator.state, .idle)
    }

    XCTAssertEqual(scheduler.scheduledCompletionCount, 3)
    XCTAssertEqual(scheduler.pendingCompletionCount, 0)
  }

  func testScheduledCompletionDoesNotOverrideAnUnexpectedStateChange() async {
    let coordinator = CaptureCoordinator()
    let scheduler = ManualCaptureCompletionScheduler()
    let command = makeTestCaptureCommand(
      coordinator: coordinator,
      scheduleWork: scheduler.schedule
    )

    _ = command.perform()
    _ = coordinator.handle(.fail(.permission))
    await scheduler.runNext()

    XCTAssertEqual(coordinator.state, .failed(.permission))
  }
}

@MainActor
private final class ManualCaptureCompletionScheduler {
  typealias Completion = @MainActor @Sendable () async -> Void

  private var pendingCompletions: [Completion] = []
  private(set) var scheduledCompletionCount = 0

  var pendingCompletionCount: Int {
    pendingCompletions.count
  }

  func schedule(_ completion: @escaping Completion) {
    scheduledCompletionCount += 1
    pendingCompletions.append(completion)
  }

  func runNext() async {
    guard !pendingCompletions.isEmpty else {
      return XCTFail("Expected a scheduled completion")
    }
    await pendingCompletions.removeFirst()()
  }
}

extension CaptureState {
  fileprivate static let nonIdleCaptureCommandTestCases: [CaptureState] = [
    .requestingPermission,
    .selecting,
    .capturing,
    .recognizing,
    .completing,
    .cancelled(.user),
    .failed(.internal),
  ]
}
