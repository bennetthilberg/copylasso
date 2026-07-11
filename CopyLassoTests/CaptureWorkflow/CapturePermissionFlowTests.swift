import XCTest

@testable import CopyLasso

@MainActor
final class CapturePermissionFlowTests: XCTestCase {
  func testGrantedPermissionReachesSelectionExactlyOnceAndReturnsIdleAfterStubFailure() async {
    let context = makeContext(current: .granted)

    XCTAssertEqual(
      context.command.perform(),
      .transitioned(from: .idle, to: .requestingPermission)
    )
    XCTAssertEqual(
      context.command.perform(),
      .rejectedBusy(currentState: .requestingPermission)
    )
    XCTAssertEqual(context.scheduler.pendingWorkCount, 1)

    await context.scheduler.runNext()

    XCTAssertEqual(context.permission.currentObservationCallCount, 1)
    XCTAssertEqual(context.permission.requestAccessCallCount, 0)
    XCTAssertEqual(context.selection.selectRegionCallCount, 1)
    XCTAssertEqual(context.recovery.presentedObservations, [])
    XCTAssertEqual(context.recovery.dismissCallCount, 1)
    XCTAssertEqual(context.coordinator.state, .idle)
    XCTAssertTrue(context.command.isEnabled)
  }

  func testFirstRequestCanGrantAndReachSelection() async {
    let context = makeContext(
      current: .notGrantedNeverRequested,
      request: .granted
    )

    _ = context.command.perform()
    await context.scheduler.runNext()

    XCTAssertEqual(context.permission.requestAccessCallCount, 1)
    XCTAssertEqual(context.selection.selectRegionCallCount, 1)
    XCTAssertEqual(context.coordinator.state, .idle)
  }

  func testFirstRequestDenialPresentsRecoveryWithoutSelectionAndReturnsIdle() async {
    let context = makeContext(
      current: .notGrantedNeverRequested,
      request: .notGrantedAfterRequest
    )

    _ = context.command.perform()
    await context.scheduler.runNext()

    XCTAssertEqual(context.permission.requestAccessCallCount, 1)
    XCTAssertEqual(context.selection.selectRegionCallCount, 0)
    XCTAssertEqual(context.recovery.presentedObservations, [.notGrantedAfterRequest])
    XCTAssertEqual(context.coordinator.state, .idle)
    XCTAssertTrue(context.command.isEnabled)
  }

  func testKnownUnavailableStatesNeverRequestOrBeginSelection() async {
    for observation in [
      ScreenCaptureAuthorizationObservation.notGrantedAfterRequest,
      .notGrantedAfterPreviouslyGranted,
    ] {
      let context = makeContext(current: observation)

      _ = context.command.perform()
      await context.scheduler.runNext()

      XCTAssertEqual(context.permission.requestAccessCallCount, 0)
      XCTAssertEqual(context.selection.selectRegionCallCount, 0)
      XCTAssertEqual(context.recovery.presentedObservations, [observation])
      XCTAssertEqual(context.coordinator.state, .idle)
    }
  }

  func testRepeatedDeniedAttemptsDoNotRepeatTheSystemRequestOrStackWork() async {
    let context = makeContext(
      current: .notGrantedNeverRequested,
      request: .notGrantedAfterRequest
    )

    _ = context.command.perform()
    XCTAssertEqual(context.scheduler.pendingWorkCount, 1)
    XCTAssertEqual(
      context.command.perform(),
      .rejectedBusy(currentState: .requestingPermission)
    )
    XCTAssertEqual(context.scheduler.pendingWorkCount, 1)
    await context.scheduler.runNext()

    context.permission.currentResult = .notGrantedAfterRequest
    _ = context.command.perform()
    await context.scheduler.runNext()

    XCTAssertEqual(context.permission.requestAccessCallCount, 1)
    XCTAssertEqual(
      context.recovery.presentedObservations,
      [.notGrantedAfterRequest, .notGrantedAfterRequest]
    )
    XCTAssertEqual(context.coordinator.state, .idle)
  }

  func testThreeGrantedAttemptsRemainReusable() async {
    let context = makeContext(current: .granted)

    for _ in 0..<3 {
      _ = context.command.perform()
      await context.scheduler.runNext()
      XCTAssertEqual(context.coordinator.state, .idle)
    }

    XCTAssertEqual(context.selection.selectRegionCallCount, 3)
    XCTAssertEqual(context.scheduler.scheduledWorkCount, 3)
  }

  private func makeContext(
    current: ScreenCaptureAuthorizationObservation,
    request: ScreenCaptureAuthorizationObservation = .granted
  ) -> Context {
    let coordinator = CaptureCoordinator()
    let permission = StubScreenCapturePermissionService(
      currentResult: current,
      requestResult: request
    )
    let selection = StubRegionSelectionService(result: .failure(.injected))
    let recovery = SpyPermissionRecoveryPresenter()
    let scheduler = ManualCaptureWorkScheduler()
    let command = CaptureCommand(
      coordinator: coordinator,
      permissionService: permission,
      selectionService: selection,
      recoveryPresenter: recovery,
      scheduleWork: scheduler.schedule
    )
    return Context(
      coordinator: coordinator,
      permission: permission,
      selection: selection,
      recovery: recovery,
      scheduler: scheduler,
      command: command
    )
  }

  private struct Context {
    let coordinator: CaptureCoordinator
    let permission: StubScreenCapturePermissionService
    let selection: StubRegionSelectionService
    let recovery: SpyPermissionRecoveryPresenter
    let scheduler: ManualCaptureWorkScheduler
    let command: CaptureCommand
  }
}

@MainActor
private final class ManualCaptureWorkScheduler {
  typealias Work = @MainActor @Sendable () async -> Void

  private var pendingWork: [Work] = []
  private(set) var scheduledWorkCount = 0

  var pendingWorkCount: Int {
    pendingWork.count
  }

  func schedule(_ work: @escaping Work) {
    scheduledWorkCount += 1
    pendingWork.append(work)
  }

  func runNext() async {
    guard !pendingWork.isEmpty else {
      return XCTFail("Expected scheduled capture work")
    }
    await pendingWork.removeFirst()()
  }
}
