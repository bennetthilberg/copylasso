@MainActor
protocol FeedbackService: AnyObject {
  func present(_ feedback: CaptureFeedback) async throws
  func dismiss()
}
