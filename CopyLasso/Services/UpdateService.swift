import Observation

@MainActor
protocol UpdateServicing: AnyObject {
  var automaticallyChecksForUpdates: Bool { get set }
  var canCheckForUpdates: Bool { get }
  var stateDidChange: (() -> Void)? { get set }

  func start() throws
  func checkForUpdates()
}

@MainActor
@Observable
final class UpdateController {
  private let service: any UpdateServicing

  private(set) var automaticallyChecksForUpdates: Bool
  private(set) var canCheckForUpdates: Bool
  private(set) var availabilityMessage: String?

  init(service: any UpdateServicing) {
    self.service = service
    automaticallyChecksForUpdates = service.automaticallyChecksForUpdates
    canCheckForUpdates = service.canCheckForUpdates
    service.stateDidChange = { [weak self] in
      self?.refresh()
    }
  }

  func start() {
    do {
      try service.start()
      availabilityMessage = nil
    } catch {
      availabilityMessage =
        "Secure updates are unavailable. Capture remains fully usable; reinstall CopyLasso or try again later."
    }
    refresh()
  }

  func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
    service.automaticallyChecksForUpdates = enabled
    refresh()
  }

  func checkForUpdates() {
    guard service.canCheckForUpdates else {
      return
    }
    service.checkForUpdates()
    refresh()
  }

  private func refresh() {
    automaticallyChecksForUpdates = service.automaticallyChecksForUpdates
    canCheckForUpdates = service.canCheckForUpdates
  }
}

#if DEBUG
  @MainActor
  final class DebugUpdateService: UpdateServicing {
    var automaticallyChecksForUpdates = true {
      didSet { stateDidChange?() }
    }
    var canCheckForUpdates = true
    var stateDidChange: (() -> Void)?

    func start() throws {
      stateDidChange?()
    }

    func checkForUpdates() {
      stateDidChange?()
    }
  }
#endif
