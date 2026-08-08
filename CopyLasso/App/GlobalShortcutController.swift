import Foundation

enum GlobalShortcutEvent: Equatable, Sendable {
  case keyDown
  case keyUp
}

@MainActor
protocol GlobalShortcutEventSourcing: AnyObject {
  func start(_ handler: @escaping (GlobalShortcutEvent) -> Void)
  func stop()
}

@MainActor
final class GlobalShortcutController {
  private let captureCommand: CaptureCommand
  private let eventSource: any GlobalShortcutEventSourcing

  init(
    captureCommand: CaptureCommand,
    eventSource: any GlobalShortcutEventSourcing
  ) {
    self.captureCommand = captureCommand
    self.eventSource = eventSource
  }

  func start() {
    stop()
    eventSource.start { [weak self] event in
      guard event == .keyDown else {
        return
      }
      self?.captureCommand.performFromGlobalShortcut()
    }
  }

  func stop() {
    eventSource.stop()
  }
}
