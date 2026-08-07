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
    XCTAssertEqual(context.permission.authoritativeObservationCallCount, 1)
  }

  func testPrelaunchSystemInterruptionSkipsPermissionRecoveryProbe() async throws {
    let capture = StubInteractiveCaptureService(
      result: .success(.cancelled(.systemInterrupted))
    )
    let context = makeContext(capture: capture)
    context.permission.authoritativeResult = .notGrantedAfterPreviouslyGranted

    _ = context.command.performFromGlobalShortcut()
    await context.scheduler.runNext()

    XCTAssertTrue(context.clipboard.writtenTexts.isEmpty)
    XCTAssertEqual(context.sound.playCallCount, 0)
    XCTAssertTrue(context.feedback.presentedFeedback.isEmpty)
    XCTAssertEqual(context.permission.authoritativeObservationCallCount, 0)
    XCTAssertEqual(context.permission.recordCaptureDenialCallCount, 0)
    XCTAssertTrue(context.recovery.presentedObservations.isEmpty)
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
    XCTAssertEqual(context.permission.authoritativeObservationCallCount, 1)
  }

  func testEmptySelectionUsesAuthoritativeAccessWhenPreflightRemainsStale() async throws {
    let capture = StubInteractiveCaptureService(result: .success(.cancelled(.escape)))
    let context = makeContext(capture: capture)
    context.permission.authoritativeResult = .notGrantedAfterPreviouslyGranted

    _ = context.command.performFromGlobalShortcut()
    await context.scheduler.runNext()

    XCTAssertEqual(context.permission.authoritativeObservationCallCount, 1)
    XCTAssertEqual(context.permission.recordCaptureDenialCallCount, 1)
    XCTAssertEqual(
      context.recovery.presentedObservations,
      [.notGrantedAfterPreviouslyGranted]
    )
    XCTAssertTrue(context.feedback.presentedFeedback.isEmpty)
  }

  func testInteractivePixelsAreReleasedBeforeFeedbackPresentation() async throws {
    let capture = EphemeralInteractiveCaptureService()
    let feedback = ImageLifetimeFeedbackService(capture: capture)
    let coordinator = CaptureCoordinator()
    let scheduler = InteractiveCaptureWorkScheduler()
    let command = CaptureCommand(
      coordinator: coordinator,
      permissionService: StubScreenCapturePermissionService(
        currentResult: .granted,
        requestResult: .granted
      ),
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
      clipboardService: SpyClipboardService(),
      successSoundPlayer: SpySuccessSoundPlayer(),
      feedbackService: feedback,
      recoveryPresenter: SpyPermissionRecoveryPresenter(),
      scheduleWork: scheduler.schedule
    )

    _ = command.performFromGlobalShortcut()
    await scheduler.runNext()

    XCTAssertEqual(feedback.imageReleaseObservations, [true])
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
    let capture = HoldingInteractiveCaptureService()
    let context = makeContext(capture: capture)
    context.permission.authoritativeResult = .notGrantedAfterPreviouslyGranted

    _ = context.command.performFromGlobalShortcut()
    let scheduledWork = Task { @MainActor in
      await context.scheduler.runNext()
    }
    await capture.waitUntilStarted()
    XCTAssertTrue(context.command.cancelActiveOperation(reason: .systemInterrupted))

    XCTAssertEqual(capture.cancelCallCount, 1)
    await scheduledWork.value
    XCTAssertEqual(context.coordinator.state, .idle)
    XCTAssertTrue(context.clipboard.writtenTexts.isEmpty)
    XCTAssertEqual(context.permission.authoritativeObservationCallCount, 0)
    XCTAssertEqual(context.permission.recordCaptureDenialCallCount, 0)
    XCTAssertTrue(context.recovery.presentedObservations.isEmpty)
  }

  func testCancellationDuringAuthoritativePermissionCheckRemainsSilent() async throws {
    let permission = StubScreenCapturePermissionService(
      currentResult: .granted,
      requestResult: .granted
    )
    let observation = HoldingPermissionObservation()
    permission.authoritativeObservationHandler = {
      await observation.value()
    }
    let capture = StubInteractiveCaptureService(result: .success(.cancelled(.escape)))
    let context = makeContext(capture: capture, permission: permission)

    _ = context.command.performFromGlobalShortcut()
    let scheduledWork = Task { @MainActor in
      await context.scheduler.runNext()
    }
    await observation.waitUntilRequested()
    XCTAssertTrue(context.command.cancelActiveOperation(reason: .systemInterrupted))
    observation.resume(returning: .notGrantedAfterPreviouslyGranted)
    await scheduledWork.value

    XCTAssertEqual(permission.authoritativeObservationCallCount, 1)
    XCTAssertEqual(permission.recordCaptureDenialCallCount, 0)
    XCTAssertTrue(context.recovery.presentedObservations.isEmpty)
    XCTAssertEqual(context.coordinator.state, .idle)
  }

  func testUnavailableAuthoritativePermissionCheckIsACaptureFailureNotADenial() async {
    let permission = StubScreenCapturePermissionService(
      currentResult: .granted,
      requestResult: .granted
    )
    permission.authoritativeObservationHandler = { nil }
    let capture = StubInteractiveCaptureService(result: .success(.cancelled(.escape)))
    let context = makeContext(capture: capture, permission: permission)

    _ = context.command.performFromGlobalShortcut()
    await context.scheduler.runNext()

    XCTAssertEqual(context.permission.authoritativeObservationCallCount, 1)
    XCTAssertEqual(context.permission.recordCaptureDenialCallCount, 0)
    XCTAssertTrue(context.recovery.presentedObservations.isEmpty)
    XCTAssertEqual(context.feedback.presentedFeedback, [.failure(.capture)])
    XCTAssertEqual(context.coordinator.state, .idle)
  }

  private func makeContext(
    capture: any InteractiveCaptureService,
    currentPermission: ScreenCaptureAuthorizationObservation = .granted,
    permission suppliedPermission: StubScreenCapturePermissionService? = nil
  ) -> Context {
    let coordinator = CaptureCoordinator()
    let permission =
      suppliedPermission
      ?? StubScreenCapturePermissionService(
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
private final class HoldingInteractiveCaptureService: InteractiveCaptureService {
  private var continuation: CheckedContinuation<InteractiveCaptureOutcome, Error>?
  private var startWaiters: [CheckedContinuation<Void, Never>] = []
  private(set) var cancelCallCount = 0

  func prepareForCaptureTransition() {}

  func capture() async throws -> InteractiveCaptureOutcome {
    try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation
      let waiters = startWaiters
      startWaiters.removeAll()
      for waiter in waiters {
        waiter.resume()
      }
    }
  }

  func cancelCapture() {
    cancelCallCount += 1
    let continuation = continuation
    self.continuation = nil
    continuation?.resume(returning: .cancelled(.systemInterrupted))
  }

  func waitUntilStarted() async {
    await withCheckedContinuation { continuation in
      if self.continuation != nil {
        continuation.resume()
      } else {
        startWaiters.append(continuation)
      }
    }
  }
}

@MainActor
private final class HoldingPermissionObservation {
  private var continuation: CheckedContinuation<ScreenCaptureAuthorizationObservation, Never>?
  private var requestWaiters: [CheckedContinuation<Void, Never>] = []

  func value() async -> ScreenCaptureAuthorizationObservation {
    await withCheckedContinuation { continuation in
      self.continuation = continuation
      let waiters = requestWaiters
      requestWaiters.removeAll()
      for waiter in waiters {
        waiter.resume()
      }
    }
  }

  func waitUntilRequested() async {
    await withCheckedContinuation { continuation in
      if self.continuation != nil {
        continuation.resume()
      } else {
        requestWaiters.append(continuation)
      }
    }
  }

  func resume(returning observation: ScreenCaptureAuthorizationObservation) {
    let continuation = continuation
    self.continuation = nil
    continuation?.resume(returning: observation)
  }
}

@MainActor
private final class EphemeralInteractiveCaptureService: InteractiveCaptureService {
  private weak var image: CGImage?

  func prepareForCaptureTransition() {}

  func capture() async throws -> InteractiveCaptureOutcome {
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
      throw InteractiveCaptureError.captureFailed
    }
    self.image = image
    return .captured(image)
  }

  func cancelCapture() {}

  func imageWasReleased() -> Bool {
    image == nil
  }
}

@MainActor
private final class ImageLifetimeFeedbackService: FeedbackService {
  private let capture: EphemeralInteractiveCaptureService
  private(set) var imageReleaseObservations: [Bool] = []

  init(capture: EphemeralInteractiveCaptureService) {
    self.capture = capture
  }

  func present(_ feedback: CaptureFeedback) throws {
    imageReleaseObservations.append(capture.imageWasReleased())
  }

  func dismiss() {}
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
