struct ScreenCapturePermissionHistory: Equatable, Sendable {
  var hasRequested = false
  var hasObservedGranted = false

  func observation(preflightGranted: Bool) -> ScreenCaptureAuthorizationObservation {
    if preflightGranted {
      return .granted
    }
    if hasObservedGranted {
      return .notGrantedAfterPreviouslyGranted
    }
    if hasRequested {
      return .notGrantedAfterRequest
    }
    return .notGrantedNeverRequested
  }
}

@MainActor
protocol ScreenCapturePermissionHistoryStoring: AnyObject {
  var history: ScreenCapturePermissionHistory { get set }
  func reset()
}
