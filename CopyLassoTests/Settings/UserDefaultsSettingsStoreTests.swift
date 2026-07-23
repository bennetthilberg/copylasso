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
    XCTAssertEqual(store.successSoundPreferenceVersion, 0)
    XCTAssertTrue(store.isSuccessSoundEnabled)
  }

  func testSoundPreferenceMigrationDefaultsNewAndUpgradedUsersToEnabled() throws {
    let store = makeStore()

    store.migrateSuccessSoundPreferenceIfNeeded()

    XCTAssertEqual(
      store.successSoundPreferenceVersion,
      UserDefaultsSettingsStore.currentSuccessSoundPreferenceVersion
    )
    XCTAssertTrue(store.isSuccessSoundEnabled)
  }

  func testSoundPreferenceMigrationPreservesAnExplicitDisabledChoice() throws {
    let defaults = try makeDefaults()
    defaults.set(false, forKey: UserDefaultsSettingsStore.successSoundEnabledKey)
    let store = UserDefaultsSettingsStore(userDefaults: defaults)

    store.migrateSuccessSoundPreferenceIfNeeded()

    XCTAssertEqual(
      store.successSoundPreferenceVersion,
      UserDefaultsSettingsStore.currentSuccessSoundPreferenceVersion
    )
    XCTAssertFalse(store.isSuccessSoundEnabled)
  }

  func testSoundPreferencePersistsAcrossStoreReconstruction() throws {
    let defaults = try makeDefaults()
    var store = UserDefaultsSettingsStore(userDefaults: defaults)
    store.migrateSuccessSoundPreferenceIfNeeded()
    store.isSuccessSoundEnabled = false

    store = UserDefaultsSettingsStore(userDefaults: defaults)

    XCTAssertEqual(
      store.successSoundPreferenceVersion,
      UserDefaultsSettingsStore.currentSuccessSoundPreferenceVersion
    )
    XCTAssertFalse(store.isSuccessSoundEnabled)
  }

  func testWritingSoundPreferenceBeforeMigrationAdvancesTheSchema() {
    let store = makeStore()

    store.isSuccessSoundEnabled = false

    XCTAssertFalse(store.isSuccessSoundEnabled)
    XCTAssertEqual(
      store.successSoundPreferenceVersion,
      UserDefaultsSettingsStore.currentSuccessSoundPreferenceVersion
    )
  }

  func testValuesPersistAcrossStoreReconstruction() throws {
    let defaults = try makeDefaults()
    var store = UserDefaultsSettingsStore(userDefaults: defaults)
    store.completedOnboardingVersion = 1
    store.hasConfiguredCaptureShortcut = true
    store.hasConfiguredLaunchAtLogin = true
    store.migrateSuccessSoundPreferenceIfNeeded()
    store.isSuccessSoundEnabled = false
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
    let defaults = try makeDefaults()
    let store = UserDefaultsSettingsStore(userDefaults: defaults)
    let updateStore = UserDefaultsSecureUpdateStateStore(userDefaults: defaults)
    store.completedOnboardingVersion = 4
    store.hasConfiguredCaptureShortcut = true
    store.hasConfiguredLaunchAtLogin = true
    store.history = ScreenCapturePermissionHistory(
      hasRequested: true,
      hasObservedGranted: true
    )
    updateStore.highestAuthenticatedBuild = "2"
    updateStore.deferredBuild = "3"

    store.reset()

    XCTAssertEqual(store.completedOnboardingVersion, 0)
    XCTAssertFalse(store.hasConfiguredCaptureShortcut)
    XCTAssertFalse(store.hasConfiguredLaunchAtLogin)
    XCTAssertEqual(store.successSoundPreferenceVersion, 0)
    XCTAssertTrue(store.isSuccessSoundEnabled)
    XCTAssertEqual(store.history, ScreenCapturePermissionHistory())
    XCTAssertNil(updateStore.highestAuthenticatedBuild)
    XCTAssertNil(updateStore.deferredBuild)
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
