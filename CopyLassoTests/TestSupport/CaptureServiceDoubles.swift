import CoreGraphics

@testable import CopyLasso

enum TestServiceError: Error, Equatable, Sendable {
  case injected
}

@MainActor
final class StubScreenCapturePermissionService: ScreenCapturePermissionService {
  var currentResult: ScreenCaptureAuthorizationObservation
  var requestResult: ScreenCaptureAuthorizationObservation
  private(set) var currentObservationCallCount = 0
  private(set) var requestAccessCallCount = 0

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

  init(result: Result<[RecognizedTextObservation], TestServiceError>) {
    self.result = result
  }

  func recognizeText(in image: CGImage) async throws -> [RecognizedTextObservation] {
    recognitionCallCount += 1
    return try result.get()
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

  func present(_ feedback: CaptureFeedback) async throws {
    if let error {
      throw error
    }
    presentedFeedback.append(feedback)
  }
}
