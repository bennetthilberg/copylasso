import AppKit
import CoreGraphics
import ScreenCaptureKit

enum SystemScreenCapturePermissionProbe {
  static func classify(_ error: any Error) -> ScreenCaptureAuthoritativePreflightResult {
    let error = error as NSError
    guard
      error.domain == SCStreamErrorDomain,
      error.code == SCStreamError.Code.userDeclined.rawValue
    else {
      return .unavailable
    }
    return .denied
  }
}

extension ScreenCapturePermissionClient {
  static let live = ScreenCapturePermissionClient(
    preflight: { CGPreflightScreenCaptureAccess() },
    authoritativePreflight: {
      do {
        _ = try await SCShareableContent.current
        return .granted
      } catch {
        return SystemScreenCapturePermissionProbe.classify(error)
      }
    },
    request: { CGRequestScreenCaptureAccess() },
    openURL: { NSWorkspace.shared.open($0) }
  )
}
