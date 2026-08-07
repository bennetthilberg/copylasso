import AppKit
import CoreGraphics
import ScreenCaptureKit

extension ScreenCapturePermissionClient {
  static let live = ScreenCapturePermissionClient(
    preflight: { CGPreflightScreenCaptureAccess() },
    authoritativePreflight: {
      do {
        _ = try await SCShareableContent.current
        return true
      } catch {
        return false
      }
    },
    request: { CGRequestScreenCaptureAccess() },
    openURL: { NSWorkspace.shared.open($0) }
  )
}
