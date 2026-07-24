import AppKit

@MainActor
final class MenuBarCommandHandler {
  private let captureCommand: CaptureCommand
  private let applicationTerminator: any ApplicationTerminating
  private let activateApplication: () -> Void

  var isCaptureEnabled: Bool {
    captureCommand.isEnabled
  }

  init(
    captureCommand: CaptureCommand,
    applicationTerminator: any ApplicationTerminating,
    activateApplication: @escaping () -> Void = {
      NSApp.activate(ignoringOtherApps: true)
    }
  ) {
    self.captureCommand = captureCommand
    self.applicationTerminator = applicationTerminator
    self.activateApplication = activateApplication
  }

  @discardableResult
  func capture() -> CaptureTransitionResult {
    captureCommand.perform()
  }

  func openSettings(_ open: () -> Void) {
    activateApplication()
    open()
  }

  func quit() {
    applicationTerminator.terminate()
  }
}
