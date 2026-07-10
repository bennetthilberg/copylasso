import AppKit

@MainActor
protocol ApplicationTerminating: AnyObject {
  func terminate()
}

@MainActor
final class SystemApplicationTerminator: ApplicationTerminating {
  func terminate() {
    NSApplication.shared.terminate(nil)
  }
}
