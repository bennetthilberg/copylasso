import KeyboardShortcuts

@testable import CopyLasso

enum StubSettingsError: Error, Equatable {
  case injected
}

@MainActor
final class StubAppSettingsStore: AppSettingsStoring {
  var completedOnboardingVersion: Int
  var hasConfiguredCaptureShortcut = false
  var hasConfiguredLaunchAtLogin = false
  var successSoundPreferenceVersion = 0
  var isSuccessSoundEnabled = true
  var history = ScreenCapturePermissionHistory()
  private(set) var resetCallCount = 0

  init(completedOnboardingVersion: Int = 0) {
    self.completedOnboardingVersion = completedOnboardingVersion
  }

  func migrateSuccessSoundPreferenceIfNeeded() {
    guard
      successSoundPreferenceVersion
        < UserDefaultsSettingsStore.currentSuccessSoundPreferenceVersion
    else {
      return
    }
    successSoundPreferenceVersion =
      UserDefaultsSettingsStore.currentSuccessSoundPreferenceVersion
  }

  func reset() {
    resetCallCount += 1
    completedOnboardingVersion = 0
    hasConfiguredCaptureShortcut = false
    hasConfiguredLaunchAtLogin = false
    successSoundPreferenceVersion = 0
    isSuccessSoundEnabled = true
    history = ScreenCapturePermissionHistory()
  }
}

@MainActor
final class StubLaunchAtLoginService: LaunchAtLoginServicing {
  var status: LaunchAtLoginStatus = .disabled
  var statusAfterEnable: LaunchAtLoginStatus = .enabled
  var statusAfterDisable: LaunchAtLoginStatus = .disabled
  var enableError: StubSettingsError?
  var disableError: StubSettingsError?
  private(set) var enableCallCount = 0
  private(set) var disableCallCount = 0
  private(set) var openSettingsCallCount = 0

  func enable() throws {
    enableCallCount += 1
    if let enableError {
      throw enableError
    }
    status = statusAfterEnable
  }

  func disable() throws {
    disableCallCount += 1
    if let disableError {
      throw disableError
    }
    status = statusAfterDisable
  }

  func openSystemSettings() {
    openSettingsCallCount += 1
  }
}

@MainActor
final class StubGlobalShortcutStore: GlobalShortcutStoring {
  var captureShortcut: KeyboardShortcuts.Shortcut?
  private(set) var resetCallCount = 0

  func reset() {
    resetCallCount += 1
    captureShortcut = nil
  }
}

@MainActor
final class StubLaunchAtLoginBackend: LaunchAtLoginBackend {
  var status: PlatformLaunchAtLoginStatus
  var registerError: StubSettingsError?
  var unregisterError: StubSettingsError?
  private(set) var registerCallCount = 0
  private(set) var unregisterCallCount = 0
  private(set) var openSettingsCallCount = 0

  init(status: PlatformLaunchAtLoginStatus) {
    self.status = status
  }

  func register() throws {
    registerCallCount += 1
    if let registerError {
      throw registerError
    }
  }

  func unregister() throws {
    unregisterCallCount += 1
    if let unregisterError {
      throw unregisterError
    }
  }

  func openSystemSettings() {
    openSettingsCallCount += 1
  }
}

@MainActor
final class StubGlobalShortcutEventSource: GlobalShortcutEventSourcing {
  private var continuation: AsyncStream<GlobalShortcutEvent>.Continuation?
  private var cancellationWaiters: [CheckedContinuation<Void, Never>] = []
  private(set) var wasCancelled = false

  func events() -> AsyncStream<GlobalShortcutEvent> {
    AsyncStream { continuation in
      self.continuation = continuation
      continuation.onTermination = { [weak self] _ in
        Task { @MainActor in
          self?.markCancelled()
        }
      }
    }
  }

  func emit(_ event: GlobalShortcutEvent) {
    continuation?.yield(event)
  }

  func waitForCancellation() async {
    guard !wasCancelled else {
      return
    }
    await withCheckedContinuation { continuation in
      cancellationWaiters.append(continuation)
    }
  }

  private func markCancelled() {
    guard !wasCancelled else {
      return
    }
    wasCancelled = true
    let waiters = cancellationWaiters
    cancellationWaiters.removeAll()
    for waiter in waiters {
      waiter.resume()
    }
  }
}
