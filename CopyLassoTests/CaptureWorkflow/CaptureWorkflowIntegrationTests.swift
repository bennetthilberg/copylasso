import CoreGraphics
import XCTest

@testable import CopyLasso

@MainActor
final class CaptureWorkflowIntegrationTests: XCTestCase {
  func testTwentyFiveConsecutiveSuccessfulCapturesRemainReusable() async throws {
    let context = try makeContext()

    for attempt in 1...25 {
      XCTAssertEqual(
        context.command.perform(),
        .transitioned(from: .idle, to: .requestingPermission),
        "Attempt \(attempt)"
      )
      await context.scheduler.runNext()
      XCTAssertEqual(context.coordinator.state, .idle, "Attempt \(attempt)")
      XCTAssertTrue(context.command.isEnabled, "Attempt \(attempt)")
    }

    XCTAssertEqual(context.permission.currentObservationCallCount, 25)
    XCTAssertEqual(context.selection.selectRegionCallCount, 25)
    let capturedSelections = await context.screenCapture.selections
    let recognitionCallCount = await context.ocr.recognitionCallCount
    XCTAssertEqual(capturedSelections.count, 25)
    XCTAssertEqual(recognitionCallCount, 25)
    XCTAssertEqual(context.textAssembler.inputs.count, 25)
    XCTAssertEqual(context.clipboard.writtenTexts, Array(repeating: "assembled", count: 25))
    XCTAssertEqual(context.sound.playCallCount, 25)
    XCTAssertEqual(
      context.feedback.presentedFeedback,
      Array(repeating: .success(preview: "assembled"), count: 25)
    )
  }

  func testTwentyAlternatingSuccessAndCancellationCyclesPreserveClipboardOnCancellation()
    async throws
  {
    let context = try makeContext()

    for index in 0..<20 {
      context.selection.result =
        index.isMultiple(of: 2)
        ? .success(.selected(try makeSelection())) : .success(.cancelled(.escape))
      _ = context.command.perform()
      await context.scheduler.runNext()
      XCTAssertEqual(context.coordinator.state, .idle, "Cycle \(index + 1)")
    }

    let capturedSelections = await context.screenCapture.selections
    let recognitionCallCount = await context.ocr.recognitionCallCount
    XCTAssertEqual(capturedSelections.count, 10)
    XCTAssertEqual(recognitionCallCount, 10)
    XCTAssertEqual(context.clipboard.writtenTexts.count, 10)
    XCTAssertEqual(context.sound.playCallCount, 10)
    XCTAssertEqual(context.feedback.presentedFeedback.count, 10)
    XCTAssertTrue(
      context.feedback.presentedFeedback.allSatisfy { $0 == .success(preview: "assembled") })
  }

  func testSelectionCaptureAndRecognitionFailuresPresentTheirStageAndReturnIdle() async throws {
    let selectionFailure = try makeContext(selectionResult: .failure(.injected))
    await runOne(selectionFailure)
    XCTAssertEqual(selectionFailure.feedback.presentedFeedback, [.failure(.selection)])
    XCTAssertEqual(selectionFailure.clipboard.writtenTexts, [])
    XCTAssertEqual(selectionFailure.sound.playCallCount, 0)

    let captureFailure = try makeContext(captureResult: .failure(.injected))
    await runOne(captureFailure)
    XCTAssertEqual(captureFailure.feedback.presentedFeedback, [.failure(.capture)])
    XCTAssertEqual(captureFailure.clipboard.writtenTexts, [])
    XCTAssertEqual(captureFailure.sound.playCallCount, 0)

    let recognitionFailure = try makeContext(ocrResult: .failure(.injected))
    await runOne(recognitionFailure)
    XCTAssertEqual(recognitionFailure.feedback.presentedFeedback, [.failure(.recognition)])
    XCTAssertEqual(recognitionFailure.clipboard.writtenTexts, [])
    XCTAssertEqual(recognitionFailure.sound.playCallCount, 0)
  }

  func testEverySelectionCancellationReasonIsNonErrorFeedbackFreeAndClipboardSafe()
    async throws
  {
    let reasons: [SelectionCancellationReason] = [
      .escape, .tooSmall, .displayChanged, .systemInterrupted, .applicationTerminated,
    ]

    for reason in reasons {
      let context = try makeContext(selectionResult: .success(.cancelled(reason)))
      await runOne(context)
      XCTAssertEqual(context.feedback.presentedFeedback, [], "Reason: \(reason)")
      XCTAssertEqual(context.clipboard.writtenTexts, [], "Reason: \(reason)")
      XCTAssertEqual(context.sound.playCallCount, 0, "Reason: \(reason)")
      let capturedSelections = await context.screenCapture.selections
      XCTAssertEqual(capturedSelections, [], "Reason: \(reason)")
    }
  }

  func testPixelsAndUnboundedTextAreReleasedBeforeVisibleFeedbackReturnsIdle() async throws {
    let coordinator = CaptureCoordinator()
    let scheduler = IntegrationWorkScheduler()
    let capture = EphemeralScreenCaptureService()
    let feedback = IntegrationVisibleFeedbackService()
    let clipboard = SpyClipboardService()
    let privateSuffix = "private suffix outside bounded feedback"
    let assembled = String(repeating: "visible ", count: 30) + privateSuffix
    let command = CaptureCommand(
      coordinator: coordinator,
      permissionService: StubScreenCapturePermissionService(
        currentResult: .granted,
        requestResult: .granted
      ),
      selectionService: StubRegionSelectionService(
        result: .success(.selected(try makeSelection()))
      ),
      screenCaptureService: capture,
      ocrService: StubOCRService(result: .success([observation()])),
      textAssembler: SpyTextAssembler(result: assembled),
      clipboardService: clipboard,
      feedbackService: feedback,
      recoveryPresenter: SpyPermissionRecoveryPresenter(),
      scheduleWork: scheduler.schedule
    )

    _ = command.perform()
    await scheduler.runNext()

    for _ in 0..<100 {
      if await capture.imageWasReleased() {
        break
      }
      await Task.yield()
    }
    let imageWasReleased = await capture.imageWasReleased()
    XCTAssertTrue(imageWasReleased)
    XCTAssertEqual(clipboard.writtenTexts, [assembled])
    let shownFeedback = try XCTUnwrap(feedback.presentedFeedback.first)
    guard case .success(let preview) = shownFeedback else {
      return XCTFail("Expected success feedback")
    }
    XCTAssertEqual(preview.count, FeedbackPreview.maximumCharacterCount)
    XCTAssertFalse(preview.contains(privateSuffix))
    XCTAssertEqual(coordinator.state, .idle)
    XCTAssertTrue(feedback.isVisible)
  }

  func testRecognitionFailureFeedbackCanBeReplacedAfterPixelsAreReleased() async throws {
    let coordinator = CaptureCoordinator()
    let scheduler = IntegrationWorkScheduler()
    let capture = EphemeralScreenCaptureService()
    let feedback = IntegrationVisibleFeedbackService()
    let clipboard = SpyClipboardService()
    let command = CaptureCommand(
      coordinator: coordinator,
      permissionService: StubScreenCapturePermissionService(
        currentResult: .granted,
        requestResult: .granted
      ),
      selectionService: StubRegionSelectionService(
        result: .success(.selected(try makeSelection()))
      ),
      screenCaptureService: capture,
      ocrService: StubOCRService(result: .failure(.injected)),
      textAssembler: SpyTextAssembler(result: "must not run"),
      clipboardService: clipboard,
      feedbackService: feedback,
      recoveryPresenter: SpyPermissionRecoveryPresenter(),
      scheduleWork: scheduler.schedule
    )

    _ = command.perform()
    await scheduler.runNext()

    for _ in 0..<100 {
      if await capture.imageWasReleased() {
        break
      }
      await Task.yield()
    }
    let imageWasReleased = await capture.imageWasReleased()
    XCTAssertTrue(imageWasReleased)
    XCTAssertEqual(feedback.presentedFeedback, [.failure(.recognition)])
    XCTAssertEqual(clipboard.writtenTexts, [])
    XCTAssertEqual(coordinator.state, .idle)
    XCTAssertTrue(feedback.isVisible)
    XCTAssertTrue(command.isEnabled)
    XCTAssertEqual(
      command.perform(),
      .transitioned(from: .idle, to: .requestingPermission)
    )

    XCTAssertEqual(coordinator.state, .requestingPermission)
    XCTAssertEqual(scheduler.scheduledCount, 2)
    XCTAssertEqual(feedback.dismissCallCount, 1)
  }

  func testMenuAndShortcutRouteThroughTheExactSameSuccessfulCommand() async throws {
    let context = try makeContext()
    let menu = MenuBarCommandHandler(
      captureCommand: context.command,
      applicationTerminator: NoopApplicationTerminator()
    )
    let events = StubGlobalShortcutEventSource()
    let shortcut = GlobalShortcutController(captureCommand: context.command, eventSource: events)
    shortcut.start()
    defer { shortcut.stop() }

    XCTAssertEqual(menu.captureText(), .transitioned(from: .idle, to: .requestingPermission))
    await context.scheduler.runNext()

    await Task.yield()
    events.emit(.keyUp)
    await context.scheduler.waitUntilScheduledCount(2)
    await context.scheduler.runNext()

    XCTAssertEqual(context.clipboard.writtenTexts, ["assembled", "assembled"])
    XCTAssertEqual(context.sound.playCallCount, 2)
    XCTAssertEqual(
      context.feedback.presentedFeedback,
      [.success(preview: "assembled"), .success(preview: "assembled")]
    )
    XCTAssertEqual(context.coordinator.state, .idle)
  }

  private func runOne(_ context: Context) async {
    _ = context.command.perform()
    await context.scheduler.runNext()
    XCTAssertEqual(context.coordinator.state, .idle)
    XCTAssertTrue(context.command.isEnabled)
  }

  private func makeContext(
    selectionResult: Result<SelectionOutcome, TestServiceError>? = nil,
    captureResult: Result<CGImage, TestServiceError>? = nil,
    ocrResult: Result<[RecognizedTextObservation], TestServiceError>? = nil
  ) throws -> Context {
    let coordinator = CaptureCoordinator()
    let permission = StubScreenCapturePermissionService(
      currentResult: .granted,
      requestResult: .granted
    )
    let resolvedSelectionResult: Result<SelectionOutcome, TestServiceError>
    if let selectionResult {
      resolvedSelectionResult = selectionResult
    } else {
      resolvedSelectionResult = .success(.selected(try makeSelection()))
    }
    let selection = StubRegionSelectionService(result: resolvedSelectionResult)
    let resolvedCaptureResult: Result<CGImage, TestServiceError>
    if let captureResult {
      resolvedCaptureResult = captureResult
    } else {
      resolvedCaptureResult = .success(try makeImage())
    }
    let screenCapture = StubScreenCaptureService(result: resolvedCaptureResult)
    let ocr = StubOCRService(result: ocrResult ?? .success([observation()]))
    let textAssembler = SpyTextAssembler(result: "assembled")
    let clipboard = SpyClipboardService()
    let sound = SpySuccessSoundPlayer()
    let feedback = SpyFeedbackService()
    let recovery = SpyPermissionRecoveryPresenter()
    let scheduler = IntegrationWorkScheduler()
    let command = CaptureCommand(
      coordinator: coordinator,
      permissionService: permission,
      selectionService: selection,
      screenCaptureService: screenCapture,
      ocrService: ocr,
      textAssembler: textAssembler,
      clipboardService: clipboard,
      successSoundPlayer: sound,
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
      sound: sound,
      feedback: feedback,
      recovery: recovery,
      scheduler: scheduler,
      command: command
    )
  }

  private func makeSelection() throws -> SelectionResult {
    let display = try DisplayGeometry(
      displayID: 9,
      appKitFrame: CGRect(x: 0, y: 0, width: 400, height: 300),
      coreGraphicsBounds: CGRect(x: 0, y: 0, width: 400, height: 300),
      backingScale: 2
    )
    return try XCTUnwrap(
      display.selectionResult(from: CGPoint(x: 20, y: 30), to: CGPoint(x: 180, y: 120))
    )
  }

  private func makeImage() throws -> CGImage {
    guard
      let context = CGContext(
        data: nil,
        width: 320,
        height: 180,
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

  private struct Context {
    let coordinator: CaptureCoordinator
    let permission: StubScreenCapturePermissionService
    let selection: StubRegionSelectionService
    let screenCapture: StubScreenCaptureService
    let ocr: StubOCRService
    let textAssembler: SpyTextAssembler
    let clipboard: SpyClipboardService
    let sound: SpySuccessSoundPlayer
    let feedback: SpyFeedbackService
    let recovery: SpyPermissionRecoveryPresenter
    let scheduler: IntegrationWorkScheduler
    let command: CaptureCommand
  }
}

@MainActor
private final class IntegrationWorkScheduler {
  private var pendingWork: [CaptureCommand.Work] = []
  private(set) var scheduledCount = 0

  var schedule: CaptureCommand.WorkScheduler {
    { [weak self] work in
      self?.scheduledCount += 1
      self?.pendingWork.append(work)
    }
  }

  func runNext() async {
    guard !pendingWork.isEmpty else {
      return XCTFail("Expected scheduled workflow work")
    }
    await pendingWork.removeFirst()()
  }

  func waitUntilScheduledCount(_ count: Int) async {
    while scheduledCount < count {
      await Task.yield()
    }
  }
}

@MainActor
private final class IntegrationVisibleFeedbackService: FeedbackService {
  private(set) var presentedFeedback: [CaptureFeedback] = []
  private(set) var isVisible = false
  private(set) var dismissCallCount = 0

  func present(_ feedback: CaptureFeedback) throws {
    presentedFeedback.append(feedback)
    isVisible = true
  }

  func dismiss() {
    guard isVisible else { return }
    isVisible = false
    dismissCallCount += 1
  }
}

private actor EphemeralScreenCaptureService: ScreenCaptureService {
  private let imageReference = WeakWorkflowImageReference()

  func capture(_ selection: SelectionResult) async throws -> CGImage {
    guard
      let context = CGContext(
        data: nil,
        width: 320,
        height: 180,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ),
      let image = context.makeImage()
    else {
      throw TestServiceError.injected
    }
    imageReference.image = image
    return image
  }

  func imageWasReleased() -> Bool {
    imageReference.image == nil
  }
}

private final class WeakWorkflowImageReference: @unchecked Sendable {
  weak var image: CGImage?
}

@MainActor
private final class NoopApplicationTerminator: ApplicationTerminating {
  func terminate() {}
}
