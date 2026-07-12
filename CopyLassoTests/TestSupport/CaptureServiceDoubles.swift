import CoreGraphics
import Foundation

@testable import CopyLasso

enum TestServiceError: Error, Equatable, Sendable {
  case injected
}

@MainActor
final class StubScreenCapturePermissionService: ScreenCapturePermissionService {
  var currentResult: ScreenCaptureAuthorizationObservation
  var requestResult: ScreenCaptureAuthorizationObservation
  var openSystemSettingsResult = true
  private(set) var currentObservationCallCount = 0
  private(set) var requestAccessCallCount = 0
  private(set) var recordCaptureDenialCallCount = 0
  private(set) var recordCaptureSuccessCallCount = 0
  private(set) var beginUserInitiatedRetryCallCount = 0
  private(set) var openSystemSettingsCallCount = 0

  init(
    currentResult: ScreenCaptureAuthorizationObservation,
    requestResult: ScreenCaptureAuthorizationObservation
  ) {
    self.currentResult = currentResult
    self.requestResult = requestResult
  }

  func currentObservation() -> ScreenCaptureAuthorizationObservation {
    currentObservationCallCount += 1
    return currentResult
  }

  func requestAccess() -> ScreenCaptureAuthorizationObservation {
    requestAccessCallCount += 1
    return requestResult
  }

  func recordCaptureDenial() -> ScreenCaptureAuthorizationObservation {
    recordCaptureDenialCallCount += 1
    return .notGrantedAfterPreviouslyGranted
  }

  func recordCaptureSuccess() {
    recordCaptureSuccessCallCount += 1
  }

  func beginUserInitiatedRetry() {
    beginUserInitiatedRetryCallCount += 1
  }

  func openSystemSettings() -> Bool {
    openSystemSettingsCallCount += 1
    return openSystemSettingsResult
  }
}

@MainActor
final class SpyPermissionRecoveryPresenter: PermissionRecoveryPresenting {
  private(set) var presentedObservations: [ScreenCaptureAuthorizationObservation] = []
  private(set) var dismissCallCount = 0

  func present(_ observation: ScreenCaptureAuthorizationObservation) {
    presentedObservations.append(observation)
  }

  func dismiss() {
    dismissCallCount += 1
  }
}

@MainActor
final class StubRegionSelectionService: RegionSelectionService {
  var result: Result<SelectionOutcome, TestServiceError>
  private(set) var selectRegionCallCount = 0
  private(set) var cancelSelectionCallCount = 0

  init(result: Result<SelectionOutcome, TestServiceError>) {
    self.result = result
  }

  func selectRegion() async throws -> SelectionOutcome {
    selectRegionCallCount += 1
    return try result.get()
  }

  func cancelSelection() {
    cancelSelectionCallCount += 1
  }
}

actor StubScreenCaptureService: ScreenCaptureService {
  var result: Result<CGImage, TestServiceError>
  private(set) var selections: [SelectionResult] = []

  init(result: Result<CGImage, TestServiceError>) {
    self.result = result
  }

  func capture(_ selection: SelectionResult) async throws -> CGImage {
    selections.append(selection)
    return try result.get()
  }
}

actor StubOCRService: OCRService {
  var result: Result<[RecognizedTextObservation], TestServiceError>
  private(set) var recognitionCallCount = 0
  private(set) var recognizedImageSizes: [CGSize] = []

  init(result: Result<[RecognizedTextObservation], TestServiceError>) {
    self.result = result
  }

  func recognizeText(in image: CGImage) async throws -> [RecognizedTextObservation] {
    recognitionCallCount += 1
    recognizedImageSizes.append(CGSize(width: image.width, height: image.height))
    return try result.get()
  }
}

final class SpyTextAssembler: TextAssembling, @unchecked Sendable {
  private let lock = NSLock()
  private let result: String
  private var storedInputs: [[RecognizedTextObservation]] = []

  init(result: String) {
    self.result = result
  }

  var inputs: [[RecognizedTextObservation]] {
    lock.withLock { storedInputs }
  }

  func assemble(_ observations: [RecognizedTextObservation]) -> String {
    lock.withLock { storedInputs.append(observations) }
    return result
  }
}

@MainActor
final class SpyClipboardService: ClipboardService {
  var error: TestServiceError?
  private(set) var writtenTexts: [String] = []

  func writePlainText(_ text: String) throws {
    if let error {
      throw error
    }
    writtenTexts.append(text)
  }
}

@MainActor
final class SpyFeedbackService: FeedbackService {
  var error: TestServiceError?
  private(set) var presentedFeedback: [CaptureFeedback] = []
  private(set) var dismissCallCount = 0
  private(set) var isVisible = false

  func present(_ feedback: CaptureFeedback) throws {
    if let error {
      throw error
    }
    presentedFeedback.append(feedback)
    isVisible = true
  }

  func dismiss() {
    guard isVisible else { return }
    dismissCallCount += 1
    isVisible = false
  }
}

@MainActor
func makeTestCaptureCommand(
  coordinator: CaptureCoordinator,
  scheduleWork: @escaping CaptureCommand.WorkScheduler,
  feedbackService: any FeedbackService = SpyFeedbackService()
) -> CaptureCommand {
  CaptureCommand(
    coordinator: coordinator,
    permissionService: StubScreenCapturePermissionService(
      currentResult: .granted,
      requestResult: .granted
    ),
    selectionService: StubRegionSelectionService(result: .failure(.injected)),
    screenCaptureService: StubScreenCaptureService(result: .failure(.injected)),
    ocrService: StubOCRService(result: .failure(.injected)),
    textAssembler: TextAssembler(),
    clipboardService: SpyClipboardService(),
    feedbackService: feedbackService,
    recoveryPresenter: SpyPermissionRecoveryPresenter(),
    scheduleWork: scheduleWork
  )
}
