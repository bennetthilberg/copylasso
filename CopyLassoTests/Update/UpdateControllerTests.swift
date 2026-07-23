import Observation
import XCTest

@testable import CopyLasso

@MainActor
final class UpdateControllerTests: XCTestCase {
  func testStartSeedsServiceAndPublishesItsState() throws {
    let service = StubUpdateService()
    service.seedAutomaticallyChecksForUpdates(true)
    service.canCheckForUpdates = true
    let controller = UpdateController(service: service)

    controller.start()

    XCTAssertEqual(service.startCallCount, 1)
    XCTAssertTrue(controller.automaticallyChecksForUpdates)
    XCTAssertTrue(controller.canCheckForUpdates)
  }

  func testAutomaticCheckTogglePersistsThroughUpdaterService() {
    let service = StubUpdateService()
    service.seedAutomaticallyChecksForUpdates(true)
    let controller = UpdateController(service: service)

    controller.setAutomaticallyChecksForUpdates(false)

    XCTAssertFalse(service.automaticallyChecksForUpdates)
    XCTAssertFalse(controller.automaticallyChecksForUpdates)
    XCTAssertEqual(service.automaticPreferenceWriteCount, 1)
  }

  func testManualCheckRoutesEvenWhenAutomaticChecksAreDisabled() {
    let service = StubUpdateService()
    service.seedAutomaticallyChecksForUpdates(false)
    service.canCheckForUpdates = true
    let controller = UpdateController(service: service)

    controller.checkForUpdates()

    XCTAssertEqual(service.checkCallCount, 1)
  }

  func testUnavailableServiceDoesNotBeginManualCheck() {
    let service = StubUpdateService()
    service.canCheckForUpdates = false
    let controller = UpdateController(service: service)

    controller.checkForUpdates()

    XCTAssertEqual(service.checkCallCount, 0)
  }

  func testStartupFailureLeavesTheControllerUsableAndReportsRecoveryCopy() {
    let service = StubUpdateService()
    service.canCheckForUpdates = false
    service.startError = TestError.unavailable
    let controller = UpdateController(service: service)

    controller.start()

    XCTAssertEqual(service.startCallCount, 1)
    XCTAssertFalse(controller.canCheckForUpdates)
    XCTAssertEqual(
      controller.availabilityMessage,
      "Secure updates are unavailable. Capture remains fully usable; reinstall CopyLasso or try again later."
    )
  }

  #if DEBUG
    func testDebugServiceDefaultsOnAndPublishesEveryStateChange() throws {
      let service = DebugUpdateService()
      var stateChangeCount = 0
      service.stateDidChange = {
        stateChangeCount += 1
      }

      try service.start()
      service.automaticallyChecksForUpdates = false
      service.checkForUpdates()

      XCTAssertFalse(service.automaticallyChecksForUpdates)
      XCTAssertTrue(service.canCheckForUpdates)
      XCTAssertEqual(stateChangeCount, 3)
    }
  #endif
}

private enum TestError: Error {
  case unavailable
}

@MainActor
private final class StubUpdateService: UpdateServicing {
  var canCheckForUpdates = false
  var automaticallyChecksForUpdates: Bool {
    get {
      storedAutomaticallyChecksForUpdates
    }
    set {
      storedAutomaticallyChecksForUpdates = newValue
      automaticPreferenceWriteCount += 1
    }
  }
  private var storedAutomaticallyChecksForUpdates = false
  var stateDidChange: (() -> Void)?
  private(set) var startCallCount = 0
  private(set) var checkCallCount = 0
  private(set) var automaticPreferenceWriteCount = 0
  var startError: (any Error)?

  func start() throws {
    startCallCount += 1
    if let startError {
      throw startError
    }
    stateDidChange?()
  }

  func checkForUpdates() {
    checkCallCount += 1
    stateDidChange?()
  }

  func seedAutomaticallyChecksForUpdates(_ value: Bool) {
    storedAutomaticallyChecksForUpdates = value
  }
}
