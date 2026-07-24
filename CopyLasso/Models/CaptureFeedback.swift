enum CaptureFeedback: Equatable, Sendable {
  case success(preview: String)
  case codeSuccess(preview: String)
  case noContent
  case ambiguousCodes
  case failure(CaptureFailureStage)
}
