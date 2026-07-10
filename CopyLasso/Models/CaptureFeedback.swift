enum CaptureFeedback: Equatable, Sendable {
  case success(preview: String)
  case noText
  case failure(CaptureFailureStage)
}
