import CoreGraphics

enum PendingScreenCaptureError: Error, Equatable, Sendable {
  case unavailableUntilG14
}

actor PendingScreenCaptureService: ScreenCaptureService {
  func capture(_ selection: SelectionResult) async throws -> CGImage {
    throw PendingScreenCaptureError.unavailableUntilG14
  }
}
