import AppKit
import Carbon.HIToolbox
import KeyboardShortcuts

@MainActor
protocol GlobalShortcutHotKeyRegistering: AnyObject {
  var eventHandler: ((GlobalShortcutEvent) -> Void)? { get set }
  func register(_ shortcut: KeyboardShortcuts.Shortcut?)
}

@MainActor
final class SystemGlobalShortcutEventSource: GlobalShortcutEventSourcing {
  typealias ShortcutProvider = @MainActor () -> KeyboardShortcuts.Shortcut?
  typealias ApplicationActiveProvider = @MainActor () -> Bool

  private static let shortcutChangedNotification = Notification.Name(
    "KeyboardShortcuts_shortcutByNameDidChange"
  )
  private static let recorderActiveChangedNotification = Notification.Name(
    "KeyboardShortcuts_recorderActiveStatusDidChange"
  )

  private let registrar: any GlobalShortcutHotKeyRegistering
  private let notificationCenter: NotificationCenter
  private let observedApplication: AnyObject?
  private let isApplicationActive: ApplicationActiveProvider
  private let shortcutProvider: ShortcutProvider
  private var continuation: AsyncStream<GlobalShortcutEvent>.Continuation?
  private var notificationObservers: [NSObjectProtocol] = []
  private var streamGeneration = 0
  private var isRecorderActive = false
  private var hasRegistrationState = false
  private var registeredShortcut: KeyboardShortcuts.Shortcut?

  convenience init() {
    self.init(registrar: SystemGlobalShortcutHotKeyRegistrar())
  }

  init(
    registrar: any GlobalShortcutHotKeyRegistering,
    notificationCenter: NotificationCenter = .default,
    observedApplication: AnyObject? = NSApp,
    isApplicationActive: @escaping ApplicationActiveProvider = { NSApp.isActive },
    shortcutProvider: @escaping ShortcutProvider = {
      KeyboardShortcuts.getShortcut(for: .captureText)
    }
  ) {
    self.registrar = registrar
    self.notificationCenter = notificationCenter
    self.observedApplication = observedApplication
    self.isApplicationActive = isApplicationActive
    self.shortcutProvider = shortcutProvider
  }

  func events() -> AsyncStream<GlobalShortcutEvent> {
    stopListening()
    streamGeneration += 1
    let generation = streamGeneration

    return AsyncStream { continuation in
      self.continuation = continuation
      registrar.eventHandler = { event in
        continuation.yield(event)
      }
      observeShortcutChanges()
      updateHotKeyRegistration()

      continuation.onTermination = { [weak self] _ in
        Task { @MainActor [weak self] in
          self?.stopListening(ifGenerationMatches: generation)
        }
      }
    }
  }

  private func observeShortcutChanges() {
    notificationObservers.append(
      notificationCenter.addObserver(
        forName: Self.shortcutChangedNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        guard Thread.isMainThread else { return }
        MainActor.assumeIsolated {
          self?.updateHotKeyRegistration()
        }
      }
    )
    notificationObservers.append(
      notificationCenter.addObserver(
        forName: Self.recorderActiveChangedNotification,
        object: nil,
        queue: .main
      ) { [weak self] notification in
        let isRecorderActive = notification.userInfo?["isActive"] as? Bool ?? false
        guard Thread.isMainThread else { return }
        MainActor.assumeIsolated {
          guard let self else { return }
          self.isRecorderActive = isRecorderActive
          self.updateHotKeyRegistration()
        }
      }
    )
    for name in [
      NSApplication.didBecomeActiveNotification,
      NSApplication.didResignActiveNotification,
    ] {
      notificationObservers.append(
        notificationCenter.addObserver(
          forName: name,
          object: observedApplication,
          queue: .main
        ) { [weak self] _ in
          guard Thread.isMainThread else { return }
          MainActor.assumeIsolated {
            self?.updateHotKeyRegistration()
          }
        }
      )
    }
  }

  private func updateHotKeyRegistration() {
    let desiredShortcut =
      isRecorderActive && isApplicationActive()
      ? nil
      : shortcutProvider()
    guard
      !hasRegistrationState
        || desiredShortcut != registeredShortcut
    else {
      return
    }

    registrar.register(desiredShortcut)
    registeredShortcut = desiredShortcut
    hasRegistrationState = true
  }

  private func stopListening(ifGenerationMatches generation: Int? = nil) {
    if let generation, generation != streamGeneration {
      return
    }

    let wasListening = continuation != nil || !notificationObservers.isEmpty
    for observer in notificationObservers {
      notificationCenter.removeObserver(observer)
    }
    notificationObservers.removeAll()
    if wasListening {
      registrar.register(nil)
    }
    registrar.eventHandler = nil
    continuation = nil
    isRecorderActive = false
    hasRegistrationState = false
    registeredShortcut = nil
  }

  isolated deinit {
    stopListening()
  }
}

@MainActor
final class SystemGlobalShortcutHotKeyRegistrar: GlobalShortcutHotKeyRegistering {
  private static let signature: UInt32 = 0x434C_5353
  private static let identifier: UInt32 = 1
  private static let eventTypes = [
    EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    ),
    EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyReleased)
    ),
  ]

  var eventHandler: ((GlobalShortcutEvent) -> Void)?

  private var eventHandlerReference: EventHandlerRef?
  private var hotKeyReference: EventHotKeyRef?

  func register(_ shortcut: KeyboardShortcuts.Shortcut?) {
    unregisterHotKey()
    guard let shortcut else { return }
    guard installEventHandlerIfNeeded() else { return }

    var hotKeyReference: EventHotKeyRef?
    let status = RegisterEventHotKey(
      UInt32(shortcut.carbonKeyCode),
      UInt32(shortcut.carbonModifiers),
      EventHotKeyID(signature: Self.signature, id: Self.identifier),
      GetEventDispatcherTarget(),
      0,
      &hotKeyReference
    )
    guard status == noErr else { return }
    self.hotKeyReference = hotKeyReference
  }

  private func installEventHandlerIfNeeded() -> Bool {
    if eventHandlerReference != nil {
      return true
    }
    guard let dispatcher = GetEventDispatcherTarget() else {
      return false
    }

    var eventHandlerReference: EventHandlerRef?
    let status = InstallEventHandler(
      dispatcher,
      copyLassoGlobalShortcutHandler,
      Self.eventTypes.count,
      Self.eventTypes,
      Unmanaged.passUnretained(self).toOpaque(),
      &eventHandlerReference
    )
    guard status == noErr else { return false }
    self.eventHandlerReference = eventHandlerReference
    return true
  }

  fileprivate func handleEvent(_ event: EventRef?) -> OSStatus {
    guard let event else {
      return OSStatus(eventNotHandledErr)
    }

    var hotKeyIdentifier = EventHotKeyID()
    let status = GetEventParameter(
      event,
      UInt32(kEventParamDirectObject),
      UInt32(typeEventHotKeyID),
      nil,
      MemoryLayout<EventHotKeyID>.size,
      nil,
      &hotKeyIdentifier
    )
    guard status == noErr else { return status }
    guard
      hotKeyIdentifier.signature == Self.signature,
      hotKeyIdentifier.id == Self.identifier
    else {
      return OSStatus(eventNotHandledErr)
    }

    switch Int(GetEventKind(event)) {
    case kEventHotKeyPressed:
      eventHandler?(.keyDown)
      return noErr
    case kEventHotKeyReleased:
      eventHandler?(.keyUp)
      return noErr
    default:
      return OSStatus(eventNotHandledErr)
    }
  }

  private func unregisterHotKey() {
    guard let hotKeyReference else { return }
    UnregisterEventHotKey(hotKeyReference)
    self.hotKeyReference = nil
  }

  isolated deinit {
    unregisterHotKey()
    if let eventHandlerReference {
      RemoveEventHandler(eventHandlerReference)
    }
  }
}

nonisolated private func copyLassoGlobalShortcutHandler(
  _: EventHandlerCallRef?,
  event: EventRef?,
  userData: UnsafeMutableRawPointer?
) -> OSStatus {
  guard let userData, Thread.isMainThread else {
    return OSStatus(eventNotHandledErr)
  }

  let registrar = Unmanaged<SystemGlobalShortcutHotKeyRegistrar>
    .fromOpaque(userData)
    .takeUnretainedValue()
  let eventAddress = event.map { UInt(bitPattern: $0) }
  return MainActor.assumeIsolated {
    registrar.handleEvent(eventAddress.flatMap { EventRef(bitPattern: $0) })
  }
}
