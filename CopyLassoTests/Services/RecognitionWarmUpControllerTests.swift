import Foundation
import XCTest

@testable import CopyLasso

@MainActor
final class RecognitionWarmUpControllerTests: XCTestCase {
  func testStartWaitsForTheLaunchDelayThenWarmsUpOnce() async {
    let warmer = ScriptedWarmer([.succeed])
    let sleeper = RecordingSleeper()
    let controller = makeController(warmer: warmer, sleeper: sleeper)

    controller.start()
    await controller.activeTask?.value

    XCTAssertEqual(sleeper.durations, [.seconds(5)])
    XCTAssertEqual(warmer.callCount, 1)
    XCTAssertEqual(warmer.basePriorities, [.utility])
    XCTAssertNil(controller.activeTask)
  }

  func testFailedWarmUpRetriesWithBackoffUntilItSucceeds() async {
    let warmer = ScriptedWarmer([.fail, .fail, .succeed])
    let sleeper = RecordingSleeper()
    let controller = makeController(warmer: warmer, sleeper: sleeper)

    controller.start()
    await controller.activeTask?.value

    XCTAssertEqual(sleeper.durations, [.seconds(5), .seconds(30), .seconds(120)])
    XCTAssertEqual(warmer.callCount, 3)
    XCTAssertNil(controller.activeTask)
  }

  func testRetriesStopAfterTheLastBackoffDelay() async {
    let warmer = ScriptedWarmer([.fail, .fail, .fail, .fail, .fail, .fail])
    let sleeper = RecordingSleeper()
    let controller = makeController(warmer: warmer, sleeper: sleeper)

    controller.start()
    await controller.activeTask?.value

    XCTAssertEqual(
      sleeper.durations,
      [.seconds(5), .seconds(30), .seconds(120), .seconds(600)]
    )
    XCTAssertEqual(warmer.callCount, 4)
    XCTAssertNil(controller.activeTask)
  }

  func testStopWhileWaitingCancelsWithoutWarmingUp() async {
    let warmer = ScriptedWarmer([.succeed])
    let sleeper = RecordingSleeper(holdingCalls: [0])
    let controller = makeController(warmer: warmer, sleeper: sleeper)

    controller.start()
    await waitUntil { sleeper.durations.count == 1 }
    let task = controller.activeTask
    controller.stop()
    await task?.value

    XCTAssertEqual(warmer.callCount, 0)
    XCTAssertNil(controller.activeTask)
  }

  func testStopDuringWarmUpCancelsItWithoutRetrying() async {
    let warmer = ScriptedWarmer([.holdUntilCancelled])
    let sleeper = RecordingSleeper()
    let controller = makeController(warmer: warmer, sleeper: sleeper)

    controller.start()
    await waitUntil { warmer.callCount == 1 }
    let task = controller.activeTask
    controller.stop()
    await task?.value

    XCTAssertEqual(warmer.cancellationCount, 1)
    XCTAssertEqual(sleeper.durations, [.seconds(5)])
    XCTAssertNil(controller.activeTask)
  }

  func testResumeWhileWaitingRestartsWithTheResumeDelay() async {
    let warmer = ScriptedWarmer([.succeed])
    let sleeper = RecordingSleeper(holdingCalls: [0])
    let controller = makeController(warmer: warmer, sleeper: sleeper)

    controller.start()
    await waitUntil { sleeper.durations.count == 1 }
    let launchTask = controller.activeTask
    controller.systemResumed()
    await launchTask?.value
    await controller.activeTask?.value

    XCTAssertEqual(sleeper.durations, [.seconds(5), .seconds(3)])
    XCTAssertEqual(warmer.callCount, 1)
    XCTAssertNil(controller.activeTask)
  }

  func testResumeDuringWarmUpIsCoalescedIntoTheRunningWarmUp() async {
    let warmer = ScriptedWarmer([.holdUntilReleased])
    let sleeper = RecordingSleeper()
    let controller = makeController(warmer: warmer, sleeper: sleeper)

    controller.start()
    await waitUntil { warmer.callCount == 1 }
    controller.systemResumed()
    warmer.release()
    await controller.activeTask?.value

    XCTAssertEqual(sleeper.durations, [.seconds(5)])
    XCTAssertEqual(warmer.callCount, 1)
    XCTAssertEqual(warmer.cancellationCount, 0)
    XCTAssertNil(controller.activeTask)
  }

  func testResumeAfterACompletedWarmUpWarmsUpAgain() async {
    let warmer = ScriptedWarmer([.succeed, .succeed])
    let sleeper = RecordingSleeper()
    let controller = makeController(warmer: warmer, sleeper: sleeper)

    controller.start()
    await controller.activeTask?.value
    controller.systemResumed()
    await controller.activeTask?.value

    XCTAssertEqual(sleeper.durations, [.seconds(5), .seconds(3)])
    XCTAssertEqual(warmer.callCount, 2)
  }

  func testStopBeforeStartIsHarmless() {
    let warmer = ScriptedWarmer([])
    let controller = makeController(warmer: warmer, sleeper: RecordingSleeper())

    controller.stop()

    XCTAssertNil(controller.activeTask)
    XCTAssertEqual(warmer.callCount, 0)
  }

  func testDefaultScheduleWarmsSoonAfterLaunchAndBacksOffOnFailure() {
    XCTAssertEqual(RecognitionWarmUpController.defaultLaunchDelay, .seconds(5))
    XCTAssertEqual(RecognitionWarmUpController.defaultResumeDelay, .seconds(3))
    XCTAssertEqual(
      RecognitionWarmUpController.defaultRetryDelays,
      [.seconds(30), .seconds(120), .seconds(600)]
    )
  }

  private func makeController(
    warmer: ScriptedWarmer,
    sleeper: RecordingSleeper
  ) -> RecognitionWarmUpController {
    RecognitionWarmUpController(
      warmer: warmer,
      launchDelay: .seconds(5),
      resumeDelay: .seconds(3),
      retryDelays: [.seconds(30), .seconds(120), .seconds(600)],
      sleep: sleeper.sleep
    )
  }

  private func waitUntil(
    timeout: Duration = .seconds(2),
    _ condition: @escaping @MainActor () -> Bool
  ) async {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while !condition(), clock.now < deadline {
      try? await Task.sleep(for: .milliseconds(1))
    }
    XCTAssertTrue(condition())
  }
}

private final class ScriptedWarmer: RecognitionWarming, @unchecked Sendable {
  enum Step {
    case succeed
    case fail
    case holdUntilCancelled
    case holdUntilReleased
  }

  private let lock = NSLock()
  private var steps: [Step]
  private var calls = 0
  private var cancellations = 0
  private var released = false
  private var priorities: [TaskPriority?] = []

  init(_ steps: [Step]) {
    self.steps = steps
  }

  var callCount: Int {
    lock.withLock { calls }
  }

  var cancellationCount: Int {
    lock.withLock { cancellations }
  }

  var basePriorities: [TaskPriority?] {
    lock.withLock { priorities }
  }

  func release() {
    lock.withLock { released = true }
  }

  func warmUp() async throws {
    let step = lock.withLock {
      calls += 1
      priorities.append(Task.basePriority)
      return steps.isEmpty ? .succeed : steps.removeFirst()
    }
    switch step {
    case .succeed:
      return
    case .fail:
      throw VisionOCRError.recognitionFailed
    case .holdUntilCancelled:
      do {
        try await Task.sleep(for: .seconds(3_600))
      } catch {
        lock.withLock { cancellations += 1 }
        throw VisionOCRError.cancelled
      }
    case .holdUntilReleased:
      while !lock.withLock({ released }) {
        do {
          try await Task.sleep(for: .milliseconds(1))
        } catch {
          lock.withLock { cancellations += 1 }
          throw VisionOCRError.cancelled
        }
      }
    }
  }
}

private final class RecordingSleeper: @unchecked Sendable {
  private let lock = NSLock()
  private let holdingCalls: Set<Int>
  private var recordedDurations: [Duration] = []

  init(holdingCalls: Set<Int> = []) {
    self.holdingCalls = holdingCalls
  }

  var durations: [Duration] {
    lock.withLock { recordedDurations }
  }

  func sleep(_ duration: Duration) async throws {
    let index = lock.withLock {
      recordedDurations.append(duration)
      return recordedDurations.count - 1
    }
    if holdingCalls.contains(index) {
      try await Task.sleep(for: .seconds(3_600))
    }
    try Task.checkCancellation()
  }
}
