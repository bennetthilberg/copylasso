@MainActor
final class MenuBarCommandHandler {
  private let captureCommand: CaptureCommand
  private let applicationTerminator: any ApplicationTerminating

  var isCaptureEnabled: Bool {
    captureCommand.isEnabled
  }

  init(
    captureCommand: CaptureCommand,
    applicationTerminator: any ApplicationTerminating
  ) {
    self.captureCommand = captureCommand
    self.applicationTerminator = applicationTerminator
  }

  @discardableResult
  func captureText() -> CaptureTransitionResult {
    captureCommand.perform()
  }

  func quit() {
    applicationTerminator.terminate()
  }
}
