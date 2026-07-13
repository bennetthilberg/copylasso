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

  func testNonemptyRecognitionWritesPlainTextAndPresentsSuccessExactlyOnce() async throws {
    let selection = try makeSelection()
    let image = try makeImage(width: 80, height: 80)
    let observations = [
      RecognizedTextObservation(
        text: "transient",
        confidence: 0.9,
        boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1)
      )
    ]
    let context = makeContext(
      current: .granted,
      selectionResult: .success(.selected(selection)),
      captureResult: .success(image),
      ocrResult: .success(observations)
    )

    _ = context.command.perform()
    await context.scheduler.runNext()

    let capturedSelections = await context.screenCapture.selections
    let recognizedImageSizes = await context.ocr.recognizedImageSizes
    XCTAssertEqual(capturedSelections, [selection])
    XCTAssertEqual(recognizedImageSizes, [CGSize(width: 80, height: 80)])
    XCTAssertEqual(context.permission.recordCaptureSuccessCallCount, 1)
    XCTAssertEqual(context.textAssembler.inputs, [observations])
    XCTAssertEqual(context.clipboard.writtenTexts, ["assembled"])
    XCTAssertEqual(context.feedback.presentedFeedback, [.success(preview: "assembled")])
    XCTAssertEqual(context.coordinator.state, .idle)
    XCTAssertTrue(context.command.isEnabled)
  }

  func testEmptyRecognitionPreservesClipboardAndPresentsNoText() async throws {
    let context = makeContext(
      current: .granted,
      selectionResult: .success(.selected(try makeSelection())),
      captureResult: .success(try makeImage(width: 80, height: 80)),
      ocrResult: .success([]),
      assembledText: ""
    )

    _ = context.command.perform()
    await context.scheduler.runNext()

    XCTAssertEqual(context.textAssembler.inputs, [[]])
    XCTAssertEqual(context.clipboard.writtenTexts, [])
    XCTAssertEqual(context.feedback.presentedFeedback, [.noText])
    XCTAssertEqual(context.coordinator.state, .idle)
    XCTAssertTrue(context.command.isEnabled)
  }

  func testSuccessPreviewIsWhitespaceNormalizedAndBounded() async throws {
    let privateSuffix = "private suffix must not appear"
    let assembled =
      "  " + String(repeating: "word ", count: 30) + "\n\t" + privateSuffix
    let context = makeContext(
      current: .granted,
      selectionResult: .success(.selected(try makeSelection())),
      captureResult: .success(try makeImage(width: 80, height: 80)),
      ocrResult: .success([]),
      assembledText: assembled
    )

    _ = context.command.perform()
    await context.scheduler.runNext()

    let expectedPreview = FeedbackPreview(text: assembled).text
    XCTAssertEqual(context.clipboard.writtenTexts, [assembled])
    XCTAssertEqual(context.feedback.presentedFeedback, [.success(preview: expectedPreview)])
    XCTAssertEqual(expectedPreview.count, FeedbackPreview.maximumCharacterCount)
    XCTAssertEqual(expectedPreview.last, "…")
    XCTAssertFalse(expectedPreview.contains(privateSuffix))
  }

  func testClipboardFailureRecordsNoSuccessfulWriteAndPresentsFailure() async throws {
    let context = makeContext(
      current: .granted,
      selectionResult: .success(.selected(try makeSelection())),
      captureResult: .success(try makeImage(width: 80, height: 80)),
      ocrResult: .success([]),
      clipboardError: .injected
    )

    _ = context.command.perform()
    await context.scheduler.runNext()

    XCTAssertEqual(context.clipboard.writtenTexts, [])
    XCTAssertEqual(context.feedback.presentedFeedback, [.failure(.clipboard)])
    XCTAssertEqual(context.coordinator.state, .idle)
    XCTAssertTrue(context.command.isEnabled)
  }

  func testFeedbackFailureAfterCopyReturnsTheCommandToIdle() async throws {
    let context = makeContext(
      current: .granted,
      selectionResult: .success(.selected(try makeSelection())),
      captureResult: .success(try makeImage(width: 80, height: 80)),
      ocrResult: .success([]),
      feedbackError: .injected
    )

    _ = context.command.perform()
    await context.scheduler.runNext()

    XCTAssertEqual(context.clipboard.writtenTexts, ["assembled"])
    XCTAssertEqual(context.feedback.presentedFeedback, [])
    XCTAssertEqual(context.coordinator.state, .idle)
    XCTAssertTrue(context.command.isEnabled)
  }

  func testTenRapidCaptureCyclesDismissPriorFeedbackWithoutHoldingTheWorkflow() async throws {
    let coordinator = CaptureCoordinator()
    let scheduler = ManualCaptureWorkScheduler()
    let clipboard = SpyClipboardService()
    let feedback = SpyFeedbackService()
    let command = CaptureCommand(
      coordinator: coordinator,
      permissionService: StubScreenCapturePermissionService(
        currentResult: .granted,
        requestResult: .granted
      ),
      selectionService: StubRegionSelectionService(
        result: .success(.selected(try makeSelection()))
      ),
      screenCaptureService: StubScreenCaptureService(
        result: .success(try makeImage(width: 80, height: 80))
      ),
      ocrService: StubOCRService(result: .success([])),
      textAssembler: SpyTextAssembler(result: "copied"),
      clipboardService: clipboard,
      feedbackService: feedback,
      recoveryPresenter: SpyPermissionRecoveryPresenter(),
      scheduleWork: scheduler.schedule
    )

    for attempt in 1...10 {
      XCTAssertEqual(
        command.perform(),
        .transitioned(from: .idle, to: .requestingPermission),
        "Attempt \(attempt)"
      )
      await scheduler.runNext()
      XCTAssertEqual(coordinator.state, .idle, "Attempt \(attempt)")
      XCTAssertTrue(command.isEnabled, "Attempt \(attempt)")
      XCTAssertTrue(feedback.isVisible, "Attempt \(attempt)")
    }

    XCTAssertEqual(clipboard.writtenTexts, Array(repeating: "copied", count: 10))
    XCTAssertEqual(
      feedback.presentedFeedback,
      Array(repeating: .success(preview: "copied"), count: 10)
    )
    XCTAssertEqual(feedback.dismissCallCount, 9)
    XCTAssertEqual(scheduler.pendingWorkCount, 0)
  }

  func testRecognitionFailureReturnsIdleWithoutRetryingCapture() async throws {
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
    let recognitionCallCount = await context.ocr.recognitionCallCount
    XCTAssertEqual(capturedSelections, [selection])
    XCTAssertEqual(recognitionCallCount, 1)
    XCTAssertEqual(context.textAssembler.inputs, [])
    XCTAssertEqual(context.clipboard.writtenTexts, [])
    XCTAssertEqual(context.feedback.presentedFeedback, [.failure(.recognition)])
    XCTAssertEqual(context.coordinator.state, .idle)
    XCTAssertTrue(context.command.isEnabled)
  }

  func testRecognitionCancellationReturnsIdleAsANonPermissionOutcome() async throws {
    let coordinator = CaptureCoordinator()
    let recovery = SpyPermissionRecoveryPresenter()
    let scheduler = ManualCaptureWorkScheduler()
    let screenCapture = StubScreenCaptureService(
      result: .success(try makeImage(width: 80, height: 80))
    )
    let command = CaptureCommand(
      coordinator: coordinator,
      permissionService: StubScreenCapturePermissionService(
        currentResult: .granted,
        requestResult: .granted
      ),
      selectionService: StubRegionSelectionService(
        result: .success(.selected(try makeSelection()))
      ),
      screenCaptureService: screenCapture,
      ocrService: CancelledOCRService(),
      textAssembler: TextAssembler(),
      clipboardService: SpyClipboardService(),
      feedbackService: SpyFeedbackService(),
      recoveryPresenter: recovery,
      scheduleWork: scheduler.schedule
    )

    _ = command.perform()
    await scheduler.runNext()

    let selections = await screenCapture.selections
    XCTAssertEqual(selections.count, 1)
    XCTAssertEqual(recovery.presentedObservations, [])
    XCTAssertEqual(coordinator.state, .idle)
    XCTAssertTrue(command.isEnabled)
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
    XCTAssertEqual(context.textAssembler.inputs, [])
    XCTAssertEqual(context.recovery.presentedObservations, [])
    XCTAssertEqual(context.feedback.presentedFeedback, [.failure(.capture)])
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
      textAssembler: TextAssembler(),
      clipboardService: SpyClipboardService(),
      feedbackService: SpyFeedbackService(),
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
      .systemInterrupted,
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
      XCTAssertEqual(context.feedback.presentedFeedback, [], "reason: \(reason)")
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
    XCTAssertEqual(context.feedback.presentedFeedback, [.failure(.selection)])
    XCTAssertEqual(context.coordinator.state, .idle)
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
      textAssembler: TextAssembler(),
      clipboardService: SpyClipboardService(),
      feedbackService: SpyFeedbackService(),
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
    ocrResult: Result<[RecognizedTextObservation], TestServiceError> = .failure(.injected),
    assembledText: String = "assembled",
    clipboardError: TestServiceError? = nil,
    feedbackError: TestServiceError? = nil
  ) -> Context {
    let coordinator = CaptureCoordinator()
    let permission = StubScreenCapturePermissionService(
      currentResult: current,
      requestResult: request
    )
    let selection = StubRegionSelectionService(result: selectionResult)
    let screenCapture = StubScreenCaptureService(result: captureResult)
    let ocr = StubOCRService(result: ocrResult)
    let textAssembler = SpyTextAssembler(result: assembledText)
    let clipboard = SpyClipboardService()
    clipboard.error = clipboardError
    let feedback = SpyFeedbackService()
    feedback.error = feedbackError
    let recovery = SpyPermissionRecoveryPresenter()
    let scheduler = ManualCaptureWorkScheduler()
    let command = CaptureCommand(
      coordinator: coordinator,
      permissionService: permission,
      selectionService: selection,
      screenCaptureService: screenCapture,
      ocrService: ocr,
      textAssembler: textAssembler,
      clipboardService: clipboard,
      feedbackService: feedback,
      recoveryPresenter: recovery,
      scheduleWork: scheduler.schedule
    )
    return Context(
      coordinator: coordinator,
      permission: permission,
      selection: selection,
      screenCapture: screenCapture,
      ocr: ocr,
      textAssembler: textAssembler,
      clipboard: clipboard,
      feedback: feedback,
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
    let textAssembler: SpyTextAssembler
    let clipboard: SpyClipboardService
    let feedback: SpyFeedbackService
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

private actor CancelledOCRService: OCRService {
  func recognizeText(in image: CGImage) async throws -> [RecognizedTextObservation] {
    throw VisionOCRError.cancelled
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
