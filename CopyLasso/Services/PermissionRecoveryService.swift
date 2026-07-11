@MainActor
protocol PermissionRecoveryPresenting: AnyObject {
  func present(_ observation: ScreenCaptureAuthorizationObservation)
  func dismiss()
}

@MainActor
protocol CaptureRequesting: AnyObject {
  @discardableResult
  func perform() -> CaptureTransitionResult
}
