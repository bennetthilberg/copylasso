import KeyboardShortcuts

enum GlobalShortcutEvent: Equatable, Sendable {
  case keyDown
  case keyUp
}

@MainActor
protocol GlobalShortcutEventSourcing: AnyObject {
  func events() -> AsyncStream<GlobalShortcutEvent>
}

@MainActor
final class GlobalShortcutController {
  private let captureCommand: CaptureCommand
  private let eventSource: any GlobalShortcutEventSourcing
  private var listenerTasks: [Task<Void, Never>] = []

  init(
    captureCommand: CaptureCommand,
    eventSource: any GlobalShortcutEventSourcing
  ) {
    self.captureCommand = captureCommand
    self.eventSource = eventSource
  }

  func start() {
    stop()
    let stream = eventSource.events()
    let task = Task { @MainActor [weak self] in
      for await event in stream where event == .keyUp {
        guard !Task.isCancelled else {
          return
        }
        self?.captureCommand.perform()
      }
    }
    listenerTasks.append(task)
  }

  func stop() {
    for task in listenerTasks {
      task.cancel()
    }
    listenerTasks.removeAll()
  }
}

@MainActor
final class KeyboardShortcutsEventSource: GlobalShortcutEventSourcing {
  func events() -> AsyncStream<GlobalShortcutEvent> {
    AsyncStream { continuation in
      let task = Task { @MainActor in
        for await event in KeyboardShortcuts.events(for: .captureText) {
          switch event {
          case .keyDown:
            continuation.yield(.keyDown)
          case .keyUp:
            continuation.yield(.keyUp)
          }
        }
        continuation.finish()
      }
      continuation.onTermination = { _ in
        task.cancel()
      }
    }
  }
}
