import Foundation
import OSLog

enum CaptureLifecycleDiagnostic: Equatable, Sendable {
  case cancelledForSystemInterruption
  case systemInterruptionWhileIdle
  case systemResumed
  case applicationWillTerminate
}

@MainActor
protocol CaptureLifecycleLogging: AnyObject {
  func record(_ event: CaptureLifecycleDiagnostic)
}

@MainActor
final class SystemCaptureLifecycleLogger: CaptureLifecycleLogging {
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "io.github.bennetthilberg.copylasso",
    category: "Lifecycle"
  )

  func record(_ event: CaptureLifecycleDiagnostic) {
    switch event {
    case .cancelledForSystemInterruption:
      logger.notice("Active capture cancelled for a screen or session interruption.")
    case .systemInterruptionWhileIdle:
      logger.notice("Screen or session interruption occurred while capture was idle.")
    case .systemResumed:
      logger.notice("Screen or session resumed; waiting for a new user capture request.")
    case .applicationWillTerminate:
      logger.notice("Application termination cleanup requested.")
    }
  }
}
