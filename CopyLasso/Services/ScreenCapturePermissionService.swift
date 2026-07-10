@MainActor
protocol ScreenCapturePermissionService: AnyObject {
  func currentObservation() -> ScreenCaptureAuthorizationObservation
  func requestAccess() -> ScreenCaptureAuthorizationObservation
}
