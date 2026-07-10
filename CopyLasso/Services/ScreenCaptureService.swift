import CoreGraphics

protocol ScreenCaptureService: Sendable {
  func capture(_ selection: SelectionResult) async throws -> CGImage
}
