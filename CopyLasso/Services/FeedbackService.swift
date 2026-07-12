@MainActor
protocol FeedbackService: AnyObject {
  func present(_ feedback: CaptureFeedback) throws
  func dismiss()
}
