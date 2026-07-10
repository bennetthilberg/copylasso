import XCTest

@testable import CopyLasso

@MainActor
final class ScreenCapturePermissionHistoryTests: XCTestCase {
  func testPermissionHistoryReportsOnlyKnownOrSafelyInferredStates() {
    var history = ScreenCapturePermissionHistory()

    XCTAssertEqual(history.observation(preflightGranted: false), .notGrantedNeverRequested)

    history.hasRequested = true
    XCTAssertEqual(history.observation(preflightGranted: false), .notGrantedAfterRequest)

    history.hasObservedGranted = true
    XCTAssertEqual(history.observation(preflightGranted: false), .notGrantedAfterPreviouslyGranted)
    XCTAssertEqual(history.observation(preflightGranted: true), .granted)
  }

  func testPersistenceContractCanResetTheWholeHistory() {
    let store = InMemoryPermissionHistoryStore(
      history: ScreenCapturePermissionHistory(
        hasRequested: true,
        hasObservedGranted: true
      )
    )

    store.reset()

    XCTAssertEqual(store.history, ScreenCapturePermissionHistory())
  }
}

@MainActor
private final class InMemoryPermissionHistoryStore: ScreenCapturePermissionHistoryStoring {
  var history: ScreenCapturePermissionHistory

  init(history: ScreenCapturePermissionHistory) {
    self.history = history
  }

  func reset() {
    history = ScreenCapturePermissionHistory()
  }
}
