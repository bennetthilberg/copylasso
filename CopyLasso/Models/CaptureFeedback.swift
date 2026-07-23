enum CaptureFeedback: Equatable, Sendable {
  case success(preview: String)
  case noText
  case codeSuccess(preview: String)
  case noCode
  case ambiguousCodes
  case failure(CaptureFailureStage)
  case codeFailure(CaptureFailureStage)
}
