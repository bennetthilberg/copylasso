import AppKit
import XCTest

@testable import CopyLasso

@MainActor
final class ApplicationLifecycleControllerTests: XCTestCase {
  func testSystemInterruptionsCoalesceCancelOnceDismissRecoveryAndNeverAutoRestart() {
    let source = StubApplicationLifecycleEventSource()
    let canceller = SpyActiveCaptureCanceller(results: [true, true])
    let recovery = SpyPermissionRecoveryPresenter()
    let logger = SpyCaptureLifecycleLogger()
    var shortcutStopCount = 0
    let controller = ApplicationLifecycleController(
      eventSource: source,
      captureCanceller: canceller,
      recoveryPresenter: recovery,
      stopShortcutDelivery: { shortcutStopCount += 1 },
      logger: logger
    )
    controller.start()

    source.send(.systemInterrupted)
    source.send(.systemInterrupted)

    XCTAssertEqual(canceller.reasons, [.systemInterrupted])
    XCTAssertEqual(recovery.dismissCallCount, 1)
    XCTAssertEqual(logger.events, [.cancelledForSystemInterruption])
    XCTAssertEqual(shortcutStopCount, 0)

    source.send(.systemResumed)
    XCTAssertEqual(canceller.reasons, [.systemInterrupted])
    XCTAssertEqual(logger.events, [.cancelledForSystemInterruption, .systemResumed])

    source.send(.systemInterrupted)
    XCTAssertEqual(canceller.reasons, [.systemInterrupted, .systemInterrupted])
    XCTAssertEqual(recovery.dismissCallCount, 2)
  }

  func testIdleInterruptionAndTerminationUseSafeDiagnosticsAndStopDelivery() {
    let source = StubApplicationLifecycleEventSource()
    let canceller = SpyActiveCaptureCanceller(results: [false, true])
    let recovery = SpyPermissionRecoveryPresenter()
    let logger = SpyCaptureLifecycleLogger()
    var shortcutStopCount = 0
    let controller = ApplicationLifecycleController(
      eventSource: source,
      captureCanceller: canceller,
      recoveryPresenter: recovery,
      stopShortcutDelivery: { shortcutStopCount += 1 },
      logger: logger
    )
    controller.start()

    source.send(.systemInterrupted)
    source.send(.applicationWillTerminate)

    XCTAssertEqual(canceller.reasons, [.systemInterrupted, .applicationTerminated])
    XCTAssertEqual(recovery.dismissCallCount, 2)
    XCTAssertEqual(shortcutStopCount, 1)
    XCTAssertEqual(
      logger.events,
      [.systemInterruptionWhileIdle, .applicationWillTerminate]
    )
    XCTAssertEqual(source.stopCallCount, 2)
  }

  func testStartAndStopAreIdempotentAndReleaseTheEventHandler() {
    let source = StubApplicationLifecycleEventSource()
    let controller = ApplicationLifecycleController(
      eventSource: source,
      captureCanceller: SpyActiveCaptureCanceller(results: []),
      recoveryPresenter: SpyPermissionRecoveryPresenter(),
      stopShortcutDelivery: {},
      logger: SpyCaptureLifecycleLogger()
    )

    controller.start()
    controller.start()
    controller.stop()
    controller.stop()
    source.send(.systemInterrupted)

    XCTAssertEqual(source.startCallCount, 2)
    XCTAssertEqual(source.stopCallCount, 4)
    XCTAssertFalse(source.hasHandler)
  }

  func testSystemEventSourceMapsWorkspaceAndApplicationNotificationsAndStopsCleanly() {
    let applicationCenter = NotificationCenter()
    let workspaceCenter = NotificationCenter()
    let source = SystemApplicationLifecycleEventSource(
      applicationCenter: applicationCenter,
      workspaceCenter: workspaceCenter
    )
    var events: [ApplicationLifecycleEvent] = []
    source.start { events.append($0) }

    workspaceCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
    workspaceCenter.post(name: NSWorkspace.screensDidSleepNotification, object: nil)
    workspaceCenter.post(name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
    workspaceCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
    workspaceCenter.post(name: NSWorkspace.screensDidWakeNotification, object: nil)
    workspaceCenter.post(name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
    applicationCenter.post(name: NSApplication.willTerminateNotification, object: nil)

    XCTAssertEqual(
      events,
      [
        .systemInterrupted, .systemInterrupted, .systemInterrupted,
        .systemResumed, .systemResumed, .systemResumed,
        .applicationWillTerminate,
      ]
    )

    source.stop()
    workspaceCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
    XCTAssertEqual(events.count, 7)
  }
}

@MainActor
private final class StubApplicationLifecycleEventSource: ApplicationLifecycleEventSourcing {
  private var handler: ((ApplicationLifecycleEvent) -> Void)?
  private(set) var startCallCount = 0
  private(set) var stopCallCount = 0

  var hasHandler: Bool { handler != nil }

  func start(handler: @escaping (ApplicationLifecycleEvent) -> Void) {
    startCallCount += 1
    self.handler = handler
  }

  func stop() {
    stopCallCount += 1
    handler = nil
  }

  func send(_ event: ApplicationLifecycleEvent) {
    handler?(event)
  }
}

@MainActor
private final class SpyActiveCaptureCanceller: ActiveCaptureCancelling {
  private var results: [Bool]
  private(set) var reasons: [CaptureCancellationReason] = []

  init(results: [Bool]) {
    self.results = results
  }

  func cancelActiveOperation(reason: CaptureCancellationReason) -> Bool {
    reasons.append(reason)
    return results.isEmpty ? false : results.removeFirst()
  }
}

@MainActor
private final class SpyCaptureLifecycleLogger: CaptureLifecycleLogging {
  private(set) var events: [CaptureLifecycleDiagnostic] = []

  func record(_ event: CaptureLifecycleDiagnostic) {
    events.append(event)
  }
}
