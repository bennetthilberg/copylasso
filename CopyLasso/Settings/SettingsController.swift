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

  private(set) var captureShortcut: KeyboardShortcuts.Shortcut?
  private(set) var captureCodeShortcut: KeyboardShortcuts.Shortcut?
  private(set) var launchAtLoginStatus: LaunchAtLoginStatus
  private(set) var launchAtLoginIssue: LaunchAtLoginIssue?
  private(set) var isSuccessSoundEnabled: Bool

  var needsOnboarding: Bool {
    settingsStore.completedOnboardingVersion < currentOnboardingVersion
  }

  var isLaunchAtLoginEnabled: Bool {
    launchAtLoginStatus == .enabled
  }

  var onboardingShortcutDraft: KeyboardShortcuts.Shortcut? {
    settingsStore.hasConfiguredCaptureShortcut
      ? captureShortcut
      : CaptureShortcutDefaults.suggested
  }

  var onboardingLaunchAtLoginDraft: Bool {
    settingsStore.hasConfiguredLaunchAtLogin ? isLaunchAtLoginEnabled : true
  }

  init(
    settingsStore: any AppSettingsStoring,
    launchAtLoginService: any LaunchAtLoginServicing,
    shortcutStore: any GlobalShortcutStoring,
    currentOnboardingVersion: Int = SettingsController.currentOnboardingVersion
  ) {
    settingsStore.migrateSuccessSoundPreferenceIfNeeded()
    self.settingsStore = settingsStore
    self.launchAtLoginService = launchAtLoginService
    self.shortcutStore = shortcutStore
    self.currentOnboardingVersion = currentOnboardingVersion
    captureShortcut = shortcutStore.captureShortcut
    captureCodeShortcut = shortcutStore.captureCodeShortcut
    launchAtLoginStatus = launchAtLoginService.status
    launchAtLoginIssue = Self.issue(for: launchAtLoginService.status)
    isSuccessSoundEnabled = settingsStore.isSuccessSoundEnabled
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
    settingsStore.hasConfiguredLaunchAtLogin = true
    return enabled ? enableLaunchAtLogin() : disableLaunchAtLogin(allowUnavailable: false)
  }

  func setCaptureShortcut(_ shortcut: KeyboardShortcuts.Shortcut?) {
    shortcutStore.captureShortcut = shortcut
    captureShortcut = shortcut
    settingsStore.hasConfiguredCaptureShortcut = true
  }

  func setCaptureCodeShortcut(_ shortcut: KeyboardShortcuts.Shortcut?) {
    shortcutStore.captureCodeShortcut = shortcut
    captureCodeShortcut = shortcut
  }

  func setSuccessSoundEnabled(_ enabled: Bool) {
    settingsStore.isSuccessSoundEnabled = enabled
    isSuccessSoundEnabled = settingsStore.isSuccessSoundEnabled
  }

  func useSuggestedCaptureShortcut() {
    setCaptureShortcut(CaptureShortcutDefaults.suggested)
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
      settingsStore.migrateSuccessSoundPreferenceIfNeeded()
      shortcutStore.reset()
      captureShortcut = nil
      captureCodeShortcut = nil
      isSuccessSoundEnabled = settingsStore.isSuccessSoundEnabled
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
      guard launchAtLoginStatus == .disabled else {
        launchAtLoginIssue = .disableFailed
        return false
      }
      return true
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
    setCaptureShortcut(shortcut)
    settingsStore.hasConfiguredLaunchAtLogin = true
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
