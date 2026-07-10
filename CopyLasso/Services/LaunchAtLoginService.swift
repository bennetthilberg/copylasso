import ServiceManagement

enum LaunchAtLoginStatus: Equatable, Sendable {
  case disabled
  case enabled
  case requiresApproval
  case unavailable
}

enum PlatformLaunchAtLoginStatus: Equatable, Sendable {
  case notRegistered
  case enabled
  case requiresApproval
  case notFound
  case unavailable
}

enum LaunchAtLoginServiceError: Error, Equatable, Sendable {
  case unavailable
  case enableFailed
  case disableFailed
}

@MainActor
protocol LaunchAtLoginServicing: AnyObject {
  var status: LaunchAtLoginStatus { get }
  func enable() throws
  func disable() throws
  func openSystemSettings()
}

@MainActor
protocol LaunchAtLoginBackend: AnyObject {
  var status: PlatformLaunchAtLoginStatus { get }
  func register() throws
  func unregister() throws
  func openSystemSettings()
}

@MainActor
final class SystemLaunchAtLoginService: LaunchAtLoginServicing {
  private let backend: any LaunchAtLoginBackend

  var status: LaunchAtLoginStatus {
    switch backend.status {
    case .notRegistered, .notFound:
      .disabled
    case .enabled:
      .enabled
    case .requiresApproval:
      .requiresApproval
    case .unavailable:
      .unavailable
    }
  }

  init(backend: any LaunchAtLoginBackend = SMAppServiceBackend()) {
    self.backend = backend
  }

  func enable() throws {
    switch status {
    case .enabled:
      return
    case .disabled:
      do {
        try backend.register()
      } catch {
        throw LaunchAtLoginServiceError.enableFailed
      }
    case .requiresApproval:
      throw LaunchAtLoginServiceError.enableFailed
    case .unavailable:
      throw LaunchAtLoginServiceError.unavailable
    }
  }

  func disable() throws {
    switch backend.status {
    case .notRegistered:
      return
    case .notFound:
      try? backend.unregister()
    case .enabled, .requiresApproval:
      do {
        try backend.unregister()
      } catch {
        throw LaunchAtLoginServiceError.disableFailed
      }
    case .unavailable:
      throw LaunchAtLoginServiceError.unavailable
    }
  }

  func openSystemSettings() {
    backend.openSystemSettings()
  }
}

@MainActor
private final class SMAppServiceBackend: LaunchAtLoginBackend {
  private let service: SMAppService

  var status: PlatformLaunchAtLoginStatus {
    switch service.status {
    case .notRegistered:
      .notRegistered
    case .enabled:
      .enabled
    case .requiresApproval:
      .requiresApproval
    case .notFound:
      .notFound
    @unknown default:
      .unavailable
    }
  }

  init(service: SMAppService = .mainApp) {
    self.service = service
  }

  func register() throws {
    try service.register()
  }

  func unregister() throws {
    try service.unregister()
  }

  func openSystemSettings() {
    SMAppService.openSystemSettingsLoginItems()
  }
}

#if DEBUG
  @MainActor
  final class DebugLaunchAtLoginService: LaunchAtLoginServicing {
    var status: LaunchAtLoginStatus

    init(status: LaunchAtLoginStatus = .disabled) {
      self.status = status
    }

    func enable() throws {
      status = .enabled
    }

    func disable() throws {
      status = .disabled
    }

    func openSystemSettings() {}
  }
#endif
