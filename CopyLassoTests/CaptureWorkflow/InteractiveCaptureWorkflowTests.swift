import CoreGraphics
import XCTest

@testable import CopyLasso

@MainActor
final class InteractiveCaptureWorkflowTests: XCTestCase {
  func testShortcutStartsInteractiveSelectorSynchronouslyThenCopiesRecognizedText() async throws {
    let image = try makeImage()
    let capture = StubInteractiveCaptureService(result: .success(.captured(image)))
    let context = makeContext(capture: capture)

    XCTAssertEqual(
      context.command.performFromGlobalShortcut(),
      .transitioned(from: .idle, to: .requestingPermission)
    )

    XCTAssertEqual(capture.prepareCallCount, 1)
    XCTAssertEqual(capture.captureCallCount, 0)
    await context.scheduler.runNext()

    XCTAssertEqual(capture.captureCallCount, 1)
    XCTAssertEqual(context.permission.recordCaptureSuccessCallCount, 1)
    XCTAssertEqual(context.clipboard.writtenTexts, ["system selector text"])
    XCTAssertEqual(context.sound.playCallCount, 1)
    XCTAssertEqual(
      context.feedback.presentedFeedback,
      [.success(preview: "system selector text")]
    )
    XCTAssertEqual(context.coordinator.state, .idle)
  }

  func testMenuCaptureStartsSelectorDuringScheduledWork() async throws {
    let capture = StubInteractiveCaptureService(result: .success(.cancelled(.escape)))
    let context = makeContext(capture: capture)

    _ = context.command.perform()

    XCTAssertEqual(capture.prepareCallCount, 0)
    await context.scheduler.runNext()
    XCTAssertEqual(capture.prepareCallCount, 1)
    XCTAssertEqual(capture.captureCallCount, 1)
    XCTAssertEqual(context.coordinator.state, .idle)
  }

  func testInteractiveCancellationPreservesClipboardAndRemainsSilent() async throws {
    let capture = StubInteractiveCaptureService(result: .success(.cancelled(.escape)))
    let context = makeContext(capture: capture)

    _ = context.command.performFromGlobalShortcut()
    await context.scheduler.runNext()

    XCTAssertTrue(context.clipboard.writtenTexts.isEmpty)
    XCTAssertEqual(context.sound.playCallCount, 0)
    XCTAssertTrue(context.feedback.presentedFeedback.isEmpty)
    XCTAssertEqual(context.permission.recordCaptureSuccessCallCount, 0)
    XCTAssertEqual(context.coordinator.state, .idle)
  }

  func testEmptySelectionOutputBecomesPermissionRecoveryWhenAccessChanged() async throws {
    let capture = StubInteractiveCaptureService(result: .success(.cancelled(.escape)))
    let context = makeContext(capture: capture)

    _ = context.command.performFromGlobalShortcut()
    context.permission.currentResult = .notGrantedAfterPreviouslyGranted
    await context.scheduler.runNext()

    XCTAssertEqual(context.permission.recordCaptureDenialCallCount, 1)
    XCTAssertEqual(
      context.recovery.presentedObservations,
      [.notGrantedAfterPreviouslyGranted]
    )
    XCTAssertTrue(context.clipboard.writtenTexts.isEmpty)
    XCTAssertEqual(context.sound.playCallCount, 0)
    XCTAssertTrue(context.feedback.presentedFeedback.isEmpty)
    XCTAssertEqual(context.coordinator.state, .idle)
  }

  func testDeniedPermissionNeverStartsInteractiveSelector() async throws {
    let capture = StubInteractiveCaptureService(result: .failure(.captureFailed))
    let context = makeContext(
      capture: capture,
      currentPermission: .notGrantedAfterRequest
    )

    _ = context.command.performFromGlobalShortcut()

    XCTAssertEqual(capture.prepareCallCount, 0)
    await context.scheduler.runNext()
    XCTAssertEqual(capture.captureCallCount, 0)
    XCTAssertEqual(
      context.recovery.presentedObservations,
      [.notGrantedAfterRequest]
    )
    XCTAssertEqual(context.coordinator.state, .idle)
  }

  func testInteractivePermissionFailureUsesExistingRecoveryFlow() async throws {
    let capture = StubInteractiveCaptureService(result: .failure(.permissionDenied))
    let context = makeContext(capture: capture)

    _ = context.command.performFromGlobalShortcut()
    await context.scheduler.runNext()

    XCTAssertEqual(context.permission.recordCaptureDenialCallCount, 1)
    XCTAssertEqual(
      context.recovery.presentedObservations,
      [.notGrantedAfterPreviouslyGranted]
    )
    XCTAssertTrue(context.feedback.presentedFeedback.isEmpty)
    XCTAssertEqual(context.coordinator.state, .idle)
  }

  func testInteractiveCaptureFailurePreservesClipboardAndShowsCaptureFailure() async throws {
    let capture = StubInteractiveCaptureService(result: .failure(.captureFailed))
    let context = makeContext(capture: capture)

    _ = context.command.performFromGlobalShortcut()
    await context.scheduler.runNext()

    XCTAssertTrue(context.clipboard.writtenTexts.isEmpty)
    XCTAssertEqual(context.sound.playCallCount, 0)
    XCTAssertEqual(context.feedback.presentedFeedback, [.failure(.capture)])
    XCTAssertEqual(context.permission.recordCaptureSuccessCallCount, 0)
    XCTAssertEqual(context.coordinator.state, .idle)
  }

  func testCancellingActiveInteractiveSelectionTerminatesItsSession() async throws {
    let capture = StubInteractiveCaptureService(result: .success(.cancelled(.escape)))
    let context = makeContext(capture: capture)

    _ = context.command.performFromGlobalShortcut()
    XCTAssertTrue(context.command.cancelActiveOperation(reason: .systemInterrupted))

    XCTAssertEqual(capture.cancelCallCount, 1)
    await context.scheduler.runNext()
    XCTAssertEqual(context.coordinator.state, .idle)
    XCTAssertTrue(context.clipboard.writtenTexts.isEmpty)
  }

  private func makeContext(
    capture: StubInteractiveCaptureService,
    currentPermission: ScreenCaptureAuthorizationObservation = .granted
  ) -> Context {
    let coordinator = CaptureCoordinator()
    let permission = StubScreenCapturePermissionService(
      currentResult: currentPermission,
      requestResult: currentPermission
    )
    let clipboard = SpyClipboardService()
    let sound = SpySuccessSoundPlayer()
    let feedback = SpyFeedbackService()
    let recovery = SpyPermissionRecoveryPresenter()
    let scheduler = InteractiveCaptureWorkScheduler()
    let command = CaptureCommand(
      coordinator: coordinator,
      permissionService: permission,
      interactiveCaptureService: capture,
      ocrService: StubOCRService(
        result: .success([
          RecognizedTextObservation(
            text: "system selector text",
            confidence: 0.99,
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.7, height: 0.2)
          )
        ])
      ),
      textAssembler: SpyTextAssembler(result: "system selector text"),
      barcodeService: StubBarcodeRecognitionService(result: .success([])),
      clipboardService: clipboard,
      successSoundPlayer: sound,
      feedbackService: feedback,
      recoveryPresenter: recovery,
      scheduleWork: scheduler.schedule
    )
    return Context(
      command: command,
      coordinator: coordinator,
      permission: permission,
      clipboard: clipboard,
      sound: sound,
      feedback: feedback,
      recovery: recovery,
      scheduler: scheduler
    )
  }

  private func makeImage() throws -> CGImage {
    let context = try XCTUnwrap(
      CGContext(
        data: nil,
        width: 320,
        height: 180,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    )
    return try XCTUnwrap(context.makeImage())
  }

  private struct Context {
    let command: CaptureCommand
    let coordinator: CaptureCoordinator
    let permission: StubScreenCapturePermissionService
    let clipboard: SpyClipboardService
    let sound: SpySuccessSoundPlayer
    let feedback: SpyFeedbackService
    let recovery: SpyPermissionRecoveryPresenter
    let scheduler: InteractiveCaptureWorkScheduler
  }
}

@MainActor
private final class StubInteractiveCaptureService: InteractiveCaptureService {
  var result: Result<InteractiveCaptureOutcome, InteractiveCaptureError>
  private(set) var prepareCallCount = 0
  private(set) var captureCallCount = 0
  private(set) var cancelCallCount = 0

  init(result: Result<InteractiveCaptureOutcome, InteractiveCaptureError>) {
    self.result = result
  }

  func prepareForCaptureTransition() {
    prepareCallCount += 1
  }

  func capture() async throws -> InteractiveCaptureOutcome {
    captureCallCount += 1
    return try result.get()
  }

  func cancelCapture() {
    cancelCallCount += 1
  }
}

@MainActor
private final class InteractiveCaptureWorkScheduler {
  private var scheduledWork: [CaptureCommand.Work] = []

  lazy var schedule: CaptureCommand.WorkScheduler = { [weak self] work in
    self?.scheduledWork.append(work)
  }

  func runNext() async {
    guard !scheduledWork.isEmpty else { return }
    let work = scheduledWork.removeFirst()
    await work()
  }
}
