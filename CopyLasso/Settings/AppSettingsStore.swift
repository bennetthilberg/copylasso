import Foundation

@MainActor
protocol AppSettingsStoring: ScreenCapturePermissionHistoryStoring {
  var completedOnboardingVersion: Int { get set }
}

@MainActor
final class UserDefaultsSettingsStore: AppSettingsStoring {
  static let completedOnboardingVersionKey = "onboarding.completedVersion"

  private enum Key {
    static let permissionHasRequested = "screenCapturePermission.hasRequested"
    static let permissionHasObservedGranted = "screenCapturePermission.hasObservedGranted"
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

  func reset() {
    userDefaults.removeObject(forKey: Self.completedOnboardingVersionKey)
    userDefaults.removeObject(forKey: Key.permissionHasRequested)
    userDefaults.removeObject(forKey: Key.permissionHasObservedGranted)
  }
}
