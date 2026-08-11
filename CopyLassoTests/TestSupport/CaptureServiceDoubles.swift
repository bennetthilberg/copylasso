import CoreGraphics
import Foundation

@testable import CopyLasso

enum TestServiceError: Error, Equatable, Sendable {
  case injected
}

@MainActor
final class StubScreenCapturePermissionService: ScreenCapturePermissionService {
  var currentResult: ScreenCaptureAuthorizationObservation
  var authoritativeResult: ScreenCaptureAuthorizationObservation?
  var authoritativeObservationHandler: (() async -> ScreenCaptureAuthorizationObservation?)?
  var requestResult: ScreenCaptureAuthorizationObservation
  var openSystemSettingsResult = true
  private(set) var currentObservationCallCount = 0
  private(set) var authoritativeObservationCallCount = 0
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

  func authoritativeObservation() async -> ScreenCaptureAuthorizationObservation? {
    authoritativeObservationCallCount += 1
    if let authoritativeObservationHandler {
      return await authoritativeObservationHandler()
    }
    return authoritativeResult ?? currentResult
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
  var onPrepareForSelectionTransition: (() -> Void)?
  private(set) var prepareForSelectionTransitionCallCount = 0
  private(set) var selectRegionCallCount = 0
  private(set) var cancelSelectionCallCount = 0

  init(result: Result<SelectionOutcome, TestServiceError>) {
    self.result = result
  }

  func prepareForSelectionTransition() {
    prepareForSelectionTransitionCallCount += 1
    onPrepareForSelectionTransition?()
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
  private(set) var recognizedPreferences: [OCRRecognitionPreferences] = []

  init(result: Result<[RecognizedTextObservation], TestServiceError>) {
    self.result = result
  }

  func recognizeText(in image: CGImage) async throws -> [RecognizedTextObservation] {
    recognitionCallCount += 1
    recognizedImageSizes.append(CGSize(width: image.width, height: image.height))
    return try result.get()
  }

  func recognizeText(
    in image: CGImage,
    preferences: OCRRecognitionPreferences
  ) async throws -> [RecognizedTextObservation] {
    recognizedPreferences.append(preferences)
    return try await recognizeText(in: image)
  }
}

@MainActor
final class StubOCRRecognitionPreferencesReader: OCRRecognitionPreferencesReading {
  var ocrRecognitionPreferences: OCRRecognitionPreferences

  init(_ preferences: OCRRecognitionPreferences = .englishUS) {
    ocrRecognitionPreferences = preferences
  }
}

actor StubBarcodeRecognitionService: BarcodeRecognitionService {
  var result: Result<[RecognizedCodeObservation], TestServiceError>
  private(set) var recognitionCallCount = 0
  private(set) var recognizedImageSizes: [CGSize] = []

  init(result: Result<[RecognizedCodeObservation], TestServiceError>) {
    self.result = result
  }

  func recognizeCodes(in image: CGImage) async throws -> [RecognizedCodeObservation] {
    recognitionCallCount += 1
    recognizedImageSizes.append(CGSize(width: image.width, height: image.height))
    return try result.get()
  }

  func setResult(_ result: Result<[RecognizedCodeObservation], TestServiceError>) {
    self.result = result
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
  var onWrite: ((String) -> Void)?
  private(set) var writtenTexts: [String] = []

  func writePlainText(_ text: String) throws {
    if let error {
      throw error
    }
    writtenTexts.append(text)
    onWrite?(text)
  }
}

@MainActor
final class SpySuccessSoundPlayer: SuccessSoundPlaying {
  var onPlay: (() -> Void)?
  private(set) var playCallCount = 0
  private(set) var stopCallCount = 0

  func play() {
    playCallCount += 1
    onPlay?()
  }

  func stop() {
    stopCallCount += 1
  }
}

@MainActor
final class SpyFeedbackService: FeedbackService {
  var error: TestServiceError?
  var onPresent: ((CaptureFeedback) -> Void)?
  var onDismiss: (() -> Void)?
  private(set) var presentedFeedback: [CaptureFeedback] = []
  private(set) var dismissCallCount = 0
  private(set) var isVisible = false

  func present(_ feedback: CaptureFeedback) throws {
    if let error {
      throw error
    }
    presentedFeedback.append(feedback)
    onPresent?(feedback)
    isVisible = true
  }

  func dismiss() {
    guard isVisible else { return }
    dismissCallCount += 1
    onDismiss?()
    isVisible = false
  }
}

@MainActor
final class SpyCaptureHistoryRecorder: CaptureHistoryRecording {
  var result: CaptureHistoryRecordingResult = .notEnabled
  var shouldSuspend = false
  var onRecord: ((String, CaptureHistoryContentKind) -> Void)?
  private(set) var requests: [(content: String, kind: CaptureHistoryContentKind)] = []
  private var recordStarted = false
  private var continuation: CheckedContinuation<Void, Never>?

  func record(
    content: String,
    kind: CaptureHistoryContentKind
  ) async -> CaptureHistoryRecordingResult {
    requests.append((content, kind))
    onRecord?(content, kind)
    recordStarted = true
    if shouldSuspend {
      await withCheckedContinuation { continuation in
        self.continuation = continuation
      }
    }
    return result
  }

  func waitUntilRecordStarts() async {
    while !recordStarted {
      await Task.yield()
    }
  }

  func resumeRecord() {
    continuation?.resume()
    continuation = nil
  }
}

@MainActor
func makeTestCaptureCommand(
  coordinator: CaptureCoordinator,
  scheduleWork: @escaping CaptureCommand.WorkScheduler,
  feedbackService: any FeedbackService = SpyFeedbackService(),
  successSoundPlayer: any SuccessSoundPlaying = NoopSuccessSoundPlayer(),
  selectionService: (any RegionSelectionService)? = nil
) -> CaptureCommand {
  CaptureCommand(
    coordinator: coordinator,
    permissionService: StubScreenCapturePermissionService(
      currentResult: .granted,
      requestResult: .granted
    ),
    selectionService: selectionService
      ?? StubRegionSelectionService(result: .failure(.injected)),
    screenCaptureService: StubScreenCaptureService(result: .failure(.injected)),
    ocrService: StubOCRService(result: .failure(.injected)),
    textAssembler: TextAssembler(),
    barcodeService: StubBarcodeRecognitionService(result: .failure(.injected)),
    clipboardService: SpyClipboardService(),
    successSoundPlayer: successSoundPlayer,
    feedbackService: feedbackService,
    recoveryPresenter: SpyPermissionRecoveryPresenter(),
    scheduleWork: scheduleWork
  )
}
