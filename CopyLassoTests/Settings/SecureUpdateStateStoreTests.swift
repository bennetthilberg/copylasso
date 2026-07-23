import Foundation
import XCTest

@testable import CopyLasso

@MainActor
final class SecureUpdateStateStoreTests: XCTestCase {
  func testStoresOnlyHighWaterAndDeferredBuildValues() throws {
    let defaults = try makeDefaults()
    var store = UserDefaultsSecureUpdateStateStore(userDefaults: defaults)
    store.highestAuthenticatedBuild = "3"
    store.deferredBuild = "4"

    store = UserDefaultsSecureUpdateStateStore(userDefaults: defaults)

    XCTAssertEqual(store.highestAuthenticatedBuild, "3")
    XCTAssertEqual(store.deferredBuild, "4")
    XCTAssertEqual(
      Set(defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("updates.") }),
      [
        UserDefaultsSecureUpdateStateStore.highestAuthenticatedBuildKey,
        UserDefaultsSecureUpdateStateStore.deferredBuildKey,
      ]
    )
  }

  func testNilRemovesPersistedUpdateState() throws {
    let defaults = try makeDefaults()
    let store = UserDefaultsSecureUpdateStateStore(userDefaults: defaults)
    store.highestAuthenticatedBuild = "3"
    store.deferredBuild = "4"

    store.highestAuthenticatedBuild = nil
    store.deferredBuild = nil

    XCTAssertNil(store.highestAuthenticatedBuild)
    XCTAssertNil(store.deferredBuild)
  }

  private func makeDefaults() throws -> UserDefaults {
    let suiteName = "CopyLassoUpdateTests.\(UUID().uuidString)"
    addTeardownBlock {
      UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }
    return try XCTUnwrap(UserDefaults(suiteName: suiteName))
  }
}
