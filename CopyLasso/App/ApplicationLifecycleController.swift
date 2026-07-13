import AppKit

enum ApplicationLifecycleEvent: Equatable, Sendable {
  case systemInterrupted
  case systemResumed
  case applicationWillTerminate
}

@MainActor
protocol ApplicationLifecycleEventSourcing: AnyObject {
  func start(handler: @escaping (ApplicationLifecycleEvent) -> Void)
  func stop()
}

@MainActor
final class ApplicationLifecycleController {
  typealias ShortcutStop = @MainActor () -> Void

  private let eventSource: any ApplicationLifecycleEventSourcing
  private let captureCanceller: any ActiveCaptureCancelling
  private let recoveryPresenter: any PermissionRecoveryPresenting
  private let stopShortcutDelivery: ShortcutStop
  private let logger: any CaptureLifecycleLogging
  private var isSystemInterrupted = false

  init(
    eventSource: any ApplicationLifecycleEventSourcing,
    captureCanceller: any ActiveCaptureCancelling,
    recoveryPresenter: any PermissionRecoveryPresenting,
    stopShortcutDelivery: @escaping ShortcutStop,
    logger: any CaptureLifecycleLogging
  ) {
    self.eventSource = eventSource
    self.captureCanceller = captureCanceller
    self.recoveryPresenter = recoveryPresenter
    self.stopShortcutDelivery = stopShortcutDelivery
    self.logger = logger
  }

  func start() {
    stop()
    eventSource.start { [weak self] event in
      self?.handle(event)
    }
  }

  func stop() {
    eventSource.stop()
    isSystemInterrupted = false
  }

  private func handle(_ event: ApplicationLifecycleEvent) {
    switch event {
    case .systemInterrupted:
      guard !isSystemInterrupted else { return }
      isSystemInterrupted = true
      let cancelled = captureCanceller.cancelActiveOperation(reason: .systemInterrupted)
      recoveryPresenter.dismiss()
      logger.record(cancelled ? .cancelledForSystemInterruption : .systemInterruptionWhileIdle)
    case .systemResumed:
      guard isSystemInterrupted else { return }
      isSystemInterrupted = false
      logger.record(.systemResumed)
    case .applicationWillTerminate:
      _ = captureCanceller.cancelActiveOperation(reason: .applicationTerminated)
      recoveryPresenter.dismiss()
      stopShortcutDelivery()
      logger.record(.applicationWillTerminate)
      stop()
    }
  }
}

@MainActor
final class SystemApplicationLifecycleEventSource: NSObject,
  ApplicationLifecycleEventSourcing
{
  private let applicationCenter: NotificationCenter
  private let workspaceCenter: NotificationCenter
  private var handler: ((ApplicationLifecycleEvent) -> Void)?
  private var isObserving = false

  init(
    applicationCenter: NotificationCenter = .default,
    workspaceCenter: NotificationCenter = NSWorkspace.shared.notificationCenter
  ) {
    self.applicationCenter = applicationCenter
    self.workspaceCenter = workspaceCenter
  }

  func start(handler: @escaping (ApplicationLifecycleEvent) -> Void) {
    stop()
    self.handler = handler
    for name in [
      NSWorkspace.willSleepNotification,
      NSWorkspace.screensDidSleepNotification,
      NSWorkspace.sessionDidResignActiveNotification,
    ] {
      workspaceCenter.addObserver(
        self,
        selector: #selector(systemInterrupted(_:)),
        name: name,
        object: nil
      )
    }
    for name in [
      NSWorkspace.didWakeNotification,
      NSWorkspace.screensDidWakeNotification,
      NSWorkspace.sessionDidBecomeActiveNotification,
    ] {
      workspaceCenter.addObserver(
        self,
        selector: #selector(systemResumed(_:)),
        name: name,
        object: nil
      )
    }
    applicationCenter.addObserver(
      self,
      selector: #selector(applicationWillTerminate(_:)),
      name: NSApplication.willTerminateNotification,
      object: nil
    )
    isObserving = true
  }

  func stop() {
    guard isObserving else { return }
    applicationCenter.removeObserver(self)
    workspaceCenter.removeObserver(self)
    handler = nil
    isObserving = false
  }

  @objc private func systemInterrupted(_ notification: Notification) {
    handler?(.systemInterrupted)
  }

  @objc private func systemResumed(_ notification: Notification) {
    handler?(.systemResumed)
  }

  @objc private func applicationWillTerminate(_ notification: Notification) {
    handler?(.applicationWillTerminate)
  }
}
