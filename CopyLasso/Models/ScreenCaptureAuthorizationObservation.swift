enum ScreenCaptureAuthorizationObservation: Equatable, Sendable {
  case granted
  case notGrantedNeverRequested
  case notGrantedAfterRequest
  case notGrantedAfterPreviouslyGranted
}
