import AppKit
import KeyboardShortcuts
import XCTest

@testable import CopyLasso

@MainActor
final class GlobalShortcutControllerTests: XCTestCase {
  func testKeyUpInvokesTheSharedCaptureCommand() async {
    let context = makeContext()
    context.controller.start()

    context.events.emit(.keyDown)
    await Task.yield()
    XCTAssertEqual(context.coordinator.state, .idle)

    context.events.emit(.keyUp)
    await waitForState(.requestingPermission, coordinator: context.coordinator)
    XCTAssertEqual(context.scheduler.scheduledCompletionCount, 1)
  }

  func testBusyShortcutRequestIsRejectedWithoutAnotherWorkflow() async {
    let context = makeContext()
    context.controller.start()
    context.events.emit(.keyUp)
    await waitForState(.requestingPermission, coordinator: context.coordinator)

    context.events.emit(.keyUp)
    await Task.yield()

    XCTAssertEqual(context.coordinator.state, .requestingPermission)
    XCTAssertEqual(context.scheduler.scheduledCompletionCount, 1)
  }

  func testThreeSequentialShortcutRequestsRemainUsable() async {
    let context = makeContext()
    context.controller.start()

    for _ in 0..<3 {
      context.events.emit(.keyUp)
      await waitForState(.requestingPermission, coordinator: context.coordinator)
      await context.scheduler.runNext()
      XCTAssertEqual(context.coordinator.state, .idle)
    }

    XCTAssertEqual(context.scheduler.scheduledCompletionCount, 3)
  }

  func testSystemEventSourceRegistersSavedShortcutAndForwardsEvents() async {
    let shortcut = KeyboardShortcuts.Shortcut(.two, modifiers: [.shift, .command])
    let registrar = RecordingGlobalShortcutHotKeyRegistrar()
    let source = SystemGlobalShortcutEventSource(
      registrar: registrar,
      shortcutProvider: { shortcut }
    )
    var iterator = source.events().makeAsyncIterator()

    XCTAssertEqual(registrar.registeredShortcuts, [shortcut])

    registrar.emit(.keyDown)
    let event = await iterator.next()

    XCTAssertEqual(event, .keyDown)
  }

  func testSystemEventSourceReregistersWhenTheSavedShortcutChanges() {
    let notificationCenter = NotificationCenter()
    let first = KeyboardShortcuts.Shortcut(.two, modifiers: [.shift, .command])
    let replacement = KeyboardShortcuts.Shortcut(.eight, modifiers: [.option, .command])
    let shortcutProvider = RecordingShortcutProvider(shortcut: first)
    let registrar = RecordingGlobalShortcutHotKeyRegistrar()
    let source = SystemGlobalShortcutEventSource(
      registrar: registrar,
      notificationCenter: notificationCenter,
      shortcutProvider: { shortcutProvider.shortcut }
    )
    _ = source.events()

    shortcutProvider.shortcut = replacement
    notificationCenter.post(
      name: Notification.Name("KeyboardShortcuts_shortcutByNameDidChange"),
      object: nil
    )

    XCTAssertEqual(registrar.registeredShortcuts, [first, replacement])
  }

  func testSystemEventSourceSuspendsWhileTheShortcutRecorderIsActive() {
    let notificationCenter = NotificationCenter()
    let shortcut = KeyboardShortcuts.Shortcut(.two, modifiers: [.shift, .command])
    let registrar = RecordingGlobalShortcutHotKeyRegistrar()
    let source = SystemGlobalShortcutEventSource(
      registrar: registrar,
      notificationCenter: notificationCenter,
      isApplicationActive: { true },
      shortcutProvider: { shortcut }
    )
    _ = source.events()

    notificationCenter.post(
      name: Notification.Name("KeyboardShortcuts_recorderActiveStatusDidChange"),
      object: nil,
      userInfo: ["isActive": true]
    )
    notificationCenter.post(
      name: Notification.Name("KeyboardShortcuts_recorderActiveStatusDidChange"),
      object: nil,
      userInfo: ["isActive": false]
    )

    XCTAssertEqual(registrar.registeredShortcuts, [shortcut, nil, shortcut])
  }

  func testSystemEventSourceIgnoresRestoredRecorderFocusWhileApplicationIsInactive() {
    let notificationCenter = NotificationCenter()
    let shortcut = KeyboardShortcuts.Shortcut(.two, modifiers: [.shift, .command])
    let registrar = RecordingGlobalShortcutHotKeyRegistrar()
    let source = SystemGlobalShortcutEventSource(
      registrar: registrar,
      notificationCenter: notificationCenter,
      isApplicationActive: { false },
      shortcutProvider: { shortcut }
    )
    _ = source.events()

    notificationCenter.post(
      name: Notification.Name("KeyboardShortcuts_recorderActiveStatusDidChange"),
      object: nil,
      userInfo: ["isActive": true]
    )

    XCTAssertEqual(registrar.registeredShortcuts, [shortcut])
  }

  func testSystemEventSourceReenablesShortcutWhenApplicationResignsDuringRecording() {
    let notificationCenter = NotificationCenter()
    let observedApplication = NSObject()
    let applicationActivity = RecordingApplicationActivity(isActive: true)
    let shortcut = KeyboardShortcuts.Shortcut(.two, modifiers: [.shift, .command])
    let registrar = RecordingGlobalShortcutHotKeyRegistrar()
    let source = SystemGlobalShortcutEventSource(
      registrar: registrar,
      notificationCenter: notificationCenter,
      observedApplication: observedApplication,
      isApplicationActive: { applicationActivity.isActive },
      shortcutProvider: { shortcut }
    )
    _ = source.events()
    notificationCenter.post(
      name: Notification.Name("KeyboardShortcuts_recorderActiveStatusDidChange"),
      object: nil,
      userInfo: ["isActive": true]
    )

    applicationActivity.isActive = false
    notificationCenter.post(
      name: NSApplication.didResignActiveNotification,
      object: observedApplication
    )

    XCTAssertEqual(registrar.registeredShortcuts, [shortcut, nil, shortcut])
  }

  func testSystemEventSourceRestartDoesNotLetTheOldStreamUnregisterTheNewOne() async {
    let shortcut = KeyboardShortcuts.Shortcut(.two, modifiers: [.shift, .command])
    let registrar = RecordingGlobalShortcutHotKeyRegistrar()
    let source = SystemGlobalShortcutEventSource(
      registrar: registrar,
      shortcutProvider: { shortcut }
    )
    _ = source.events()
    var replacementIterator = source.events().makeAsyncIterator()

    await Task.yield()
    registrar.emit(.keyUp)
    let event = await replacementIterator.next()

    XCTAssertEqual(event, .keyUp)
    XCTAssertEqual(registrar.registeredShortcuts, [shortcut, nil, shortcut])
  }

  func testStopCancelsEventDeliveryAndCleansUpTheStream() async {
    let context = makeContext()
    context.controller.start()
    context.controller.stop()
    await context.events.waitForCancellation()

    context.events.emit(.keyUp)
    await Task.yield()

    XCTAssertEqual(context.coordinator.state, .idle)
    XCTAssertTrue(context.events.wasCancelled)
  }

  private func makeContext() -> Context {
    let coordinator = CaptureCoordinator()
    let scheduler = ShortcutCaptureCompletionScheduler()
    let command = makeTestCaptureCommand(
      coordinator: coordinator,
      scheduleWork: scheduler.schedule
    )
    let events = StubGlobalShortcutEventSource()
    let controller = GlobalShortcutController(
      captureCommand: command,
      eventSource: events
    )
    return Context(
      controller: controller,
      coordinator: coordinator,
      scheduler: scheduler,
      events: events
    )
  }

  private func waitForState(
    _ state: CaptureState,
    coordinator: CaptureCoordinator
  ) async {
    for _ in 0..<20 where coordinator.state != state {
      await Task.yield()
    }
    XCTAssertEqual(coordinator.state, state)
  }

  private struct Context {
    let controller: GlobalShortcutController
    let coordinator: CaptureCoordinator
    let scheduler: ShortcutCaptureCompletionScheduler
    let events: StubGlobalShortcutEventSource
  }
}

@MainActor
private final class RecordingShortcutProvider {
  var shortcut: KeyboardShortcuts.Shortcut?

  init(shortcut: KeyboardShortcuts.Shortcut?) {
    self.shortcut = shortcut
  }
}

@MainActor
private final class RecordingApplicationActivity {
  var isActive: Bool

  init(isActive: Bool) {
    self.isActive = isActive
  }
}

@MainActor
private final class RecordingGlobalShortcutHotKeyRegistrar:
  GlobalShortcutHotKeyRegistering
{
  var eventHandler: ((GlobalShortcutEvent) -> Void)?
  private(set) var registeredShortcuts: [KeyboardShortcuts.Shortcut?] = []

  func register(_ shortcut: KeyboardShortcuts.Shortcut?) {
    registeredShortcuts.append(shortcut)
  }

  func emit(_ event: GlobalShortcutEvent) {
    eventHandler?(event)
  }
}

@MainActor
private final class ShortcutCaptureCompletionScheduler {
  typealias Completion = @MainActor @Sendable () async -> Void

  private var completions: [Completion] = []
  private(set) var scheduledCompletionCount = 0

  func schedule(_ completion: @escaping Completion) {
    scheduledCompletionCount += 1
    completions.append(completion)
  }

  func runNext() async {
    guard !completions.isEmpty else {
      return XCTFail("Expected a completion")
    }
    await completions.removeFirst()()
  }
}
