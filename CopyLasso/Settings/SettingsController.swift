import KeyboardShortcuts
import Observation

enum OnboardingCompletionResult: Equatable, Sendable {
  case completed
  case requiresRecovery
}

enum LaunchAtLoginIssue: Equatable, Sendable {
  case requiresApproval
  case unavailable
  case enableFailed
  case disableFailed
}

@MainActor
@Observable
final class SettingsController {
  static let currentOnboardingVersion = 1

  private let settingsStore: any AppSettingsStoring
  private let launchAtLoginService: any LaunchAtLoginServicing
  private let shortcutStore: any GlobalShortcutStoring
  private let currentOnboardingVersion: Int
  private var presentedInitialOnboarding = false

  private(set) var launchAtLoginStatus: LaunchAtLoginStatus
  private(set) var launchAtLoginIssue: LaunchAtLoginIssue?

  var needsOnboarding: Bool {
    settingsStore.completedOnboardingVersion < currentOnboardingVersion
  }

  var isLaunchAtLoginEnabled: Bool {
    launchAtLoginStatus == .enabled
  }

  init(
    settingsStore: any AppSettingsStoring,
    launchAtLoginService: any LaunchAtLoginServicing,
    shortcutStore: any GlobalShortcutStoring,
    currentOnboardingVersion: Int = SettingsController.currentOnboardingVersion
  ) {
    self.settingsStore = settingsStore
    self.launchAtLoginService = launchAtLoginService
    self.shortcutStore = shortcutStore
    self.currentOnboardingVersion = currentOnboardingVersion
    launchAtLoginStatus = launchAtLoginService.status
    launchAtLoginIssue = Self.issue(for: launchAtLoginService.status)
  }

  func takeInitialOnboardingPresentationRequest() -> Bool {
    guard needsOnboarding, !presentedInitialOnboarding else {
      return false
    }
    presentedInitialOnboarding = true
    return true
  }

  func requestOnboardingFromSettings() -> Bool {
    needsOnboarding
  }

  func onboardingClosed() {
    launchAtLoginIssue = Self.issue(for: launchAtLoginStatus)
  }

  func completeOnboarding(
    shortcut: KeyboardShortcuts.Shortcut?,
    launchAtLogin: Bool
  ) -> OnboardingCompletionResult {
    if launchAtLogin {
      guard enableLaunchAtLogin() else {
        return .requiresRecovery
      }
    } else {
      guard disableLaunchAtLogin(allowUnavailable: true) else {
        return .requiresRecovery
      }
    }

    commitOnboarding(shortcut: shortcut)
    return .completed
  }

  func continueWithoutLaunchAtLogin(
    shortcut: KeyboardShortcuts.Shortcut?
  ) -> OnboardingCompletionResult {
    guard disableLaunchAtLogin(allowUnavailable: true) else {
      return .requiresRecovery
    }
    commitOnboarding(shortcut: shortcut)
    return .completed
  }

  @discardableResult
  func setLaunchAtLoginEnabled(_ enabled: Bool) -> Bool {
    enabled ? enableLaunchAtLogin() : disableLaunchAtLogin(allowUnavailable: false)
  }

  func refreshLaunchAtLoginStatus() {
    launchAtLoginStatus = launchAtLoginService.status
    launchAtLoginIssue = Self.issue(for: launchAtLoginStatus)
  }

  func openLoginItemsSettings() {
    launchAtLoginService.openSystemSettings()
  }

  #if DEBUG
    @discardableResult
    func resetLocalDevelopmentState() -> Bool {
      guard disableLaunchAtLogin(allowUnavailable: true) else {
        return false
      }
      settingsStore.reset()
      shortcutStore.reset()
      presentedInitialOnboarding = false
      return true
    }
  #endif

  private func enableLaunchAtLogin() -> Bool {
    refreshLaunchAtLoginStatus()
    if launchAtLoginStatus == .enabled {
      return true
    }
    if launchAtLoginStatus == .requiresApproval {
      launchAtLoginIssue = .requiresApproval
      return false
    }
    if launchAtLoginStatus == .unavailable {
      launchAtLoginIssue = .unavailable
      return false
    }

    do {
      try launchAtLoginService.enable()
    } catch {
      launchAtLoginStatus = launchAtLoginService.status
      launchAtLoginIssue = .enableFailed
      return false
    }

    launchAtLoginStatus = launchAtLoginService.status
    guard launchAtLoginStatus == .enabled else {
      launchAtLoginIssue = Self.issue(for: launchAtLoginStatus) ?? .enableFailed
      return false
    }
    launchAtLoginIssue = nil
    return true
  }

  private func disableLaunchAtLogin(allowUnavailable: Bool) -> Bool {
    refreshLaunchAtLoginStatus()
    if launchAtLoginStatus == .disabled {
      do {
        try launchAtLoginService.disable()
      } catch {
        launchAtLoginStatus = launchAtLoginService.status
        launchAtLoginIssue = .disableFailed
        return false
      }
      refreshLaunchAtLoginStatus()
      return launchAtLoginStatus == .disabled
    }
    if launchAtLoginStatus == .unavailable, allowUnavailable {
      launchAtLoginIssue = nil
      return true
    }

    do {
      try launchAtLoginService.disable()
    } catch {
      launchAtLoginStatus = launchAtLoginService.status
      launchAtLoginIssue = .disableFailed
      return false
    }

    launchAtLoginStatus = launchAtLoginService.status
    guard launchAtLoginStatus == .disabled else {
      launchAtLoginIssue = .disableFailed
      return false
    }
    launchAtLoginIssue = nil
    return true
  }

  private func commitOnboarding(shortcut: KeyboardShortcuts.Shortcut?) {
    shortcutStore.captureShortcut = shortcut
    settingsStore.completedOnboardingVersion = currentOnboardingVersion
    launchAtLoginIssue = Self.issue(for: launchAtLoginStatus)
  }

  private static func issue(for status: LaunchAtLoginStatus) -> LaunchAtLoginIssue? {
    switch status {
    case .requiresApproval:
      .requiresApproval
    case .unavailable:
      .unavailable
    case .disabled, .enabled:
      nil
    }
  }
}
