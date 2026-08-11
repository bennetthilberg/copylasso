import Foundation
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
final class SettingsController: OCRRecognitionPreferencesReading {
  static let currentOnboardingVersion = 1

  private let settingsStore: any AppSettingsStoring
  private let launchAtLoginService: any LaunchAtLoginServicing
  private let shortcutStore: any GlobalShortcutStoring
  private let locale: Locale
  private let currentOnboardingVersion: Int
  private var presentedInitialOnboarding = false

  private(set) var captureShortcut: KeyboardShortcuts.Shortcut?
  private(set) var launchAtLoginStatus: LaunchAtLoginStatus
  private(set) var launchAtLoginIssue: LaunchAtLoginIssue?
  private(set) var isSuccessSoundEnabled: Bool
  private(set) var availableOCRLanguages: [OCRLanguageOption]
  private(set) var ocrRecognitionPreferences: OCRRecognitionPreferences
  private(set) var isOCRLanguageCatalogAvailable: Bool

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

  var ocrLanguageSummary: String {
    let names = ocrRecognitionPreferences.languageIdentifiers.compactMap { identifier in
      availableOCRLanguages.first(where: { $0.identifier == identifier })?.displayName
    }
    guard let first = names.first else {
      return Self.displayName(
        for: OCRRecognitionPreferences.englishUSIdentifier,
        locale: locale
      )
    }
    let additionalCount = names.count - 1
    return additionalCount == 0 ? first : "\(first) + \(additionalCount) more"
  }

  init(
    settingsStore: any AppSettingsStoring,
    launchAtLoginService: any LaunchAtLoginServicing,
    shortcutStore: any GlobalShortcutStoring,
    currentOnboardingVersion: Int = SettingsController.currentOnboardingVersion,
    ocrLanguageCatalog: any OCRLanguageCataloging = VisionOCRLanguageCatalog(),
    locale: Locale = .current
  ) {
    settingsStore.migrateSuccessSoundPreferenceIfNeeded()
    settingsStore.migrateOCRLanguagePreferencesIfNeeded()
    self.settingsStore = settingsStore
    self.launchAtLoginService = launchAtLoginService
    self.shortcutStore = shortcutStore
    self.currentOnboardingVersion = currentOnboardingVersion
    self.locale = locale
    let supportedLanguageIdentifiers: [String]
    do {
      supportedLanguageIdentifiers = try ocrLanguageCatalog.supportedLanguageIdentifiers()
      isOCRLanguageCatalogAvailable = !supportedLanguageIdentifiers.isEmpty
    } catch {
      supportedLanguageIdentifiers = []
      isOCRLanguageCatalogAvailable = false
    }
    let effectiveIdentifiers =
      supportedLanguageIdentifiers.isEmpty
      ? [OCRRecognitionPreferences.englishUSIdentifier]
      : supportedLanguageIdentifiers
    availableOCRLanguages = effectiveIdentifiers.map { identifier in
      OCRLanguageOption(
        identifier: identifier,
        displayName: Self.displayName(for: identifier, locale: locale)
      )
    }.sorted { lhs, rhs in
      lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
    }
    ocrRecognitionPreferences = OCRRecognitionPreferences.validated(
      requestedLanguageIdentifiers: settingsStore.ocrRecognitionPreferences.languageIdentifiers,
      supportedLanguageIdentifiers: effectiveIdentifiers
    )
    captureShortcut = shortcutStore.captureShortcut
    launchAtLoginStatus = launchAtLoginService.status
    launchAtLoginIssue = Self.issue(for: launchAtLoginService.status)
    isSuccessSoundEnabled = settingsStore.isSuccessSoundEnabled
    if isOCRLanguageCatalogAvailable {
      settingsStore.ocrRecognitionPreferences = ocrRecognitionPreferences
    }
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

  func setSuccessSoundEnabled(_ enabled: Bool) {
    settingsStore.isSuccessSoundEnabled = enabled
    isSuccessSoundEnabled = settingsStore.isSuccessSoundEnabled
  }

  @discardableResult
  func setOCRLanguageIdentifiers(_ identifiers: [String]) -> Bool {
    guard !identifiers.isEmpty else {
      return false
    }
    let supported = Set(availableOCRLanguages.map(\.identifier))
    guard identifiers.contains(where: supported.contains) else {
      return false
    }
    let preferences = OCRRecognitionPreferences.validated(
      requestedLanguageIdentifiers: identifiers,
      supportedLanguageIdentifiers: availableOCRLanguages.map(\.identifier)
    )
    settingsStore.ocrRecognitionPreferences = preferences
    ocrRecognitionPreferences = preferences
    return true
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
      isSuccessSoundEnabled = settingsStore.isSuccessSoundEnabled
      ocrRecognitionPreferences = .englishUS
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

  private static func displayName(for identifier: String, locale: Locale) -> String {
    locale.localizedString(forIdentifier: identifier) ?? identifier
  }
}
