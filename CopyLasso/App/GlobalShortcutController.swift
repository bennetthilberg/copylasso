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
  private var listenerTask: Task<Void, Never>?

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
    listenerTask = Task { @MainActor [weak self] in
      for await event in stream where event == .keyUp {
        guard !Task.isCancelled else {
          return
        }
        self?.captureCommand.perform()
      }
    }
  }

  func stop() {
    listenerTask?.cancel()
    listenerTask = nil
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
