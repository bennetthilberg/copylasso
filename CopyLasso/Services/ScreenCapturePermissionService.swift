import Foundation

@MainActor
protocol ScreenCapturePermissionService: AnyObject {
  func currentObservation() -> ScreenCaptureAuthorizationObservation
  func authoritativeObservation() async -> ScreenCaptureAuthorizationObservation
  func requestAccess() -> ScreenCaptureAuthorizationObservation
  func recordCaptureDenial() -> ScreenCaptureAuthorizationObservation
  func recordCaptureSuccess()
  func beginUserInitiatedRetry()
  func openSystemSettings() -> Bool
}

extension ScreenCapturePermissionService {
  func authoritativeObservation() async -> ScreenCaptureAuthorizationObservation {
    currentObservation()
  }

  func recordCaptureSuccess() {}
  func beginUserInitiatedRetry() {}
}

@MainActor
struct ScreenCapturePermissionClient {
  static let screenRecordingSettingsURL = URL(
    string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
  )!

  let preflight: () -> Bool
  let authoritativePreflight: () async -> Bool
  let request: () -> Bool
  let openURL: (URL) -> Bool

  init(
    preflight: @escaping () -> Bool,
    authoritativePreflight: (() async -> Bool)? = nil,
    request: @escaping () -> Bool,
    openURL: @escaping (URL) -> Bool
  ) {
    self.preflight = preflight
    self.authoritativePreflight = authoritativePreflight ?? { preflight() }
    self.request = request
    self.openURL = openURL
  }

}

@MainActor
final class SystemScreenCapturePermissionService: ScreenCapturePermissionService {
  private let historyStore: any ScreenCapturePermissionHistoryStoring
  private let client: ScreenCapturePermissionClient
  private var hasAuthoritativeCaptureDenial = false
  private var hasUserInitiatedObservationRetry = false

  init(
    historyStore: any ScreenCapturePermissionHistoryStoring,
    client: ScreenCapturePermissionClient = .live
  ) {
    self.historyStore = historyStore
    self.client = client
  }

  func currentObservation() -> ScreenCaptureAuthorizationObservation {
    if hasAuthoritativeCaptureDenial {
      guard hasUserInitiatedObservationRetry else {
        return .notGrantedAfterPreviouslyGranted
      }
      hasUserInitiatedObservationRetry = false
    }
    return observation(granted: client.preflight())
  }

  func authoritativeObservation() async -> ScreenCaptureAuthorizationObservation {
    observation(granted: await client.authoritativePreflight())
  }

  func requestAccess() -> ScreenCaptureAuthorizationObservation {
    var history = historyStore.history
    history.hasRequested = true
    historyStore.history = history
    return observation(granted: client.request())
  }

  func recordCaptureDenial() -> ScreenCaptureAuthorizationObservation {
    hasAuthoritativeCaptureDenial = true
    hasUserInitiatedObservationRetry = false
    var history = historyStore.history
    history.hasRequested = true
    history.hasObservedGranted = true
    historyStore.history = history
    return .notGrantedAfterPreviouslyGranted
  }

  func recordCaptureSuccess() {
    hasAuthoritativeCaptureDenial = false
    hasUserInitiatedObservationRetry = false
  }

  func beginUserInitiatedRetry() {
    guard hasAuthoritativeCaptureDenial else {
      return
    }
    hasUserInitiatedObservationRetry = true
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
