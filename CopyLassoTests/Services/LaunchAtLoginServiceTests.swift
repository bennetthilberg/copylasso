import XCTest

@testable import CopyLasso

@MainActor
final class LaunchAtLoginServiceTests: XCTestCase {
  func testEveryPlatformStatusMapsToTheNeutralStatus() {
    let backend = StubLaunchAtLoginBackend(status: .notRegistered)
    let service = SystemLaunchAtLoginService(backend: backend)

    let cases: [(PlatformLaunchAtLoginStatus, LaunchAtLoginStatus)] = [
      (.notRegistered, .disabled),
      (.enabled, .enabled),
      (.requiresApproval, .requiresApproval),
      (.notFound, .disabled),
      (.unavailable, .unavailable),
    ]

    for (platformStatus, expectedStatus) in cases {
      backend.status = platformStatus
      XCTAssertEqual(service.status, expectedStatus)
    }
  }

  func testEnableAndDisableAreIdempotent() throws {
    let backend = StubLaunchAtLoginBackend(status: .enabled)
    let service = SystemLaunchAtLoginService(backend: backend)

    try service.enable()
    XCTAssertEqual(backend.registerCallCount, 0)

    backend.status = .notRegistered
    try service.disable()
    XCTAssertEqual(backend.unregisterCallCount, 0)

    backend.status = .notFound
    backend.unregisterError = .injected
    try service.disable()
    XCTAssertEqual(backend.unregisterCallCount, 1)
  }

  func testEnableRegistersOnlyWhenDisabled() throws {
    let backend = StubLaunchAtLoginBackend(status: .notRegistered)
    let service = SystemLaunchAtLoginService(backend: backend)

    try service.enable()

    XCTAssertEqual(backend.registerCallCount, 1)
  }

  func testDisableUnregistersEnabledOrApprovalRequiredItems() throws {
    for status in [PlatformLaunchAtLoginStatus.enabled, .requiresApproval] {
      let backend = StubLaunchAtLoginBackend(status: status)
      let service = SystemLaunchAtLoginService(backend: backend)

      try service.disable()

      XCTAssertEqual(backend.unregisterCallCount, 1)
    }
  }

  func testUnavailableStatusAndBackendErrorsBecomeSafeFailures() {
    let backend = StubLaunchAtLoginBackend(status: .unavailable)
    let service = SystemLaunchAtLoginService(backend: backend)

    XCTAssertThrowsError(try service.enable()) { error in
      XCTAssertEqual(error as? LaunchAtLoginServiceError, .unavailable)
    }

    backend.status = .notRegistered
    backend.registerError = .injected
    XCTAssertThrowsError(try service.enable()) { error in
      XCTAssertEqual(error as? LaunchAtLoginServiceError, .enableFailed)
    }

    backend.status = .enabled
    backend.unregisterError = .injected
    XCTAssertThrowsError(try service.disable()) { error in
      XCTAssertEqual(error as? LaunchAtLoginServiceError, .disableFailed)
    }
  }

  func testOpenSystemSettingsUsesTheBackend() {
    let backend = StubLaunchAtLoginBackend(status: .requiresApproval)
    let service = SystemLaunchAtLoginService(backend: backend)

    service.openSystemSettings()

    XCTAssertEqual(backend.openSettingsCallCount, 1)
  }
}
