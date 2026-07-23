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

  func testCodeShortcutInvokesCodeModeAndSharesBusyRejection() async {
    let context = makeContext()
    context.controller.start()

    context.events.emit(.keyUp, mode: .code)
    await waitForState(.requestingPermission, coordinator: context.coordinator)
    context.events.emit(.keyUp, mode: .text)
    await Task.yield()

    XCTAssertEqual(context.scheduler.scheduledCompletionCount, 1)
    await context.scheduler.runNext()
    XCTAssertEqual(context.coordinator.state, .idle)
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
