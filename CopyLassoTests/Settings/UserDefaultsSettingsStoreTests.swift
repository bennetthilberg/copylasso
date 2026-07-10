import Foundation
import XCTest

@testable import CopyLasso

@MainActor
final class UserDefaultsSettingsStoreTests: XCTestCase {
  func testDefaultsAreIncompleteAndContainNoPermissionHistory() throws {
    let store = makeStore()

    XCTAssertEqual(store.completedOnboardingVersion, 0)
    XCTAssertFalse(store.hasConfiguredCaptureShortcut)
    XCTAssertFalse(store.hasConfiguredLaunchAtLogin)
    XCTAssertEqual(store.history, ScreenCapturePermissionHistory())
  }

  func testValuesPersistAcrossStoreReconstruction() throws {
    let defaults = try makeDefaults()
    var store = UserDefaultsSettingsStore(userDefaults: defaults)
    store.completedOnboardingVersion = 1
    store.hasConfiguredCaptureShortcut = true
    store.hasConfiguredLaunchAtLogin = true
    store.history = ScreenCapturePermissionHistory(
      hasRequested: true,
      hasObservedGranted: true
    )

    store = UserDefaultsSettingsStore(userDefaults: defaults)

    XCTAssertEqual(store.completedOnboardingVersion, 1)
    XCTAssertTrue(store.hasConfiguredCaptureShortcut)
    XCTAssertTrue(store.hasConfiguredLaunchAtLogin)
    XCTAssertEqual(
      store.history,
      ScreenCapturePermissionHistory(hasRequested: true, hasObservedGranted: true)
    )
  }

  func testResetRemovesEveryOwnedPreference() throws {
    let store = makeStore()
    store.completedOnboardingVersion = 4
    store.hasConfiguredCaptureShortcut = true
    store.hasConfiguredLaunchAtLogin = true
    store.history = ScreenCapturePermissionHistory(
      hasRequested: true,
      hasObservedGranted: true
    )

    store.reset()

    XCTAssertEqual(store.completedOnboardingVersion, 0)
    XCTAssertFalse(store.hasConfiguredCaptureShortcut)
    XCTAssertFalse(store.hasConfiguredLaunchAtLogin)
    XCTAssertEqual(store.history, ScreenCapturePermissionHistory())
  }

  func testIndependentSuitesDoNotShareSettings() throws {
    let first = makeStore()
    let second = makeStore()
    first.completedOnboardingVersion = 1

    XCTAssertEqual(first.completedOnboardingVersion, 1)
    XCTAssertEqual(second.completedOnboardingVersion, 0)
  }

  func testInvalidNegativeOnboardingVersionReadsAsIncomplete() throws {
    let defaults = try makeDefaults()
    defaults.set(-1, forKey: UserDefaultsSettingsStore.completedOnboardingVersionKey)

    XCTAssertEqual(
      UserDefaultsSettingsStore(userDefaults: defaults).completedOnboardingVersion,
      0
    )
  }

  private func makeStore() -> UserDefaultsSettingsStore {
    UserDefaultsSettingsStore(userDefaults: try! makeDefaults())
  }

  private func makeDefaults() throws -> UserDefaults {
    let suiteName = "CopyLassoTests.\(UUID().uuidString)"
    addTeardownBlock {
      UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }
    return try XCTUnwrap(UserDefaults(suiteName: suiteName))
  }
}
