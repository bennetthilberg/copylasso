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
    XCTAssertEqual(store.ocrLanguagePreferenceVersion, 0)
    XCTAssertEqual(store.ocrRecognitionPreferences, .englishUS)
    XCTAssertFalse(store.isCaptureHistoryEnabled)
  }

  func testOCRLanguageMigrationDefaultsNewAndUpgradedUsersToEnglish() {
    let store = makeStore()

    store.migrateOCRLanguagePreferencesIfNeeded()

    XCTAssertEqual(
      store.ocrLanguagePreferenceVersion,
      UserDefaultsSettingsStore.currentOCRLanguagePreferenceVersion
    )
    XCTAssertEqual(store.ocrRecognitionPreferences, .englishUS)
  }

  func testCurrentOCRLanguageMigrationIsIdempotent() {
    let store = makeStore()
    store.ocrRecognitionPreferences = OCRRecognitionPreferences(
      languageIdentifiers: ["fr-FR", "en-US"]
    )
    store.isCaptureHistoryEnabled = true

    store.migrateOCRLanguagePreferencesIfNeeded()

    XCTAssertEqual(
      store.ocrRecognitionPreferences.languageIdentifiers,
      ["fr-FR", "en-US"]
    )
    XCTAssertEqual(
      store.ocrLanguagePreferenceVersion,
      UserDefaultsSettingsStore.currentOCRLanguagePreferenceVersion
    )
  }

  func testOCRLanguageOrderPersistsAcrossStoreReconstruction() throws {
    let defaults = try makeDefaults()
    var store = UserDefaultsSettingsStore(userDefaults: defaults)
    store.migrateOCRLanguagePreferencesIfNeeded()
    store.ocrRecognitionPreferences = OCRRecognitionPreferences(
      languageIdentifiers: ["fr-FR", "en-US", "ja-JP"]
    )

    store = UserDefaultsSettingsStore(userDefaults: defaults)

    XCTAssertEqual(
      store.ocrRecognitionPreferences.languageIdentifiers,
      ["fr-FR", "en-US", "ja-JP"]
    )
  }

  func testWritingOCRLanguagesBeforeMigrationAdvancesTheSchema() {
    let store = makeStore()

    store.ocrRecognitionPreferences = OCRRecognitionPreferences(
      languageIdentifiers: ["fr-FR", "en-US"]
    )

    XCTAssertEqual(
      store.ocrLanguagePreferenceVersion,
      UserDefaultsSettingsStore.currentOCRLanguagePreferenceVersion
    )
    XCTAssertEqual(
      store.ocrRecognitionPreferences.languageIdentifiers,
      ["fr-FR", "en-US"]
    )
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

  func testCurrentSoundPreferenceMigrationIsIdempotent() {
    let store = makeStore()
    store.migrateSuccessSoundPreferenceIfNeeded()
    store.isSuccessSoundEnabled = false

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

  func testVersion011PreferencesRemainCompatibleWithVersion020Migration() throws {
    let defaults = try makeDefaults()
    var store = UserDefaultsSettingsStore(userDefaults: defaults)
    let updateStore = UserDefaultsSecureUpdateStateStore(userDefaults: defaults)
    store.completedOnboardingVersion = 1
    store.hasConfiguredCaptureShortcut = true
    store.hasConfiguredLaunchAtLogin = true
    store.history = ScreenCapturePermissionHistory(
      hasRequested: true,
      hasObservedGranted: true
    )
    updateStore.highestAuthenticatedBuild = "2"
    updateStore.deferredBuild = "3"

    store = UserDefaultsSettingsStore(userDefaults: defaults)
    store.migrateSuccessSoundPreferenceIfNeeded()

    XCTAssertEqual(store.completedOnboardingVersion, 1)
    XCTAssertTrue(store.hasConfiguredCaptureShortcut)
    XCTAssertTrue(store.hasConfiguredLaunchAtLogin)
    XCTAssertEqual(
      store.history,
      ScreenCapturePermissionHistory(hasRequested: true, hasObservedGranted: true)
    )
    XCTAssertTrue(store.isSuccessSoundEnabled)
    XCTAssertEqual(
      store.successSoundPreferenceVersion,
      UserDefaultsSettingsStore.currentSuccessSoundPreferenceVersion
    )
    XCTAssertEqual(updateStore.highestAuthenticatedBuild, "2")
    XCTAssertEqual(updateStore.deferredBuild, "3")
  }

  func testVersion022PreferencesUpgradeToVersion030WithSafeFeatureDefaults() throws {
    let defaults = try makeDefaults()
    var store = UserDefaultsSettingsStore(userDefaults: defaults)
    let updateStore = UserDefaultsSecureUpdateStateStore(userDefaults: defaults)
    store.completedOnboardingVersion = 1
    store.hasConfiguredCaptureShortcut = true
    store.hasConfiguredLaunchAtLogin = true
    store.history = ScreenCapturePermissionHistory(
      hasRequested: true,
      hasObservedGranted: true
    )
    store.migrateSuccessSoundPreferenceIfNeeded()
    store.isSuccessSoundEnabled = false
    updateStore.highestAuthenticatedBuild = "5"
    updateStore.deferredBuild = "6"

    store = UserDefaultsSettingsStore(userDefaults: defaults)
    store.migrateSuccessSoundPreferenceIfNeeded()
    store.migrateOCRLanguagePreferencesIfNeeded()

    XCTAssertEqual(store.completedOnboardingVersion, 1)
    XCTAssertTrue(store.hasConfiguredCaptureShortcut)
    XCTAssertTrue(store.hasConfiguredLaunchAtLogin)
    XCTAssertEqual(
      store.history,
      ScreenCapturePermissionHistory(hasRequested: true, hasObservedGranted: true)
    )
    XCTAssertFalse(store.isSuccessSoundEnabled)
    XCTAssertEqual(store.ocrRecognitionPreferences, .englishUS)
    XCTAssertEqual(
      store.ocrLanguagePreferenceVersion,
      UserDefaultsSettingsStore.currentOCRLanguagePreferenceVersion
    )
    XCTAssertFalse(store.isCaptureHistoryEnabled)
    XCTAssertEqual(updateStore.highestAuthenticatedBuild, "5")
    XCTAssertEqual(updateStore.deferredBuild, "6")
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
    store.migrateOCRLanguagePreferencesIfNeeded()
    store.ocrRecognitionPreferences = OCRRecognitionPreferences(
      languageIdentifiers: ["fr-FR", "en-US"]
    )

    store.reset()

    XCTAssertEqual(store.completedOnboardingVersion, 0)
    XCTAssertFalse(store.hasConfiguredCaptureShortcut)
    XCTAssertFalse(store.hasConfiguredLaunchAtLogin)
    XCTAssertEqual(store.successSoundPreferenceVersion, 0)
    XCTAssertTrue(store.isSuccessSoundEnabled)
    XCTAssertEqual(store.ocrLanguagePreferenceVersion, 0)
    XCTAssertEqual(store.ocrRecognitionPreferences, .englishUS)
    XCTAssertFalse(store.isCaptureHistoryEnabled)
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
