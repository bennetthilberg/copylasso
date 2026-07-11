import CoreGraphics
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

  func testValidSelectionCapturesImageAndReachesPendingOCRBoundaryExactlyOnce() async throws {
    let selection = try makeSelection()
    let image = try makeImage(width: 80, height: 80)
    let context = makeContext(
      current: .granted,
      selectionResult: .success(.selected(selection)),
      captureResult: .success(image)
    )

    _ = context.command.perform()
    await context.scheduler.runNext()

    let capturedSelections = await context.screenCapture.selections
    let recognizedImageSizes = await context.ocr.recognizedImageSizes
    XCTAssertEqual(capturedSelections, [selection])
    XCTAssertEqual(recognizedImageSizes, [CGSize(width: 80, height: 80)])
    XCTAssertEqual(context.permission.recordCaptureSuccessCallCount, 1)
    XCTAssertEqual(context.coordinator.state, .idle)
    XCTAssertTrue(context.command.isEnabled)
  }

  func testCaptureFailureNeverCallsOCRAndReturnsIdle() async throws {
    let selection = try makeSelection()
    let context = makeContext(
      current: .granted,
      selectionResult: .success(.selected(selection))
    )

    _ = context.command.perform()
    await context.scheduler.runNext()

    let capturedSelections = await context.screenCapture.selections
    let recognitionCallCount = await context.ocr.recognitionCallCount
    XCTAssertEqual(capturedSelections, [selection])
    XCTAssertEqual(recognitionCallCount, 0)
    XCTAssertEqual(context.permission.recordCaptureSuccessCallCount, 0)
    XCTAssertEqual(context.recovery.presentedObservations, [])
    XCTAssertEqual(context.coordinator.state, .idle)
  }

  func testAuthoritativeCaptureDenialPresentsLikelyRevokedRecovery() async throws {
    let coordinator = CaptureCoordinator()
    let permission = StubScreenCapturePermissionService(
      currentResult: .granted,
      requestResult: .granted
    )
    let recovery = SpyPermissionRecoveryPresenter()
    let scheduler = ManualCaptureWorkScheduler()
    let ocr = StubOCRService(result: .failure(.injected))
    let command = CaptureCommand(
      coordinator: coordinator,
      permissionService: permission,
      selectionService: StubRegionSelectionService(
        result: .success(.selected(try makeSelection()))
      ),
      screenCaptureService: PermissionDeniedScreenCaptureService(),
      ocrService: ocr,
      recoveryPresenter: recovery,
      scheduleWork: scheduler.schedule
    )

    _ = command.perform()
    await scheduler.runNext()

    XCTAssertEqual(permission.recordCaptureDenialCallCount, 1)
    XCTAssertEqual(recovery.presentedObservations, [.notGrantedAfterPreviouslyGranted])
    let recognitionCallCount = await ocr.recognitionCallCount
    XCTAssertEqual(recognitionCallCount, 0)
    XCTAssertEqual(coordinator.state, .idle)
  }

  func testSelectionCancellationNeverRecordsCaptureSuccessForEveryReason() async {
    for reason in [
      SelectionCancellationReason.escape,
      .tooSmall,
      .displayChanged,
      .applicationTerminated,
    ] {
      let context = makeContext(
        current: .granted,
        selectionResult: .success(.cancelled(reason))
      )

      _ = context.command.perform()
      await context.scheduler.runNext()

      let capturedSelections = await context.screenCapture.selections
      XCTAssertEqual(capturedSelections, [], "reason: \(reason)")
      XCTAssertEqual(context.permission.recordCaptureSuccessCallCount, 0, "reason: \(reason)")
      let recognitionCallCount = await context.ocr.recognitionCallCount
      XCTAssertEqual(recognitionCallCount, 0, "reason: \(reason)")
      XCTAssertEqual(context.coordinator.state, .idle, "reason: \(reason)")
    }
  }

  func testSelectionFailureNeverCallsCaptureAndReturnsIdle() async {
    let context = makeContext(current: .granted, selectionResult: .failure(.injected))

    _ = context.command.perform()
    await context.scheduler.runNext()

    let capturedSelections = await context.screenCapture.selections
    XCTAssertEqual(capturedSelections, [])
    let recognitionCallCount = await context.ocr.recognitionCallCount
    XCTAssertEqual(recognitionCallCount, 0)
    XCTAssertEqual(context.coordinator.state, .idle)
  }

  func testPendingOCRServiceRejectsBeforeProducingObservations() async throws {
    let service = PendingOCRService()

    do {
      _ = try await service.recognizeText(in: makeImage(width: 8, height: 6))
      XCTFail("Expected the G15 boundary to be unavailable")
    } catch {
      XCTAssertEqual(error as? PendingOCRError, .unavailableUntilG15)
    }
  }

  func testCommandRemainsBusyWhileProductionSelectionIsPending() async {
    let coordinator = CaptureCoordinator()
    let selection = HoldingRegionSelectionService()
    let scheduler = ManualCaptureWorkScheduler()
    let command = CaptureCommand(
      coordinator: coordinator,
      permissionService: StubScreenCapturePermissionService(
        currentResult: .granted,
        requestResult: .granted
      ),
      selectionService: selection,
      screenCaptureService: StubScreenCaptureService(result: .failure(.injected)),
      ocrService: StubOCRService(result: .failure(.injected)),
      recoveryPresenter: SpyPermissionRecoveryPresenter(),
      scheduleWork: scheduler.schedule
    )

    XCTAssertEqual(
      command.perform(),
      .transitioned(from: .idle, to: .requestingPermission)
    )
    let flow = Task { @MainActor in await scheduler.runNext() }
    await Task.yield()
    await Task.yield()

    XCTAssertEqual(coordinator.state, .selecting)
    XCTAssertEqual(command.perform(), .rejectedBusy(currentState: .selecting))
    XCTAssertEqual(selection.selectRegionCallCount, 1)

    selection.complete(with: .cancelled(.escape))
    await flow.value
    XCTAssertEqual(coordinator.state, .idle)
  }

  private func makeContext(
    current: ScreenCaptureAuthorizationObservation,
    request: ScreenCaptureAuthorizationObservation = .granted,
    selectionResult: Result<SelectionOutcome, TestServiceError> = .failure(.injected),
    captureResult: Result<CGImage, TestServiceError> = .failure(.injected),
    ocrResult: Result<[RecognizedTextObservation], TestServiceError> = .failure(.injected)
  ) -> Context {
    let coordinator = CaptureCoordinator()
    let permission = StubScreenCapturePermissionService(
      currentResult: current,
      requestResult: request
    )
    let selection = StubRegionSelectionService(result: selectionResult)
    let screenCapture = StubScreenCaptureService(result: captureResult)
    let ocr = StubOCRService(result: ocrResult)
    let recovery = SpyPermissionRecoveryPresenter()
    let scheduler = ManualCaptureWorkScheduler()
    let command = CaptureCommand(
      coordinator: coordinator,
      permissionService: permission,
      selectionService: selection,
      screenCaptureService: screenCapture,
      ocrService: ocr,
      recoveryPresenter: recovery,
      scheduleWork: scheduler.schedule
    )
    return Context(
      coordinator: coordinator,
      permission: permission,
      selection: selection,
      screenCapture: screenCapture,
      ocr: ocr,
      recovery: recovery,
      scheduler: scheduler,
      command: command
    )
  }

  private func makeSelection() throws -> SelectionResult {
    let display = try DisplayGeometry(
      displayID: 7,
      appKitFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
      coreGraphicsBounds: CGRect(x: 0, y: 0, width: 100, height: 100),
      backingScale: 2
    )
    return try XCTUnwrap(
      display.selectionResult(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 50, y: 60))
    )
  }

  private func makeImage(width: Int, height: Int) throws -> CGImage {
    guard
      let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ),
      let image = context.makeImage()
    else {
      throw TestServiceError.injected
    }
    return image
  }

  private struct Context {
    let coordinator: CaptureCoordinator
    let permission: StubScreenCapturePermissionService
    let selection: StubRegionSelectionService
    let screenCapture: StubScreenCaptureService
    let ocr: StubOCRService
    let recovery: SpyPermissionRecoveryPresenter
    let scheduler: ManualCaptureWorkScheduler
    let command: CaptureCommand
  }
}

private actor PermissionDeniedScreenCaptureService: ScreenCaptureService {
  func capture(_ selection: SelectionResult) async throws -> CGImage {
    throw ScreenCaptureError.permissionDenied
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

@MainActor
private final class HoldingRegionSelectionService: RegionSelectionService {
  private var continuation: CheckedContinuation<SelectionOutcome, Never>?
  private(set) var selectRegionCallCount = 0

  func selectRegion() async throws -> SelectionOutcome {
    selectRegionCallCount += 1
    return await withCheckedContinuation { self.continuation = $0 }
  }

  func cancelSelection() {
    complete(with: .cancelled(.applicationTerminated))
  }

  func complete(with outcome: SelectionOutcome) {
    let continuation = continuation
    self.continuation = nil
    continuation?.resume(returning: outcome)
  }
}
