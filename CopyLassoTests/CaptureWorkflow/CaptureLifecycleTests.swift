import CoreGraphics
import XCTest

@testable import CopyLasso

@MainActor
final class CaptureLifecycleTests: XCTestCase {
  func testCancellationBeforeScheduledWorkIsIdempotentAndPerformsNoServiceWork() async throws {
    let coordinator = CaptureCoordinator()
    let permission = StubScreenCapturePermissionService(
      currentResult: .granted,
      requestResult: .granted
    )
    let selection = StubRegionSelectionService(result: .success(.cancelled(.escape)))
    let scheduler = LifecycleManualScheduler()
    let command = makeCommand(
      coordinator: coordinator,
      permission: permission,
      selection: selection,
      scheduleWork: scheduler.schedule
    )

    _ = command.perform()
    XCTAssertTrue(command.cancelActiveOperation(reason: .systemInterrupted))
    XCTAssertFalse(command.cancelActiveOperation(reason: .systemInterrupted))
    await scheduler.runNext()

    XCTAssertEqual(coordinator.state, .idle)
    XCTAssertEqual(permission.currentObservationCallCount, 0)
    XCTAssertEqual(selection.selectRegionCallCount, 0)
    XCTAssertEqual(selection.cancelSelectionCallCount, 0)
  }

  func testPendingSelectionCancellationRejectsRapidRequestsThenNextCaptureSucceeds() async throws {
    let coordinator = CaptureCoordinator()
    let scheduler = LifecycleManualScheduler()
    let selection = ReusableLifecycleSelectionService(success: try makeSelection())
    let clipboard = SpyClipboardService()
    let feedback = SpyFeedbackService()
    let command = makeCommand(
      coordinator: coordinator,
      selection: selection,
      clipboard: clipboard,
      feedback: feedback,
      scheduleWork: scheduler.schedule
    )

    _ = command.perform()
    let firstFlow = Task { @MainActor in await scheduler.runNext() }
    await selection.waitUntilPending()
    for _ in 0..<100 {
      XCTAssertEqual(command.perform(), .rejectedBusy(currentState: .selecting))
    }

    XCTAssertTrue(command.cancelActiveOperation(reason: .systemInterrupted))
    await firstFlow.value
    XCTAssertEqual(coordinator.state, .idle)
    XCTAssertEqual(selection.cancelSelectionCallCount, 1)
    XCTAssertEqual(clipboard.writtenTexts, [])
    XCTAssertEqual(feedback.presentedFeedback, [])

    _ = command.perform()
    await scheduler.runNext()
    XCTAssertEqual(coordinator.state, .idle)
    XCTAssertEqual(clipboard.writtenTexts, ["assembled"])
    XCTAssertEqual(feedback.presentedFeedback, [.success(preview: "assembled")])
  }

  func testSystemInterruptionCancelsPendingCaptureWithoutDownstreamWork() async throws {
    let coordinator = CaptureCoordinator()
    let capture = CancellableHoldingCaptureService()
    let ocr = StubOCRService(result: .success([observation()]))
    let clipboard = SpyClipboardService()
    let feedback = SpyFeedbackService()
    let command = makeCommand(
      coordinator: coordinator,
      capture: capture,
      ocr: ocr,
      clipboard: clipboard,
      feedback: feedback
    )

    _ = command.perform()
    await capture.waitUntilStarted()
    XCTAssertEqual(coordinator.state, .capturing)
    XCTAssertTrue(command.cancelActiveOperation(reason: .systemInterrupted))
    await waitForIdle(coordinator)

    let recognitionCallCount = await ocr.recognitionCallCount
    XCTAssertEqual(recognitionCallCount, 0)
    XCTAssertEqual(clipboard.writtenTexts, [])
    XCTAssertEqual(feedback.presentedFeedback, [])
  }

  func testSystemInterruptionCancelsPendingRecognitionAndReleasesTheCommand() async throws {
    let coordinator = CaptureCoordinator()
    let ocr = CancellableHoldingOCRService()
    let clipboard = SpyClipboardService()
    let feedback = SpyFeedbackService()
    let command = makeCommand(
      coordinator: coordinator,
      ocr: ocr,
      clipboard: clipboard,
      feedback: feedback
    )

    _ = command.perform()
    await ocr.waitUntilStarted()
    XCTAssertEqual(coordinator.state, .recognizing)
    XCTAssertTrue(command.cancelActiveOperation(reason: .applicationTerminated))
    await waitForIdle(coordinator)

    XCTAssertEqual(clipboard.writtenTexts, [])
    XCTAssertEqual(feedback.presentedFeedback, [])
    XCTAssertTrue(command.isEnabled)
  }

  func testSystemInterruptionDismissesVisibleFeedbackWhileWorkflowIsIdle() async throws {
    let coordinator = CaptureCoordinator()
    let feedback = VisibleLifecycleFeedbackService()
    let clipboard = SpyClipboardService()
    let command = makeCommand(
      coordinator: coordinator,
      clipboard: clipboard,
      feedback: feedback
    )

    _ = command.perform()
    await feedback.waitUntilPresentationCount(1)
    XCTAssertEqual(coordinator.state, .idle)
    XCTAssertEqual(clipboard.writtenTexts, ["assembled"])
    XCTAssertFalse(command.cancelActiveOperation(reason: .systemInterrupted))

    XCTAssertFalse(feedback.isPresented)
    XCTAssertEqual(feedback.dismissCallCount, 1)
    XCTAssertTrue(command.isEnabled)
  }

  func testThreeVisibleFeedbackCyclesRemainDismissibleBySystemInterruption() async throws {
    let coordinator = CaptureCoordinator()
    let feedback = VisibleLifecycleFeedbackService()
    let clipboard = SpyClipboardService()
    let command = makeCommand(
      coordinator: coordinator,
      clipboard: clipboard,
      feedback: feedback
    )

    for attempt in 1...3 {
      XCTAssertEqual(
        command.perform(),
        .transitioned(from: .idle, to: .requestingPermission),
        "Attempt \(attempt)"
      )
      await feedback.waitUntilPresentationCount(attempt)
      XCTAssertEqual(coordinator.state, .idle, "Attempt \(attempt)")
    }

    XCTAssertEqual(clipboard.writtenTexts, ["assembled", "assembled", "assembled"])
    XCTAssertFalse(command.cancelActiveOperation(reason: .systemInterrupted))

    XCTAssertEqual(feedback.dismissCallCount, 3)
    XCTAssertFalse(feedback.isPresented)
    XCTAssertTrue(command.isEnabled)
  }

  private func makeCommand(
    coordinator: CaptureCoordinator,
    permission: StubScreenCapturePermissionService? = nil,
    selection: (any RegionSelectionService)? = nil,
    capture: (any ScreenCaptureService)? = nil,
    ocr: (any OCRService)? = nil,
    clipboard: SpyClipboardService? = nil,
    feedback: (any FeedbackService)? = nil,
    scheduleWork: CaptureCommand.WorkScheduler? = nil
  ) -> CaptureCommand {
    let resolvedSchedule = scheduleWork
    return CaptureCommand(
      coordinator: coordinator,
      permissionService: permission
        ?? StubScreenCapturePermissionService(currentResult: .granted, requestResult: .granted),
      selectionService: selection
        ?? StubRegionSelectionService(result: .success(.selected(try! makeSelection()))),
      screenCaptureService: capture
        ?? StubScreenCaptureService(result: .success(try! makeImage())),
      ocrService: ocr ?? StubOCRService(result: .success([observation()])),
      textAssembler: SpyTextAssembler(result: "assembled"),
      clipboardService: clipboard ?? SpyClipboardService(),
      feedbackService: feedback ?? SpyFeedbackService(),
      recoveryPresenter: SpyPermissionRecoveryPresenter(),
      scheduleWork: resolvedSchedule
    )
  }

  private func waitForIdle(_ coordinator: CaptureCoordinator) async {
    for _ in 0..<200 where coordinator.state != .idle {
      await Task.yield()
    }
    XCTAssertEqual(coordinator.state, .idle)
  }

  private func makeSelection() throws -> SelectionResult {
    let display = try DisplayGeometry(
      displayID: 31,
      appKitFrame: CGRect(x: 0, y: 0, width: 400, height: 300),
      coreGraphicsBounds: CGRect(x: 0, y: 0, width: 400, height: 300),
      backingScale: 1
    )
    return try XCTUnwrap(
      display.selectionResult(from: CGPoint(x: 20, y: 30), to: CGPoint(x: 180, y: 120))
    )
  }

  private func makeImage() throws -> CGImage {
    guard
      let context = CGContext(
        data: nil,
        width: 160,
        height: 90,
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

  private func observation() -> RecognizedTextObservation {
    RecognizedTextObservation(
      text: "assembled",
      confidence: 0.99,
      boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.4, height: 0.1)
    )
  }
}

@MainActor
private final class LifecycleManualScheduler {
  private var work: [CaptureCommand.Work] = []

  var schedule: CaptureCommand.WorkScheduler {
    { [weak self] work in self?.work.append(work) }
  }

  func runNext() async {
    guard !work.isEmpty else {
      return XCTFail("Expected scheduled lifecycle work")
    }
    await work.removeFirst()()
  }
}

@MainActor
private final class ReusableLifecycleSelectionService: RegionSelectionService {
  private let success: SelectionResult
  private var continuation: CheckedContinuation<SelectionOutcome, Never>?
  private(set) var callCount = 0
  private(set) var cancelSelectionCallCount = 0

  init(success: SelectionResult) {
    self.success = success
  }

  func selectRegion() async throws -> SelectionOutcome {
    callCount += 1
    if callCount > 1 {
      return .selected(success)
    }
    return await withCheckedContinuation { continuation = $0 }
  }

  func cancelSelection() {
    cancelSelectionCallCount += 1
    let continuation = continuation
    self.continuation = nil
    continuation?.resume(returning: .cancelled(.applicationTerminated))
  }

  func waitUntilPending() async {
    while continuation == nil {
      await Task.yield()
    }
  }
}

private actor CancellableHoldingCaptureService: ScreenCaptureService {
  private var continuation: CheckedContinuation<CGImage, Error>?
  private var started = false

  func capture(_ selection: SelectionResult) async throws -> CGImage {
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        self.continuation = continuation
        started = true
      }
    } onCancel: {
      Task { await self.cancel() }
    }
  }

  func waitUntilStarted() async {
    while !started {
      await Task.yield()
    }
  }

  private func cancel() {
    let continuation = continuation
    self.continuation = nil
    continuation?.resume(throwing: CancellationError())
  }
}

private actor CancellableHoldingOCRService: OCRService {
  private var continuation: CheckedContinuation<[RecognizedTextObservation], Error>?
  private var started = false

  func recognizeText(in image: CGImage) async throws -> [RecognizedTextObservation] {
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        self.continuation = continuation
        started = true
      }
    } onCancel: {
      Task { await self.cancel() }
    }
  }

  func waitUntilStarted() async {
    while !started {
      await Task.yield()
    }
  }

  private func cancel() {
    let continuation = continuation
    self.continuation = nil
    continuation?.resume(throwing: CancellationError())
  }
}

@MainActor
private final class VisibleLifecycleFeedbackService: FeedbackService {
  private(set) var isPresented = false
  private(set) var presentationCount = 0
  private(set) var dismissCallCount = 0

  func present(_ feedback: CaptureFeedback) throws {
    presentationCount += 1
    isPresented = true
  }

  func waitUntilPresentationCount(_ count: Int) async {
    while presentationCount < count {
      await Task.yield()
    }
  }

  func dismiss() {
    guard isPresented else { return }
    dismissCallCount += 1
    isPresented = false
  }
}
