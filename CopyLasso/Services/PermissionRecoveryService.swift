@MainActor
protocol PermissionRecoveryPresenting: AnyObject {
  func present(_ observation: ScreenCaptureAuthorizationObservation)
  func dismiss()
}

@MainActor
protocol CaptureRequesting: AnyObject {
  @discardableResult
  func perform(mode: CaptureMode) -> CaptureTransitionResult
  @discardableResult
  func retryLastRequest() -> CaptureTransitionResult
}

extension CaptureRequesting {
  @discardableResult
  func perform() -> CaptureTransitionResult {
    perform(mode: .text)
  }
}
