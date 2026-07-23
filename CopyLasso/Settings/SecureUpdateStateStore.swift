import Foundation

@MainActor
protocol SecureUpdateStateStoring: AnyObject {
  var highestAuthenticatedBuild: String? { get set }
  var deferredBuild: String? { get set }
}

@MainActor
final class UserDefaultsSecureUpdateStateStore: SecureUpdateStateStoring {
  static let highestAuthenticatedBuildKey = "updates.highestAuthenticatedBuild"
  static let deferredBuildKey = "updates.deferredBuild"

  private let userDefaults: UserDefaults

  var highestAuthenticatedBuild: String? {
    get {
      userDefaults.string(forKey: Self.highestAuthenticatedBuildKey)
    }
    set {
      set(newValue, forKey: Self.highestAuthenticatedBuildKey)
    }
  }

  var deferredBuild: String? {
    get {
      userDefaults.string(forKey: Self.deferredBuildKey)
    }
    set {
      set(newValue, forKey: Self.deferredBuildKey)
    }
  }

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
  }

  private func set(_ value: String?, forKey key: String) {
    if let value {
      userDefaults.set(value, forKey: key)
    } else {
      userDefaults.removeObject(forKey: key)
    }
  }
}
