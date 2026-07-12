import AppKit
import CoreGraphics

enum AppKitRegionSelectionError: Error, Equatable, Sendable {
  case selectionAlreadyActive
  case noDisplays
  case missingDisplayIdentifier
  case duplicateDisplayIdentifier
  case invalidDisplayGeometry
  case backingScaleMismatch
  case surfaceCreationFailed
  case overlayFailedToHide
}

enum SelectionOverlayEvent: Equatable {
  case mouseDown(CGPoint)
  case mouseDragged(CGPoint)
  case mouseUp(CGPoint)
  case escape
}

enum SelectionOverlayRenderState: Equatable {
  case clear
  case dragging(rect: CGRect)
}

@MainActor
protocol SelectionDisplayProviding: AnyObject {
  func currentDisplays() throws -> [DisplayGeometry]
}

@MainActor
protocol SelectionOverlaySurface: AnyObject {
  var displayID: CGDirectDisplayID { get }
  var frame: CGRect { get }
  var isVisible: Bool { get }
  var eventHandler: ((SelectionOverlayEvent) -> Void)? { get set }

  func show()
  func makeInputReady(whenKey: @escaping @MainActor @Sendable () -> Void)
  func cancelInputReadiness()
  func refreshCursorRects()
  func render(_ state: SelectionOverlayRenderState)
  func hide()
}

@MainActor
protocol SelectionOverlaySurfaceMaking: AnyObject {
  func makeSurface(for display: DisplayGeometry) throws -> any SelectionOverlaySurface
}

@MainActor
protocol SelectionOverlayLifecycleObserving: AnyObject {
  func start(
    displayChange: @escaping () -> Void,
    applicationTermination: @escaping () -> Void
  )
  func stop()
}

@MainActor
protocol SelectionCursorManaging: AnyObject {
  func pushCrosshair()
  func popCrosshair()
}

@MainActor
protocol SelectionApplicationActivationManaging: AnyObject {
  func activateForSelection(whenActive: @escaping @MainActor @Sendable () -> Void)
  func restorePreviousApplication()
}

@MainActor
final class AppKitRegionSelectionService: RegionSelectionService {
  typealias CompletionWork = @MainActor @Sendable () -> Void
  typealias CompletionScheduler = @MainActor (@escaping CompletionWork) -> Void

  private let displayProvider: any SelectionDisplayProviding
  private let surfaceFactory: any SelectionOverlaySurfaceMaking
  private let lifecycleObserver: any SelectionOverlayLifecycleObserving
  private let cursorManager: any SelectionCursorManaging
  private let activationManager: any SelectionApplicationActivationManaging
  private let pointerLocation: () -> CGPoint
  private let scheduleCompletion: CompletionScheduler
  private var activeController: SelectionOverlayController?
  private var hasPendingContinuation = false

  var hasActiveSelection: Bool {
    activeController != nil
  }

  convenience init() {
    self.init(
      displayProvider: SystemSelectionDisplayProvider(),
      surfaceFactory: AppKitSelectionOverlaySurfaceFactory(),
      lifecycleObserver: SystemSelectionOverlayLifecycleObserver(),
      cursorManager: SystemSelectionCursorManager(),
      activationManager: SystemSelectionApplicationActivationManager()
    )
  }

  init(
    displayProvider: any SelectionDisplayProviding,
    surfaceFactory: any SelectionOverlaySurfaceMaking,
    lifecycleObserver: any SelectionOverlayLifecycleObserving,
    cursorManager: any SelectionCursorManaging,
    activationManager: any SelectionApplicationActivationManaging,
    pointerLocation: @escaping () -> CGPoint = { NSEvent.mouseLocation },
    scheduleCompletion: @escaping CompletionScheduler = AppKitRegionSelectionService
      .scheduleOnNextMainActorTurn
  ) {
    self.displayProvider = displayProvider
    self.surfaceFactory = surfaceFactory
    self.lifecycleObserver = lifecycleObserver
    self.cursorManager = cursorManager
    self.activationManager = activationManager
    self.pointerLocation = pointerLocation
    self.scheduleCompletion = scheduleCompletion
  }

  func selectRegion() async throws -> SelectionOutcome {
    guard activeController == nil, !hasPendingContinuation else {
      throw AppKitRegionSelectionError.selectionAlreadyActive
    }

    let displays = try validatedDisplays(displayProvider.currentDisplays())
    hasPendingContinuation = true

    return try await withCheckedThrowingContinuation { continuation in
      let controller = SelectionOverlayController(
        displays: displays,
        surfaceFactory: surfaceFactory,
        lifecycleObserver: lifecycleObserver,
        cursorManager: cursorManager,
        activationManager: activationManager,
        pointerLocation: pointerLocation
      )
      activeController = controller

      controller.start { [self] result in
        activeController = nil
        scheduleCompletion {
          self.hasPendingContinuation = false
          continuation.resume(with: result)
        }
      }
    }
  }

  func cancelSelection() {
    activeController?.cancel(.applicationTerminated)
  }

  private func validatedDisplays(_ displays: [DisplayGeometry]) throws -> [DisplayGeometry] {
    guard !displays.isEmpty else {
      throw AppKitRegionSelectionError.noDisplays
    }

    var identifiers = Set<CGDirectDisplayID>()
    for display in displays where !identifiers.insert(display.displayID).inserted {
      throw AppKitRegionSelectionError.duplicateDisplayIdentifier
    }
    return displays
  }

  private static func scheduleOnNextMainActorTurn(_ work: @escaping CompletionWork) {
    Task { @MainActor in
      await Task.yield()
      work()
    }
  }
}

@MainActor
private final class SelectionOverlayController {
  typealias Completion = (Result<SelectionOutcome, any Error>) -> Void

  private let displays: [DisplayGeometry]
  private let surfaceFactory: any SelectionOverlaySurfaceMaking
  private let lifecycleObserver: any SelectionOverlayLifecycleObserving
  private let cursorManager: any SelectionCursorManaging
  private let activationManager: any SelectionApplicationActivationManaging
  private let pointerLocation: () -> CGPoint
  private var surfaces: [any SelectionOverlaySurface] = []
  private var completion: Completion?
  private var hasFinished = false
  private var lifecycleStarted = false
  private var cursorPushed = false
  private var activationRequested = false
  private lazy var session = SelectionSession(displays: displays) { [weak self] outcome in
    self?.finish(.success(outcome))
  }

  init(
    displays: [DisplayGeometry],
    surfaceFactory: any SelectionOverlaySurfaceMaking,
    lifecycleObserver: any SelectionOverlayLifecycleObserving,
    cursorManager: any SelectionCursorManaging,
    activationManager: any SelectionApplicationActivationManaging,
    pointerLocation: @escaping () -> CGPoint
  ) {
    self.displays = displays
    self.surfaceFactory = surfaceFactory
    self.lifecycleObserver = lifecycleObserver
    self.cursorManager = cursorManager
    self.activationManager = activationManager
    self.pointerLocation = pointerLocation
  }

  func start(completion: @escaping Completion) {
    self.completion = completion
    lifecycleObserver.start(
      displayChange: { [weak self] in self?.cancel(.displayChanged) },
      applicationTermination: { [weak self] in self?.cancel(.applicationTerminated) }
    )
    lifecycleStarted = true
    activationRequested = true
    activationManager.activateForSelection { [weak self] in
      self?.applicationDidBecomeActive()
    }
  }

  private func applicationDidBecomeActive() {
    guard !hasFinished, activationRequested, surfaces.isEmpty else { return }

    do {
      for display in displays {
        let surface = try surfaceFactory.makeSurface(for: display)
        surface.eventHandler = { [weak self] event in
          self?.handle(event, from: display.displayID)
        }
        surface.render(.clear)
        surfaces.append(surface)
      }

      for surface in surfaces {
        surface.show()
      }
      let pointer = pointerLocation()
      inputSurface(at: pointer)?.makeInputReady { [weak self] in
        self?.initialInputSurfaceBecameKey()
      }
    } catch {
      finish(
        .failure((error as? AppKitRegionSelectionError) ?? .surfaceCreationFailed)
      )
    }
  }

  private func initialInputSurfaceBecameKey() {
    guard !hasFinished, !cursorPushed else { return }
    for surface in surfaces {
      surface.cancelInputReadiness()
      surface.refreshCursorRects()
    }
    cursorManager.pushCrosshair()
    cursorPushed = true
  }

  func cancel(_ reason: SelectionCancellationReason) {
    guard !hasFinished else { return }
    session.cancel(reason)
  }

  private func handle(_ event: SelectionOverlayEvent, from displayID: CGDirectDisplayID) {
    guard !hasFinished else { return }

    switch event {
    case .mouseDown(let point):
      let inputSurface = surfaces.first(where: { $0.displayID == displayID })
      inputSurface?.makeInputReady { [weak self] in
        self?.inputSurfaceBecameKeyDuringMouseDown(displayID: displayID)
      }
      guard session.begin(on: displayID, at: point) else { return }
      renderCurrentDrag()
    case .mouseDragged(let point):
      guard session.currentDisplayID != nil else { return }
      session.update(to: point)
      renderCurrentDrag()
    case .mouseUp(let point):
      session.finish(at: point)
    case .escape:
      session.cancel(.escape)
    }
  }

  private func inputSurfaceBecameKeyDuringMouseDown(displayID: CGDirectDisplayID) {
    guard !hasFinished else { return }
    if cursorPushed {
      refreshCursorRects(for: displayID)
    } else {
      initialInputSurfaceBecameKey()
    }
  }

  private func refreshCursorRects(for displayID: CGDirectDisplayID) {
    guard !hasFinished else { return }
    surfaces.first(where: { $0.displayID == displayID })?.refreshCursorRects()
  }

  private func renderCurrentDrag() {
    guard let initiatingDisplayID = session.currentDisplayID,
      let selectionRect = session.currentAppKitRect
    else {
      return
    }

    for surface in surfaces {
      if surface.displayID == initiatingDisplayID {
        surface.render(.dragging(rect: selectionRect))
      } else {
        surface.render(.clear)
      }
    }
  }

  private func finish(_ result: Result<SelectionOutcome, any Error>) {
    guard !hasFinished else { return }
    hasFinished = true

    let cleanupSucceeded = cleanup()
    let resolvedResult: Result<SelectionOutcome, any Error> =
      cleanupSucceeded ? result : .failure(AppKitRegionSelectionError.overlayFailedToHide)
    let completion = completion
    self.completion = nil
    completion?(resolvedResult)
  }

  private func cleanup() -> Bool {
    if lifecycleStarted {
      lifecycleObserver.stop()
      lifecycleStarted = false
    }

    for surface in surfaces {
      surface.cancelInputReadiness()
      surface.eventHandler = nil
      surface.render(.clear)
      surface.hide()
    }

    if cursorPushed {
      cursorManager.popCrosshair()
      cursorPushed = false
    }
    if activationRequested {
      activationManager.restorePreviousApplication()
      activationRequested = false
    }
    let everySurfaceHidden = surfaces.allSatisfy { !$0.isVisible }
    surfaces.removeAll()
    return everySurfaceHidden
  }

  private func inputSurface(at pointer: CGPoint) -> (any SelectionOverlaySurface)? {
    return surfaces.first(where: { $0.frame.contains(pointer) }) ?? surfaces.first
  }
}

@MainActor
struct SelectionDisplayMetadata: Equatable {
  let displayID: CGDirectDisplayID?
  let appKitFrame: CGRect
  let coreGraphicsBounds: CGRect
  let backingScale: CGFloat
  let hundredPointBackingSize: CGSize
}

@MainActor
final class SystemSelectionDisplayProvider: SelectionDisplayProviding {
  func currentDisplays() throws -> [DisplayGeometry] {
    let screens = NSScreen.screens
    guard !screens.isEmpty else {
      throw AppKitRegionSelectionError.noDisplays
    }

    var identifiers = Set<CGDirectDisplayID>()
    return try screens.map { screen in
      let backingCheck = screen.convertRectToBacking(
        CGRect(x: 0, y: 0, width: 100, height: 100)
      )
      let number =
        screen.deviceDescription[
          NSDeviceDescriptionKey("NSScreenNumber")
        ] as? NSNumber
      let displayID = number.map { CGDirectDisplayID($0.uint32Value) }
      let metadata = SelectionDisplayMetadata(
        displayID: displayID,
        appKitFrame: screen.frame,
        coreGraphicsBounds: displayID.map { CGDisplayBounds($0) } ?? .zero,
        backingScale: screen.backingScaleFactor,
        hundredPointBackingSize: backingCheck.size
      )
      return try Self.geometry(from: metadata, identifiers: &identifiers)
    }
  }

  static func geometry(
    from metadata: SelectionDisplayMetadata,
    identifiers: inout Set<CGDirectDisplayID>
  ) throws -> DisplayGeometry {
    guard let displayID = metadata.displayID else {
      throw AppKitRegionSelectionError.missingDisplayIdentifier
    }
    guard identifiers.insert(displayID).inserted else {
      throw AppKitRegionSelectionError.duplicateDisplayIdentifier
    }
    guard
      abs(metadata.hundredPointBackingSize.width / 100 - metadata.backingScale) < 0.01,
      abs(metadata.hundredPointBackingSize.height / 100 - metadata.backingScale) < 0.01
    else {
      throw AppKitRegionSelectionError.backingScaleMismatch
    }

    do {
      return try DisplayGeometry(
        displayID: displayID,
        appKitFrame: metadata.appKitFrame,
        coreGraphicsBounds: metadata.coreGraphicsBounds,
        backingScale: metadata.backingScale
      )
    } catch {
      throw AppKitRegionSelectionError.invalidDisplayGeometry
    }
  }
}

@MainActor
final class AppKitSelectionOverlaySurfaceFactory: SelectionOverlaySurfaceMaking {
  private let appearanceProvider: any AccessibilityAppearanceProviding

  convenience init() {
    self.init(appearanceProvider: SystemAccessibilityAppearanceProvider())
  }

  init(appearanceProvider: any AccessibilityAppearanceProviding) {
    self.appearanceProvider = appearanceProvider
  }

  func makeSurface(for display: DisplayGeometry) throws -> any SelectionOverlaySurface {
    AppKitSelectionOverlaySurface(
      display: display,
      style: appearanceProvider.currentAppearance.selectionOverlayStyle
    )
  }
}

@MainActor
private final class AppKitSelectionOverlaySurface: SelectionOverlaySurface {
  let displayID: CGDirectDisplayID
  let frame: CGRect
  var eventHandler: ((SelectionOverlayEvent) -> Void)? {
    didSet {
      contentView.eventHandler = eventHandler
    }
  }

  var isVisible: Bool {
    panel.isVisible
  }

  private let panel: RegionSelectionPanel
  private let contentView: RegionSelectionView

  init(display: DisplayGeometry, style: SelectionOverlayStyle) {
    displayID = display.displayID
    frame = display.appKitFrame
    panel = RegionSelectionPanel(
      contentRect: display.appKitFrame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    contentView = RegionSelectionView(
      frame: CGRect(origin: .zero, size: display.appKitFrame.size),
      style: style
    )

    panel.setFrame(display.appKitFrame, display: false)
    panel.level = .screenSaver
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    panel.isMovable = false
    panel.isMovableByWindowBackground = false
    panel.isReleasedWhenClosed = false
    panel.acceptsMouseMovedEvents = true
    panel.ignoresMouseEvents = false
    panel.animationBehavior = .none
    panel.contentView = contentView
    panel.title = "CopyLasso text selection overlay"
    panel.setAccessibilityIdentifier("copylasso.selection.overlay")
    panel.setAccessibilityLabel("CopyLasso text selection overlay")
    panel.setAccessibilityHelp("Drag to select text. Press Escape to cancel.")

    contentView.displayFrame = display.appKitFrame
  }

  func show() {
    panel.orderFrontRegardless()
  }

  func makeInputReady(whenKey: @escaping @MainActor @Sendable () -> Void) {
    panel.whenKey { [weak self] in
      guard let self else { return }
      panel.makeFirstResponder(contentView)
      whenKey()
    }
    panel.makeKey()
  }

  func cancelInputReadiness() {
    panel.cancelKeyReadiness()
  }

  func refreshCursorRects() {
    contentView.refreshCrosshairCursorRects()
  }

  func render(_ state: SelectionOverlayRenderState) {
    contentView.renderState = state
  }

  func hide() {
    cancelInputReadiness()
    panel.orderOut(nil)
  }
}

final class RegionSelectionPanel: NSPanel {
  private var keyReadiness: (@MainActor @Sendable () -> Void)?

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  func whenKey(_ readiness: @escaping @MainActor @Sendable () -> Void) {
    keyReadiness = readiness
    if isKeyWindow {
      completeKeyReadiness()
    }
  }

  func cancelKeyReadiness() {
    keyReadiness = nil
  }

  override func becomeKey() {
    super.becomeKey()
    completeKeyReadiness()
  }

  private func completeKeyReadiness() {
    let keyReadiness = keyReadiness
    self.keyReadiness = nil
    keyReadiness?()
  }
}

@MainActor
final class RegionSelectionView: NSView {
  var eventHandler: ((SelectionOverlayEvent) -> Void)?
  var displayFrame: CGRect = .zero
  var renderState: SelectionOverlayRenderState = .clear {
    didSet {
      needsDisplay = true
    }
  }
  override var acceptsFirstResponder: Bool { true }

  private let style: SelectionOverlayStyle

  init(frame frameRect: NSRect, style: SelectionOverlayStyle) {
    self.style = style
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
    setAccessibilityElement(true)
    setAccessibilityIdentifier("copylasso.selection.overlay")
    setAccessibilityRole(.group)
    setAccessibilityLabel("CopyLasso text selection overlay")
    setAccessibilityHelp("Drag to select text. Press Escape to cancel.")
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable")
  }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
  }

  override func resetCursorRects() {
    addCrosshairCursorRect()
  }

  func refreshCrosshairCursorRects() {
    guard let window else { return }
    window.invalidateCursorRects(for: self)
    window.resetCursorRects()
  }

  private func addCrosshairCursorRect() {
    addCursorRect(bounds, cursor: .crosshair)
  }

  override func cursorUpdate(with event: NSEvent) {
    NSCursor.crosshair.set()
  }

  override func mouseMoved(with event: NSEvent) {
    NSCursor.crosshair.set()
  }

  override func mouseDown(with event: NSEvent) {
    window?.makeKey()
    NSCursor.crosshair.set()
    guard let point = globalPoint(for: event) else { return }
    eventHandler?(.mouseDown(point))
  }

  override func mouseDragged(with event: NSEvent) {
    NSCursor.crosshair.set()
    guard let point = globalPoint(for: event) else { return }
    eventHandler?(.mouseDragged(point))
  }

  override func mouseUp(with event: NSEvent) {
    guard let point = globalPoint(for: event) else { return }
    eventHandler?(.mouseUp(point))
  }

  override func keyDown(with event: NSEvent) {
    if event.keyCode == 53 || event.charactersIgnoringModifiers == "\u{1b}" {
      eventHandler?(.escape)
    } else {
      super.keyDown(with: event)
    }
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    if case .dragging(let globalRect) = renderState {
      drawSelection(globalRect)
    }
  }

  private func drawSelection(_ globalRect: CGRect) {
    let localRect =
      globalRect
      .offsetBy(dx: -displayFrame.minX, dy: -displayFrame.minY)
      .intersection(bounds)
    guard !localRect.isNull else { return }

    NSGraphicsContext.saveGraphicsState()
    let outside = NSBezierPath(rect: bounds)
    outside.appendRect(localRect)
    outside.windingRule = .evenOdd
    NSColor.black.withAlphaComponent(style.dimOpacity).setFill()
    outside.fill()

    let border = NSBezierPath(rect: localRect)
    border.lineWidth = style.outerBorderWidth
    NSColor.black.setStroke()
    border.stroke()
    border.lineWidth = style.innerBorderWidth
    NSColor.white.setStroke()
    border.stroke()
    NSGraphicsContext.restoreGraphicsState()
  }

  private func globalPoint(for event: NSEvent) -> CGPoint? {
    window?.convertPoint(toScreen: event.locationInWindow)
  }
}

@MainActor
final class SystemSelectionCursorManager: SelectionCursorManaging {
  func pushCrosshair() {
    NSCursor.crosshair.push()
    NSCursor.crosshair.set()
  }

  func popCrosshair() {
    NSCursor.pop()
  }
}

@MainActor
final class SystemSelectionApplicationActivationManager: NSObject,
  SelectionApplicationActivationManaging
{
  private let notificationCenter: NotificationCenter
  private let observedApplication: AnyObject?
  private let isApplicationActive: () -> Bool
  private let activateApplication: () -> Void
  private var previousApplication: NSRunningApplication?
  private var hasActiveHandoff = false
  private var isObservingActivation = false
  private var activationReady: (@MainActor @Sendable () -> Void)?

  override convenience init() {
    self.init(
      notificationCenter: .default,
      observedApplication: NSApp,
      isApplicationActive: { NSApp.isActive },
      activateApplication: { NSApp.activate(ignoringOtherApps: true) }
    )
  }

  init(
    notificationCenter: NotificationCenter,
    observedApplication: AnyObject?,
    isApplicationActive: @escaping () -> Bool,
    activateApplication: @escaping () -> Void
  ) {
    self.notificationCenter = notificationCenter
    self.observedApplication = observedApplication
    self.isApplicationActive = isApplicationActive
    self.activateApplication = activateApplication
    super.init()
  }

  func activateForSelection(whenActive: @escaping @MainActor @Sendable () -> Void) {
    guard !hasActiveHandoff else { return }
    hasActiveHandoff = true

    let currentApplication = NSRunningApplication.current
    if let frontmostApplication = NSWorkspace.shared.frontmostApplication,
      frontmostApplication.processIdentifier != currentApplication.processIdentifier
    {
      previousApplication = frontmostApplication
    }

    activationReady = whenActive
    if isApplicationActive() {
      completeActivation()
      return
    }

    notificationCenter.addObserver(
      self,
      selector: #selector(applicationDidBecomeActive),
      name: NSApplication.didBecomeActiveNotification,
      object: observedApplication
    )
    isObservingActivation = true
    activateApplication()
  }

  func restorePreviousApplication() {
    guard hasActiveHandoff else { return }
    hasActiveHandoff = false
    stopObservingActivation()
    activationReady = nil

    guard let previousApplication else { return }
    self.previousApplication = nil
    guard !previousApplication.isTerminated else {
      NSApp.deactivate()
      return
    }

    NSApp.yieldActivation(to: previousApplication)
    _ = previousApplication.activate(from: .current, options: [])
  }

  @objc private func applicationDidBecomeActive() {
    completeActivation()
  }

  private func completeActivation() {
    guard hasActiveHandoff else { return }
    stopObservingActivation()
    let activationReady = activationReady
    self.activationReady = nil
    activationReady?()
  }

  private func stopObservingActivation() {
    guard isObservingActivation else { return }
    notificationCenter.removeObserver(
      self,
      name: NSApplication.didBecomeActiveNotification,
      object: observedApplication
    )
    isObservingActivation = false
  }

  deinit {
    notificationCenter.removeObserver(self)
  }
}

@MainActor
final class SystemSelectionOverlayLifecycleObserver: NSObject,
  SelectionOverlayLifecycleObserving
{
  private var displayChange: (() -> Void)?
  private var applicationTermination: (() -> Void)?
  private var isObserving = false

  func start(
    displayChange: @escaping () -> Void,
    applicationTermination: @escaping () -> Void
  ) {
    stop()
    self.displayChange = displayChange
    self.applicationTermination = applicationTermination
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenParametersChanged),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationWillTerminate),
      name: NSApplication.willTerminateNotification,
      object: nil
    )
    isObserving = true
  }

  func stop() {
    guard isObserving else { return }
    NotificationCenter.default.removeObserver(self)
    displayChange = nil
    applicationTermination = nil
    isObserving = false
  }

  @objc private func screenParametersChanged() {
    displayChange?()
  }

  @objc private func applicationWillTerminate() {
    applicationTermination?()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}
