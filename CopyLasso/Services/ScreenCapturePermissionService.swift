import AppKit
import CoreGraphics

@MainActor
protocol ScreenCapturePermissionService: AnyObject {
  func currentObservation() -> ScreenCaptureAuthorizationObservation
  func requestAccess() -> ScreenCaptureAuthorizationObservation
  func recordCaptureDenial() -> ScreenCaptureAuthorizationObservation
  func openSystemSettings() -> Bool
}

@MainActor
struct ScreenCapturePermissionClient {
  static let screenRecordingSettingsURL = URL(
    string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
  )!

  let preflight: () -> Bool
  let request: () -> Bool
  let openURL: (URL) -> Bool

  static let live = ScreenCapturePermissionClient(
    preflight: { CGPreflightScreenCaptureAccess() },
    request: { CGRequestScreenCaptureAccess() },
    openURL: { NSWorkspace.shared.open($0) }
  )
}

@MainActor
final class SystemScreenCapturePermissionService: ScreenCapturePermissionService {
  private let historyStore: any ScreenCapturePermissionHistoryStoring
  private let client: ScreenCapturePermissionClient
  private var hasAuthoritativeCaptureDenial = false

  init(
    historyStore: any ScreenCapturePermissionHistoryStoring,
    client: ScreenCapturePermissionClient = .live
  ) {
    self.historyStore = historyStore
    self.client = client
  }

  func currentObservation() -> ScreenCaptureAuthorizationObservation {
    if hasAuthoritativeCaptureDenial {
      return .notGrantedAfterPreviouslyGranted
    }
    return observation(granted: client.preflight())
  }

  func requestAccess() -> ScreenCaptureAuthorizationObservation {
    var history = historyStore.history
    history.hasRequested = true
    historyStore.history = history
    return observation(granted: client.request())
  }

  func recordCaptureDenial() -> ScreenCaptureAuthorizationObservation {
    hasAuthoritativeCaptureDenial = true
    var history = historyStore.history
    history.hasRequested = true
    history.hasObservedGranted = true
    historyStore.history = history
    return .notGrantedAfterPreviouslyGranted
  }

  func openSystemSettings() -> Bool {
    client.openURL(ScreenCapturePermissionClient.screenRecordingSettingsURL)
  }

  private func observation(granted: Bool) -> ScreenCaptureAuthorizationObservation {
    var history = historyStore.history
    if granted {
      history.hasObservedGranted = true
      historyStore.history = history
    }
    return history.observation(preflightGranted: granted)
  }
}
