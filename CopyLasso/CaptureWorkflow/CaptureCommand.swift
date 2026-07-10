@MainActor
final class CaptureCommand {
  typealias Completion = @MainActor @Sendable () -> Void
  typealias CompletionScheduler = @MainActor (@escaping Completion) -> Void

  private static let stubCompletionEvents: [CaptureEvent] = [
    .permissionGranted,
    .selectionCompleted,
    .captureCompleted,
    .recognitionCompleted,
    .completionFinished,
  ]

  private let coordinator: CaptureCoordinator
  private let scheduleCompletion: CompletionScheduler

  var isEnabled: Bool {
    !coordinator.isBusy
  }

  init(
    coordinator: CaptureCoordinator,
    scheduleCompletion: @escaping CompletionScheduler = CaptureCommand.scheduleOnNextMainActorTurn
  ) {
    self.coordinator = coordinator
    self.scheduleCompletion = scheduleCompletion
  }

  @discardableResult
  func perform() -> CaptureTransitionResult {
    let result = coordinator.handle(.requestCapture)
    guard case .transitioned = result else {
      return result
    }

    scheduleCompletion { [weak self] in
      self?.completeStubIfStillRequested()
    }
    return result
  }

  private func completeStubIfStillRequested() {
    guard coordinator.state == .requestingPermission else {
      return
    }

    for event in Self.stubCompletionEvents {
      guard case .transitioned = coordinator.handle(event) else {
        return
      }
    }
  }

  private static func scheduleOnNextMainActorTurn(_ completion: @escaping Completion) {
    Task { @MainActor in
      await Task.yield()
      completion()
    }
  }
}
