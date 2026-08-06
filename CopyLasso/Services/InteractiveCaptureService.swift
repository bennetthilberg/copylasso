import CoreGraphics

enum InteractiveCaptureOutcome: @unchecked Sendable {
  case captured(CGImage)
  case cancelled(SelectionCancellationReason)
}

enum InteractiveCaptureError: Error, Equatable, Sendable {
  case permissionDenied
  case processFailed(status: Int32)
  case invalidImage
  case captureFailed
}

@MainActor
protocol InteractiveCaptureService: AnyObject {
  func prepareForCaptureTransition()
  func capture() async throws -> InteractiveCaptureOutcome
  func cancelCapture()
}
