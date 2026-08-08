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
  typealias ModifierFlagsProvider = @MainActor () -> NSEvent.ModifierFlags
  typealias ShortcutReleaseCheckScheduler =
    @MainActor (
      @escaping @MainActor @Sendable () -> Void
    ) -> Void

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
  private let modifierFlagsProvider: ModifierFlagsProvider
  private let scheduleShortcutReleaseCheck: ShortcutReleaseCheckScheduler
  private var eventHandler: ((GlobalShortcutEvent) -> Void)?
  private var notificationObservers: [NSObjectProtocol] = []
  private var isRecorderActive = false
  private var hasRegistrationState = false
  private var registeredShortcut: KeyboardShortcuts.Shortcut?
  private var isAwaitingShortcutRelease = false
  private var shortcutReleaseGeneration: UInt = 0

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
    },
    modifierFlagsProvider: @escaping ModifierFlagsProvider = {
      NSEvent.modifierFlags
    },
    scheduleShortcutReleaseCheck: @escaping ShortcutReleaseCheckScheduler = { work in
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(10))
        work()
      }
    }
  ) {
    self.registrar = registrar
    self.notificationCenter = notificationCenter
    self.observedApplication = observedApplication
    self.isApplicationActive = isApplicationActive
    self.shortcutProvider = shortcutProvider
    self.modifierFlagsProvider = modifierFlagsProvider
    self.scheduleShortcutReleaseCheck = scheduleShortcutReleaseCheck
  }

  func start(_ eventHandler: @escaping (GlobalShortcutEvent) -> Void) {
    stopListening()
    self.eventHandler = eventHandler
    registrar.eventHandler = { [weak self] event in
      self?.handleHotKeyEvent(event)
    }
    observeShortcutChanges()
    updateHotKeyRegistration()
  }

  func stop() {
    stopListening()
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

    invalidatePendingShortcut()
    registrar.register(desiredShortcut)
    registeredShortcut = desiredShortcut
    hasRegistrationState = true
  }

  private func handleHotKeyEvent(_ event: GlobalShortcutEvent) {
    guard !selectorSensitiveModifiers.isEmpty else {
      eventHandler?(event)
      return
    }

    switch event {
    case .keyDown:
      invalidatePendingShortcut()
      isAwaitingShortcutRelease = true
    case .keyUp:
      guard isAwaitingShortcutRelease else {
        eventHandler?(.keyUp)
        return
      }
      isAwaitingShortcutRelease = false
      deliverShortcutWhenReleased(generation: shortcutReleaseGeneration)
    }
  }

  private func deliverShortcutWhenReleased(generation: UInt) {
    guard
      generation == shortcutReleaseGeneration,
      eventHandler != nil
    else {
      return
    }
    guard !modifierFlagsProvider().intersection(selectorSensitiveModifiers).isEmpty else {
      eventHandler?(.keyDown)
      return
    }

    scheduleShortcutReleaseCheck { [weak self] in
      self?.deliverShortcutWhenReleased(generation: generation)
    }
  }

  private var selectorSensitiveModifiers: NSEvent.ModifierFlags {
    guard let modifiers = registeredShortcut?.modifiers else { return [] }
    var flags: NSEvent.ModifierFlags = []
    if modifiers.contains(.control) {
      flags.insert(.control)
    }
    if modifiers.contains(.shift) {
      flags.insert(.shift)
    }
    if modifiers.contains(.option) {
      flags.insert(.option)
    }
    return flags
  }

  private func invalidatePendingShortcut() {
    isAwaitingShortcutRelease = false
    shortcutReleaseGeneration &+= 1
  }

  private func stopListening() {
    invalidatePendingShortcut()
    let wasListening = eventHandler != nil || !notificationObservers.isEmpty
    for observer in notificationObservers {
      notificationCenter.removeObserver(observer)
    }
    notificationObservers.removeAll()
    if wasListening {
      registrar.register(nil)
    }
    registrar.eventHandler = nil
    eventHandler = nil
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
