import CoreGraphics
import Darwin
import Foundation
import XCTest

@testable import CopyLasso

@MainActor
final class SystemInteractiveCaptureServiceTests: XCTestCase {
  func testProductionConfigurationUsesOnlyTheFixedSystemSelectorContract() {
    let configuration = SystemInteractiveCaptureConfiguration.copyLasso

    XCTAssertEqual(
      configuration.executableURL,
      URL(fileURLWithPath: "/usr/sbin/screencapture")
    )
    XCTAssertEqual(
      configuration.arguments,
      ["-i", "-s", "-x", "-t", "png", "/dev/null"]
    )
  }

  func testPrepareStartsSelectorSynchronouslyAndCapturesSelectedGeometryInMemory() async throws {
    let display = try makeDisplay()
    let selection = try XCTUnwrap(
      display.selectionResultFromCoreGraphics(
        from: CGPoint(x: 100, y: 120),
        to: CGPoint(x: 420, y: 300)
      )
    )
    let image = try makeImage(width: 320, height: 180)
    let session = StubSystemInteractiveCaptureProcessSession(
      result: .success(
        SystemInteractiveCaptureProcessResult(
          terminationStatus: 1,
          terminationReason: .exit,
          selectionOutcome: .selected(selection)
        )
      )
    )
    let launcher = RecordingSystemInteractiveCaptureProcessLauncher(sessions: [session])
    let screenCapture = StubScreenCaptureService(result: .success(image))
    let service = SystemInteractiveCaptureService(
      launcher: launcher,
      screenCaptureService: screenCapture
    )

    service.prepareForCaptureTransition()

    XCTAssertEqual(launcher.configurations, [.copyLasso])
    let outcome = try await service.capture()

    guard case .captured(let capturedImage) = outcome else {
      return XCTFail("Expected captured image")
    }
    XCTAssertEqual(capturedImage.width, 320)
    XCTAssertEqual(capturedImage.height, 180)
    let capturedSelections = await screenCapture.selections
    XCTAssertEqual(capturedSelections, [selection])
    XCTAssertEqual(launcher.configurations, [.copyLasso])
  }

  func testRepeatedPreparationDoesNotStartOverlappingSelectors() {
    let session = StubSystemInteractiveCaptureProcessSession(
      result: .success(.cancelledFixture)
    )
    let launcher = RecordingSystemInteractiveCaptureProcessLauncher(sessions: [session])
    let service = makeService(launcher: launcher)

    service.prepareForCaptureTransition()
    service.prepareForCaptureTransition()

    XCTAssertEqual(launcher.configurations, [.copyLasso])
  }

  func testCaptureStartsSelectorWhenMenuInvocationDidNotPreflight() async throws {
    let session = StubSystemInteractiveCaptureProcessSession(
      result: .success(.cancelledFixture)
    )
    let launcher = RecordingSystemInteractiveCaptureProcessLauncher(sessions: [session])
    let service = makeService(launcher: launcher)

    let outcome = try await service.capture()

    XCTAssertEqual(launcher.configurations, [.copyLasso])
    guard case .cancelled(.escape) = outcome else {
      return XCTFail("Expected Escape cancellation")
    }
  }

  func testSuccessfulSelectorExitWithoutADragIsAlsoEscape() async throws {
    let service = makeService(
      result: SystemInteractiveCaptureProcessResult(
        terminationStatus: 0,
        terminationReason: .exit
      )
    )

    guard case .cancelled(.escape) = try await service.capture() else {
      return XCTFail("Expected empty successful selector exit to cancel")
    }
  }

  func testControlHeldBeforeLaunchIsRejectedWithoutStartingAProcess() throws {
    let launcher = makeLiveLauncher(controlModifierProvider: { true })

    XCTAssertThrowsError(try launcher.start(.exitingFixture)) { error in
      XCTAssertEqual(
        error as? SystemInteractiveCaptureProcessError,
        .controlModifierActive
      )
    }
  }

  func testUnavailableDisplaysRejectLaunchWithoutStartingAProcess() {
    let launcher = SystemInteractiveCaptureProcessLauncher(
      controlModifierProvider: { false },
      pointerTransitionMonitorProvider: {
        XCTFail("A display failure must precede event monitoring")
        return StubSystemInteractivePointerTransitionMonitor()
      },
      displayProvider: { [] }
    )

    XCTAssertThrowsError(try launcher.start(.exitingFixture)) { error in
      XCTAssertEqual(
        error as? SystemInteractiveCaptureProcessError,
        .displayUnavailable
      )
    }
  }

  func testControlHeldBeforeMenuCaptureIsAnInertCancellation() async throws {
    let service = SystemInteractiveCaptureService(
      launcher: FailingSystemInteractiveCaptureProcessLauncher(
        error: .controlModifierActive
      ),
      screenCaptureService: StubScreenCaptureService(result: .failure(.injected))
    )

    let outcome = try await service.capture()

    guard case .cancelled(.systemInterrupted) = outcome else {
      return XCTFail("Expected held Control to cancel before capture")
    }
  }

  func testLiveSessionCancelsWhenControlIsPressedDuringSelection() async throws {
    let modifierState = LockedControlModifierState(isPressed: false)
    let configuration = SystemInteractiveCaptureConfiguration(
      executableURL: URL(fileURLWithPath: "/bin/sleep"),
      arguments: ["5"]
    )
    let launcher = makeLiveLauncher(
      controlModifierProvider: { modifierState.isPressed }
    )
    let session = try launcher.start(configuration)

    modifierState.isPressed = true
    let result = try await session.result()

    XCTAssertTrue(result.wasCancelledForControlModifier)
    XCTAssertNil(result.selectionOutcome)
    XCTAssertEqual(result.terminationReason, .uncaughtSignal)
    XCTAssertEqual(result.terminationStatus, SIGINT)

    modifierState.isPressed = false
    let followupSession = try launcher.start(.exitingFixture)
    let followupResult = try await followupSession.result()

    XCTAssertEqual(followupResult.terminationReason, .exit)
    XCTAssertEqual(followupResult.terminationStatus, 0)
    XCTAssertNil(followupResult.selectionOutcome)
  }

  func testControlDetectedDuringSelectionIsAnInertCancellation() async throws {
    let result = SystemInteractiveCaptureProcessResult(
      terminationStatus: SIGINT,
      terminationReason: .uncaughtSignal,
      wasCancelledForControlModifier: true
    )
    let service = makeService(result: result)

    let outcome = try await service.capture()

    guard case .cancelled(.systemInterrupted) = outcome else {
      return XCTFail("Expected detected Control to cancel capture")
    }
  }

  func testSelectionIsAcceptedDespiteNativeSelectorOutputFailure() async throws {
    let display = try makeDisplay()
    let selection = try XCTUnwrap(
      display.selectionResultFromCoreGraphics(
        from: CGPoint(x: 40, y: 50),
        to: CGPoint(x: 240, y: 150)
      )
    )
    let image = try makeImage(width: 200, height: 100)
    let screenCapture = StubScreenCaptureService(result: .success(image))
    let service = makeService(
      result: SystemInteractiveCaptureProcessResult(
        terminationStatus: 1,
        terminationReason: .exit,
        selectionOutcome: .selected(selection)
      ),
      screenCaptureService: screenCapture
    )

    guard case .captured(let captured) = try await service.capture() else {
      return XCTFail("Expected selected geometry to be captured")
    }
    XCTAssertEqual(captured.width, 200)
    XCTAssertEqual(captured.height, 100)
    let capturedSelections = await screenCapture.selections
    XCTAssertEqual(capturedSelections, [selection])
  }

  func testProcessFailureWithoutSelectionIsNotMisreportedAsCancellation() async {
    let service = makeService(
      result: SystemInteractiveCaptureProcessResult(
        terminationStatus: 2,
        terminationReason: .exit
      )
    )

    await assertThrowsErrorAsync(try await service.capture()) { error in
      XCTAssertEqual(error as? InteractiveCaptureError, .processFailed(status: 2))
    }
  }

  func testTooSmallSelectionDoesNotRequestPixels() async throws {
    let screenCapture = StubScreenCaptureService(result: .failure(.injected))
    let service = makeService(
      result: SystemInteractiveCaptureProcessResult(
        terminationStatus: 1,
        terminationReason: .exit,
        selectionOutcome: .cancelled(.tooSmall)
      ),
      screenCaptureService: screenCapture
    )

    guard case .cancelled(.tooSmall) = try await service.capture() else {
      return XCTFail("Expected too-small cancellation")
    }
    let capturedSelections = await screenCapture.selections
    XCTAssertTrue(capturedSelections.isEmpty)
  }

  func testScreenCapturePermissionDenialMapsToInteractivePermissionDenial() async {
    let display = try? makeDisplay()
    let selection = try? display?.selectionResultFromCoreGraphics(
      from: CGPoint(x: 10, y: 10),
      to: CGPoint(x: 100, y: 100)
    )
    let service = makeService(
      result: SystemInteractiveCaptureProcessResult(
        terminationStatus: 1,
        terminationReason: .exit,
        selectionOutcome: selection.flatMap { $0 }.map(SelectionOutcome.selected)
      ),
      screenCaptureService: FailingScreenCaptureService(error: .permissionDenied)
    )

    await assertThrowsErrorAsync(try await service.capture()) { error in
      XCTAssertEqual(error as? InteractiveCaptureError, .permissionDenied)
    }
  }

  func testOtherScreenCaptureFailureMapsToCaptureFailure() async throws {
    let display = try makeDisplay()
    let selection = try XCTUnwrap(
      display.selectionResultFromCoreGraphics(
        from: CGPoint(x: 10, y: 10),
        to: CGPoint(x: 100, y: 100)
      )
    )
    let service = makeService(
      result: SystemInteractiveCaptureProcessResult(
        terminationStatus: 1,
        terminationReason: .exit,
        selectionOutcome: .selected(selection)
      )
    )

    await assertThrowsErrorAsync(try await service.capture()) { error in
      XCTAssertEqual(error as? InteractiveCaptureError, .captureFailed)
    }
  }

  func testCancelTerminatesPreparedSessionAndAllowsFreshPreparation() {
    let first = StubSystemInteractiveCaptureProcessSession(result: .success(.cancelledFixture))
    let second = StubSystemInteractiveCaptureProcessSession(result: .success(.cancelledFixture))
    let launcher = RecordingSystemInteractiveCaptureProcessLauncher(sessions: [first, second])
    let service = makeService(launcher: launcher)

    service.prepareForCaptureTransition()
    service.cancelCapture()
    service.prepareForCaptureTransition()

    XCTAssertEqual(first.cancelCallCount, 1)
    XCTAssertEqual(second.cancelCallCount, 0)
    XCTAssertEqual(launcher.configurations, [.copyLasso, .copyLasso])
  }

  func testCancelledStaleCompletionCannotConsumeAReplacementSession() async throws {
    let first = HoldingSystemInteractiveCaptureProcessSession()
    let second = StubSystemInteractiveCaptureProcessSession(result: .success(.cancelledFixture))
    let launcher = RecordingSystemInteractiveCaptureProcessLauncher(sessions: [first, second])
    let service = makeService(launcher: launcher)

    service.prepareForCaptureTransition()
    let staleCapture = Task { @MainActor in
      try await service.capture()
    }
    await first.waitUntilResultRequested()
    service.cancelCapture()
    service.prepareForCaptureTransition()
    first.resume(returning: .cancelledFixture)

    guard case .cancelled(.systemInterrupted) = try await staleCapture.value else {
      return XCTFail("Expected the cancelled generation to stay stale")
    }
    guard case .cancelled(.escape) = try await service.capture() else {
      return XCTFail("Expected the replacement session to remain available")
    }
    XCTAssertEqual(launcher.configurations, [.copyLasso, .copyLasso])
  }

  func testLiveProcessSessionExitsWithoutReadingOrWritingCaptureData() async throws {
    let session = try makeLiveLauncher().start(.exitingFixture)

    let result = try await session.result()

    XCTAssertEqual(result.terminationStatus, 0)
    XCTAssertEqual(result.terminationReason, .exit)
    XCTAssertNil(result.selectionOutcome)
    XCTAssertFalse(result.wasCancelledForControlModifier)
  }

  func testLiveProcessSessionRetainsFastMouseTransitionsAfterTheChildExits() async throws {
    let monitor = StubSystemInteractivePointerTransitionMonitor(
      transitions: [
        .pressed(at: CGPoint(x: 20, y: 30)),
        .released(at: CGPoint(x: 420, y: 330)),
      ]
    )
    let session = try makeLiveLauncher(
      pointerTransitionMonitorProvider: { monitor }
    ).start(.exitingFixture)

    let result = try await session.result()

    guard case .selected(let selection) = result.selectionOutcome else {
      return XCTFail("Expected timestamped transitions to survive process exit")
    }
    XCTAssertEqual(
      selection.coreGraphicsGlobalRect,
      CGRect(x: 20, y: 30, width: 400, height: 300)
    )
    XCTAssertEqual(monitor.stopCallCount, 1)
  }

  private func makeService(
    result: SystemInteractiveCaptureProcessResult,
    screenCaptureService: any ScreenCaptureService = StubScreenCaptureService(
      result: .failure(.injected)
    )
  ) -> SystemInteractiveCaptureService {
    makeService(
      launcher: RecordingSystemInteractiveCaptureProcessLauncher(
        sessions: [StubSystemInteractiveCaptureProcessSession(result: .success(result))]
      ),
      screenCaptureService: screenCaptureService
    )
  }

  private func makeService(
    launcher: any SystemInteractiveCaptureProcessLaunching,
    screenCaptureService: any ScreenCaptureService = StubScreenCaptureService(
      result: .failure(.injected)
    )
  ) -> SystemInteractiveCaptureService {
    SystemInteractiveCaptureService(
      launcher: launcher,
      screenCaptureService: screenCaptureService
    )
  }

  private func makeLiveLauncher(
    controlModifierProvider: @escaping @Sendable () -> Bool = { false },
    pointerTransitionMonitorProvider:
      @escaping SystemInteractiveCaptureProcessLauncher.PointerTransitionMonitorProvider = {
        StubSystemInteractivePointerTransitionMonitor()
      }
  ) -> SystemInteractiveCaptureProcessLauncher {
    SystemInteractiveCaptureProcessLauncher(
      controlModifierProvider: controlModifierProvider,
      pointerTransitionMonitorProvider: pointerTransitionMonitorProvider,
      displayProvider: { [try self.makeDisplay()] }
    )
  }

  private func makeDisplay() throws -> DisplayGeometry {
    try DisplayGeometry(
      displayID: 7,
      appKitFrame: CGRect(x: 0, y: 0, width: 1_920, height: 1_080),
      coreGraphicsBounds: CGRect(x: 0, y: 0, width: 1_920, height: 1_080),
      backingScale: 1
    )
  }

  private func makeImage(width: Int, height: Int) throws -> CGImage {
    let context = try XCTUnwrap(
      CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    )
    context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return try XCTUnwrap(context.makeImage())
  }
}

@MainActor
private final class RecordingSystemInteractiveCaptureProcessLauncher:
  SystemInteractiveCaptureProcessLaunching
{
  private var sessions: [any SystemInteractiveCaptureProcessSession]
  private(set) var configurations: [SystemInteractiveCaptureConfiguration] = []

  init(sessions: [any SystemInteractiveCaptureProcessSession]) {
    self.sessions = sessions
  }

  func start(
    _ configuration: SystemInteractiveCaptureConfiguration
  ) throws -> any SystemInteractiveCaptureProcessSession {
    configurations.append(configuration)
    guard !sessions.isEmpty else { throw TestServiceError.injected }
    return sessions.removeFirst()
  }
}

@MainActor
private final class FailingSystemInteractiveCaptureProcessLauncher:
  SystemInteractiveCaptureProcessLaunching
{
  private let error: SystemInteractiveCaptureProcessError

  init(error: SystemInteractiveCaptureProcessError) {
    self.error = error
  }

  func start(
    _ configuration: SystemInteractiveCaptureConfiguration
  ) throws -> any SystemInteractiveCaptureProcessSession {
    throw error
  }
}

private final class LockedControlModifierState: @unchecked Sendable {
  private let lock = NSLock()
  private var storedIsPressed: Bool

  init(isPressed: Bool) {
    storedIsPressed = isPressed
  }

  var isPressed: Bool {
    get { lock.withLock { storedIsPressed } }
    set { lock.withLock { storedIsPressed = newValue } }
  }
}

private final class StubSystemInteractivePointerTransitionMonitor:
  SystemInteractivePointerTransitionMonitoring,
  @unchecked Sendable
{
  private let lock = NSLock()
  private var storedTransitions: [SystemInteractivePointerTransition]
  private var storedStopCallCount = 0

  init(transitions: [SystemInteractivePointerTransition] = []) {
    storedTransitions = transitions
  }

  var stopCallCount: Int {
    lock.withLock { storedStopCallCount }
  }

  func drainTransitions() -> [SystemInteractivePointerTransition] {
    lock.withLock {
      let transitions = storedTransitions
      storedTransitions.removeAll()
      return transitions
    }
  }

  @MainActor
  func stop() {
    lock.withLock { storedStopCallCount += 1 }
  }
}

private final class StubSystemInteractiveCaptureProcessSession:
  SystemInteractiveCaptureProcessSession,
  @unchecked Sendable
{
  private let storedResult: Result<SystemInteractiveCaptureProcessResult, TestServiceError>
  private let lock = NSLock()
  private var storedCancelCallCount = 0

  init(result: Result<SystemInteractiveCaptureProcessResult, TestServiceError>) {
    storedResult = result
  }

  var cancelCallCount: Int {
    lock.withLock { storedCancelCallCount }
  }

  func result() async throws -> SystemInteractiveCaptureProcessResult {
    try storedResult.get()
  }

  func cancel() {
    lock.withLock { storedCancelCallCount += 1 }
  }
}

private final class HoldingSystemInteractiveCaptureProcessSession:
  SystemInteractiveCaptureProcessSession,
  @unchecked Sendable
{
  private let lock = NSLock()
  private var resultContinuation: CheckedContinuation<SystemInteractiveCaptureProcessResult, Error>?
  private var requestWaiters: [CheckedContinuation<Void, Never>] = []

  func result() async throws -> SystemInteractiveCaptureProcessResult {
    try await withCheckedThrowingContinuation { continuation in
      lock.withLock {
        resultContinuation = continuation
        let waiters = requestWaiters
        requestWaiters.removeAll()
        for waiter in waiters {
          waiter.resume()
        }
      }
    }
  }

  func cancel() {}

  func waitUntilResultRequested() async {
    await withCheckedContinuation { continuation in
      lock.withLock {
        if resultContinuation != nil {
          continuation.resume()
        } else {
          requestWaiters.append(continuation)
        }
      }
    }
  }

  func resume(returning result: SystemInteractiveCaptureProcessResult) {
    let continuation = lock.withLock {
      let continuation = resultContinuation
      resultContinuation = nil
      return continuation
    }
    continuation?.resume(returning: result)
  }
}

private actor FailingScreenCaptureService: ScreenCaptureService {
  let error: ScreenCaptureError

  init(error: ScreenCaptureError) {
    self.error = error
  }

  func capture(_ selection: SelectionResult) async throws -> CGImage {
    throw error
  }
}

extension SystemInteractiveCaptureConfiguration {
  fileprivate static let exitingFixture = SystemInteractiveCaptureConfiguration(
    executableURL: URL(fileURLWithPath: "/usr/bin/true"),
    arguments: []
  )
}

extension SystemInteractiveCaptureProcessResult {
  fileprivate static let cancelledFixture = SystemInteractiveCaptureProcessResult(
    terminationStatus: 1,
    terminationReason: .exit
  )
}

@MainActor
private func assertThrowsErrorAsync<T>(
  _ expression: @autoclosure () async throws -> T,
  _ errorHandler: (any Error) -> Void,
  file: StaticString = #filePath,
  line: UInt = #line
) async {
  do {
    _ = try await expression()
    XCTFail("Expected error", file: file, line: line)
  } catch {
    errorHandler(error)
  }
}
