import AppKit
import XCTest

@testable import CopyLasso

@MainActor
final class PermissionRecoveryTests: XCTestCase {
  func testRecoveryCopyDoesNotOverstateAfterRequestState() {
    let content = PermissionRecoveryContent(
      observation: .notGrantedAfterRequest
    )

    XCTAssertEqual(content.title, "Screen Recording Access Needed")
    XCTAssertEqual(
      content.status,
      "macOS does not tell CopyLasso whether access was denied or is still awaiting approval."
    )
    XCTAssertEqual(
      content.instructions,
      "Open System Settings > Privacy & Security > Screen & System Audio Recording and enable CopyLasso. If macOS asks, choose Quit & Reopen. Otherwise return here and choose Try Again."
    )
  }

  func testRecoveryCopyDescribesPriorAccessAsOnlyLikelyRevoked() {
    let content = PermissionRecoveryContent(
      observation: .notGrantedAfterPreviouslyGranted
    )

    XCTAssertEqual(
      content.status,
      "Screen Recording access was available before and may have been turned off."
    )
    XCTAssertFalse(content.status.localizedCaseInsensitiveContains("revoked"))
  }

  func testPanelControllerReusesOneHostAndUpdatesItsModel() {
    let permission = StubScreenCapturePermissionService(
      currentResult: .notGrantedAfterRequest,
      requestResult: .notGrantedAfterRequest
    )
    let host = SpyPermissionRecoveryPanelHost()
    var factoryCallCount = 0
    let controller = PermissionRecoveryPanelController(
      permissionService: permission,
      makePanel: { _, _ in
        factoryCallCount += 1
        return host
      }
    )

    controller.present(.notGrantedAfterRequest)
    controller.present(.notGrantedAfterPreviouslyGranted)

    XCTAssertEqual(factoryCallCount, 1)
    XCTAssertEqual(host.showCallCount, 2)
    XCTAssertEqual(
      controller.model.observation,
      .notGrantedAfterPreviouslyGranted
    )
  }

  func testPanelActionsOpenSettingsRetryAndCancelWithoutDuplicatingThePanel() {
    let permission = StubScreenCapturePermissionService(
      currentResult: .notGrantedAfterRequest,
      requestResult: .notGrantedAfterRequest
    )
    permission.openSystemSettingsResult = false
    let requester = SpyCaptureRequester()
    let host = SpyPermissionRecoveryPanelHost()
    var capturedActions: PermissionRecoveryPanelActions?
    let controller = PermissionRecoveryPanelController(
      permissionService: permission,
      makePanel: { _, actions in
        capturedActions = actions
        return host
      }
    )
    controller.captureRequester = requester
    controller.present(.notGrantedAfterRequest)

    capturedActions?.openSystemSettings()
    XCTAssertEqual(permission.openSystemSettingsCallCount, 1)
    XCTAssertTrue(controller.model.settingsOpenFailed)

    capturedActions?.tryAgain()
    XCTAssertEqual(requester.performCallCount, 1)
    XCTAssertEqual(permission.beginUserInitiatedRetryCallCount, 1)

    capturedActions?.cancel()
    XCTAssertEqual(host.hideCallCount, 1)
    XCTAssertFalse(controller.model.isPresented)
  }

  func testRetryReportsProgressAndExplainsWhenAccessRemainsUnavailable() {
    let permission = StubScreenCapturePermissionService(
      currentResult: .notGrantedAfterRequest,
      requestResult: .notGrantedAfterRequest
    )
    let requester = SpyCaptureRequester()
    var capturedActions: PermissionRecoveryPanelActions?
    let controller = PermissionRecoveryPanelController(
      permissionService: permission,
      makePanel: { _, actions in
        capturedActions = actions
        return SpyPermissionRecoveryPanelHost()
      }
    )
    controller.captureRequester = requester
    controller.present(.notGrantedAfterRequest)

    capturedActions?.tryAgain()
    XCTAssertEqual(
      controller.model.retryStatus,
      "Checking Screen Recording access…"
    )

    controller.present(.notGrantedAfterRequest)
    XCTAssertEqual(
      controller.model.retryStatus,
      "Access is still unavailable. If you chose Later, quit and reopen CopyLasso, then choose Try Again."
    )
  }

  func testProductionPanelIsNonactivatingAndUsesNoAppDefinedAnimation() throws {
    let permission = StubScreenCapturePermissionService(
      currentResult: .notGrantedAfterRequest,
      requestResult: .notGrantedAfterRequest
    )
    let controller = PermissionRecoveryPanelController(permissionService: permission)

    controller.present(.notGrantedAfterRequest)

    let panel = try XCTUnwrap(
      NSApp.windows.first(where: {
        $0.identifier?.rawValue == "copylasso.permission-recovery.panel"
      }) as? NSPanel
    )
    XCTAssertTrue(panel.isVisible)
    XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
    XCTAssertEqual(panel.animationBehavior, .none)
    XCTAssertFalse(panel.canBecomeMain)

    controller.dismiss()
    XCTAssertFalse(panel.isVisible)
  }

  func testRejectedRetryDoesNotClearTheAuthoritativeDenial() {
    let permission = StubScreenCapturePermissionService(
      currentResult: .notGrantedAfterPreviouslyGranted,
      requestResult: .notGrantedAfterPreviouslyGranted
    )
    let requester = SpyCaptureRequester()
    requester.result = .rejectedBusy(currentState: .requestingPermission)
    var capturedActions: PermissionRecoveryPanelActions?
    let controller = PermissionRecoveryPanelController(
      permissionService: permission,
      makePanel: { _, actions in
        capturedActions = actions
        return SpyPermissionRecoveryPanelHost()
      }
    )
    controller.captureRequester = requester
    controller.present(.notGrantedAfterPreviouslyGranted)

    capturedActions?.tryAgain()

    XCTAssertEqual(permission.beginUserInitiatedRetryCallCount, 0)
    XCTAssertEqual(
      controller.model.retryStatus,
      "CopyLasso is already checking Screen Recording access."
    )
  }
}

@MainActor
private final class SpyPermissionRecoveryPanelHost: PermissionRecoveryPanelHosting {
  private(set) var showCallCount = 0
  private(set) var hideCallCount = 0

  func show() {
    showCallCount += 1
  }

  func hide() {
    hideCallCount += 1
  }
}

@MainActor
private final class SpyCaptureRequester: CaptureRequesting {
  var result: CaptureTransitionResult = .transitioned(from: .idle, to: .requestingPermission)
  private(set) var performCallCount = 0

  @discardableResult
  func perform() -> CaptureTransitionResult {
    performCallCount += 1
    return result
  }
}
