import Foundation

@MainActor
protocol OCRRecognitionPreferencesReading: Sendable {
  var ocrRecognitionPreferences: OCRRecognitionPreferences { get }
}

@MainActor
struct EnglishOnlyOCRRecognitionPreferencesReader: OCRRecognitionPreferencesReading {
  let ocrRecognitionPreferences = OCRRecognitionPreferences.englishUS
}

@MainActor
protocol AppSettingsStoring: ScreenCapturePermissionHistoryStoring,
  SuccessSoundPreferenceReading, OCRRecognitionPreferencesReading
{
  var completedOnboardingVersion: Int { get set }
  var hasConfiguredCaptureShortcut: Bool { get set }
  var hasConfiguredLaunchAtLogin: Bool { get set }
  var successSoundPreferenceVersion: Int { get set }
  var isSuccessSoundEnabled: Bool { get set }
  var ocrLanguagePreferenceVersion: Int { get set }
  var ocrRecognitionPreferences: OCRRecognitionPreferences { get set }

  func migrateSuccessSoundPreferenceIfNeeded()
  func migrateOCRLanguagePreferencesIfNeeded()
}

@MainActor
final class UserDefaultsSettingsStore: AppSettingsStoring {
  static let completedOnboardingVersionKey = "onboarding.completedVersion"
  static let currentSuccessSoundPreferenceVersion = 1
  static let successSoundEnabledKey = "feedback.successSoundEnabled"
  static let currentOCRLanguagePreferenceVersion = 1

  private enum Key {
    static let hasConfiguredCaptureShortcut = "settings.hasConfiguredCaptureShortcut"
    static let hasConfiguredLaunchAtLogin = "settings.hasConfiguredLaunchAtLogin"
    static let permissionHasRequested = "screenCapturePermission.hasRequested"
    static let permissionHasObservedGranted = "screenCapturePermission.hasObservedGranted"
    static let successSoundPreferenceVersion = "feedback.successSoundPreferenceVersion"
    static let ocrLanguagePreferenceVersion = "recognition.languagePreferenceVersion"
    static let ocrLanguageIdentifiers = "recognition.languageIdentifiers"
  }

  private let userDefaults: UserDefaults

  var completedOnboardingVersion: Int {
    get {
      max(0, userDefaults.integer(forKey: Self.completedOnboardingVersionKey))
    }
    set {
      userDefaults.set(max(0, newValue), forKey: Self.completedOnboardingVersionKey)
    }
  }

  var hasConfiguredCaptureShortcut: Bool {
    get {
      userDefaults.bool(forKey: Key.hasConfiguredCaptureShortcut)
    }
    set {
      userDefaults.set(newValue, forKey: Key.hasConfiguredCaptureShortcut)
    }
  }

  var hasConfiguredLaunchAtLogin: Bool {
    get {
      userDefaults.bool(forKey: Key.hasConfiguredLaunchAtLogin)
    }
    set {
      userDefaults.set(newValue, forKey: Key.hasConfiguredLaunchAtLogin)
    }
  }

  var successSoundPreferenceVersion: Int {
    get {
      max(0, userDefaults.integer(forKey: Key.successSoundPreferenceVersion))
    }
    set {
      userDefaults.set(max(0, newValue), forKey: Key.successSoundPreferenceVersion)
    }
  }

  var isSuccessSoundEnabled: Bool {
    get {
      userDefaults.object(forKey: Self.successSoundEnabledKey) as? Bool ?? true
    }
    set {
      userDefaults.set(newValue, forKey: Self.successSoundEnabledKey)
      if successSoundPreferenceVersion < Self.currentSuccessSoundPreferenceVersion {
        successSoundPreferenceVersion = Self.currentSuccessSoundPreferenceVersion
      }
    }
  }

  var ocrLanguagePreferenceVersion: Int {
    get {
      max(0, userDefaults.integer(forKey: Key.ocrLanguagePreferenceVersion))
    }
    set {
      userDefaults.set(max(0, newValue), forKey: Key.ocrLanguagePreferenceVersion)
    }
  }

  var ocrRecognitionPreferences: OCRRecognitionPreferences {
    get {
      guard let identifiers = userDefaults.stringArray(forKey: Key.ocrLanguageIdentifiers) else {
        return .englishUS
      }
      return OCRRecognitionPreferences(languageIdentifiers: identifiers)
    }
    set {
      userDefaults.set(newValue.languageIdentifiers, forKey: Key.ocrLanguageIdentifiers)
      if ocrLanguagePreferenceVersion < Self.currentOCRLanguagePreferenceVersion {
        ocrLanguagePreferenceVersion = Self.currentOCRLanguagePreferenceVersion
      }
    }
  }

  var history: ScreenCapturePermissionHistory {
    get {
      ScreenCapturePermissionHistory(
        hasRequested: userDefaults.bool(forKey: Key.permissionHasRequested),
        hasObservedGranted: userDefaults.bool(forKey: Key.permissionHasObservedGranted)
      )
    }
    set {
      userDefaults.set(newValue.hasRequested, forKey: Key.permissionHasRequested)
      userDefaults.set(newValue.hasObservedGranted, forKey: Key.permissionHasObservedGranted)
    }
  }

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
  }

  func migrateSuccessSoundPreferenceIfNeeded() {
    guard successSoundPreferenceVersion < Self.currentSuccessSoundPreferenceVersion else {
      return
    }
    if userDefaults.object(forKey: Self.successSoundEnabledKey) as? Bool == nil {
      userDefaults.set(true, forKey: Self.successSoundEnabledKey)
    }
    successSoundPreferenceVersion = Self.currentSuccessSoundPreferenceVersion
  }

  func migrateOCRLanguagePreferencesIfNeeded() {
    guard ocrLanguagePreferenceVersion < Self.currentOCRLanguagePreferenceVersion else {
      return
    }
    if userDefaults.stringArray(forKey: Key.ocrLanguageIdentifiers) == nil {
      userDefaults.set(
        OCRRecognitionPreferences.englishUS.languageIdentifiers,
        forKey: Key.ocrLanguageIdentifiers
      )
    }
    ocrLanguagePreferenceVersion = Self.currentOCRLanguagePreferenceVersion
  }

  func reset() {
    userDefaults.removeObject(forKey: Self.completedOnboardingVersionKey)
    userDefaults.removeObject(forKey: Key.hasConfiguredCaptureShortcut)
    userDefaults.removeObject(forKey: Key.hasConfiguredLaunchAtLogin)
    userDefaults.removeObject(forKey: Key.permissionHasRequested)
    userDefaults.removeObject(forKey: Key.permissionHasObservedGranted)
    userDefaults.removeObject(forKey: Key.successSoundPreferenceVersion)
    userDefaults.removeObject(forKey: Self.successSoundEnabledKey)
    userDefaults.removeObject(forKey: Key.ocrLanguagePreferenceVersion)
    userDefaults.removeObject(forKey: Key.ocrLanguageIdentifiers)
    userDefaults.removeObject(
      forKey: UserDefaultsSecureUpdateStateStore.highestAuthenticatedBuildKey)
    userDefaults.removeObject(forKey: UserDefaultsSecureUpdateStateStore.deferredBuildKey)
  }
}
