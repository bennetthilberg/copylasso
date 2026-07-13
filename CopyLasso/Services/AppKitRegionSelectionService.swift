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
  case applicationActivationFailed
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
    systemInterruption: @escaping () -> Void,
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
  func activateForSelection(
    whenActive: @escaping @MainActor @Sendable () -> Void,
    whenUnavailable: @escaping @MainActor @Sendable () -> Void
  )
  func restorePreviousApplication(
    whenInactive: @escaping @MainActor @Sendable () -> Void
  )
}

@MainActor
final class AppKitRegionSelectionService: RegionSelectionService {
  typealias CompletionWork = @MainActor @Sendable () -> Void
  typealias CompletionScheduler = @MainActor (@escaping CompletionWork) -> Void
  typealias CursorInstallationWork = @MainActor @Sendable () -> Void
  typealias CursorInstallationScheduler =
    @MainActor (
      @escaping CursorInstallationWork
    ) -> Void

  private let displayProvider: any SelectionDisplayProviding
  private let surfaceFactory: any SelectionOverlaySurfaceMaking
  private let lifecycleObserver: any SelectionOverlayLifecycleObserving
  private let cursorManager: any SelectionCursorManaging
  private let activationManager: any SelectionApplicationActivationManaging
  private let pointerLocation: () -> CGPoint
  private let scheduleCursorInstallation: CursorInstallationScheduler
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
    scheduleCursorInstallation: @escaping CursorInstallationScheduler = AppKitRegionSelectionService
      .scheduleOnNextMainActorTurn,
    scheduleCompletion: @escaping CompletionScheduler = AppKitRegionSelectionService
      .scheduleOnNextMainActorTurn
  ) {
    self.displayProvider = displayProvider
    self.surfaceFactory = surfaceFactory
    self.lifecycleObserver = lifecycleObserver
    self.cursorManager = cursorManager
    self.activationManager = activationManager
    self.pointerLocation = pointerLocation
    self.scheduleCursorInstallation = scheduleCursorInstallation
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
        pointerLocation: pointerLocation,
        scheduleCursorInstallation: scheduleCursorInstallation
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
  private let scheduleCursorInstallation:
    AppKitRegionSelectionService
      .CursorInstallationScheduler
  private var surfaces: [any SelectionOverlaySurface] = []
  private var completion: Completion?
  private var hasFinished = false
  private var lifecycleStarted = false
  private var cursorPushed = false
  private var cursorInstallationScheduled = false
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
    pointerLocation: @escaping () -> CGPoint,
    scheduleCursorInstallation:
      @escaping AppKitRegionSelectionService
      .CursorInstallationScheduler
  ) {
    self.displays = displays
    self.surfaceFactory = surfaceFactory
    self.lifecycleObserver = lifecycleObserver
    self.cursorManager = cursorManager
    self.activationManager = activationManager
    self.pointerLocation = pointerLocation
    self.scheduleCursorInstallation = scheduleCursorInstallation
  }

  func start(completion: @escaping Completion) {
    self.completion = completion
    lifecycleObserver.start(
      displayChange: { [weak self] in self?.cancel(.displayChanged) },
      systemInterruption: { [weak self] in self?.cancel(.systemInterrupted) },
      applicationTermination: { [weak self] in self?.cancel(.applicationTerminated) }
    )
    lifecycleStarted = true
    activationRequested = true
    activationManager.activateForSelection(
      whenActive: { [weak self] in
        self?.applicationDidBecomeActive()
      },
      whenUnavailable: { [weak self] in
        self?.finish(.failure(AppKitRegionSelectionError.applicationActivationFailed))
      }
    )
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
      let inputSurface = inputSurface(at: pointer)
      let inputSurfaceID = inputSurface?.displayID
      inputSurface?.makeInputReady { [weak self] in
        self?.inputSurfaceBecameKey(inputSurfaceID)
      }
    } catch {
      finish(
        .failure((error as? AppKitRegionSelectionError) ?? .surfaceCreationFailed)
      )
    }
  }

  private func inputSurfaceBecameKey(_ displayID: CGDirectDisplayID?) {
    guard !hasFinished else { return }
    for surface in surfaces {
      surface.cancelInputReadiness()
    }
    surfaces.first(where: { $0.displayID == displayID })?.refreshCursorRects()
    guard !cursorPushed, !cursorInstallationScheduled else { return }
    cursorInstallationScheduled = true
    scheduleCursorInstallation { [weak self] in
      self?.installCrosshairAfterCursorRectsSettle()
    }
  }

  private func installCrosshairAfterCursorRectsSettle() {
    cursorInstallationScheduled = false
    guard !hasFinished, !cursorPushed else { return }
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
        self?.inputSurfaceBecameKey(displayID)
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

    let cleanupSucceeded = cleanupSurfaces()
    let resolvedResult: Result<SelectionOutcome, any Error> =
      cleanupSucceeded ? result : .failure(AppKitRegionSelectionError.overlayFailedToHide)
    let completion = completion
    self.completion = nil

    guard activationRequested else {
      completion?(resolvedResult)
      return
    }
    activationRequested = false
    activationManager.restorePreviousApplication {
      completion?(resolvedResult)
    }
  }

  private func cleanupSurfaces() -> Bool {
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
  var displayFrame: CGRect = .zero {
    didSet {
      updateSelectionOutline()
    }
  }
  var renderState: SelectionOverlayRenderState = .clear {
    didSet {
      updateSelectionOutline()
      needsDisplay = true
    }
  }
  override var acceptsFirstResponder: Bool { true }

  private let style: SelectionOverlayStyle
  private let outlineLayer = CAShapeLayer()
  private static let outlineAnimationKey = "selectionOutlinePhase"

  init(frame frameRect: NSRect, style: SelectionOverlayStyle) {
    self.style = style
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
    configureOutlineLayer()
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

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    outlineLayer.contentsScale = window?.backingScaleFactor ?? 1
  }

  override func layout() {
    super.layout()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    outlineLayer.frame = bounds
    CATransaction.commit()
    updateSelectionOutline()
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
    guard let localRect = localSelectionRect(for: globalRect) else { return }

    NSGraphicsContext.saveGraphicsState()
    let outside = NSBezierPath(rect: bounds)
    outside.appendRect(localRect)
    outside.windingRule = .evenOdd
    NSColor.black.withAlphaComponent(style.dimOpacity).setFill()
    outside.fill()
    NSGraphicsContext.restoreGraphicsState()
  }

  private func configureOutlineLayer() {
    outlineLayer.name = "copylasso.selection.outline"
    outlineLayer.fillColor = nil
    outlineLayer.strokeColor =
      NSColor(
        calibratedWhite: style.outline.grayWhiteComponent,
        alpha: 1
      ).cgColor
    outlineLayer.lineWidth = style.outline.lineWidth
    outlineLayer.lineDashPattern = [
      NSNumber(value: style.outline.dashLength),
      NSNumber(value: style.outline.gapLength),
    ]
    outlineLayer.lineCap = .butt
    outlineLayer.lineJoin = .miter
    outlineLayer.lineDashPhase = 0
    outlineLayer.actions = [
      "bounds": NSNull(),
      "path": NSNull(),
      "position": NSNull(),
    ]
    outlineLayer.frame = bounds
    layer?.addSublayer(outlineLayer)
  }

  private func updateSelectionOutline() {
    let localRect: CGRect?
    if case .dragging(let globalRect) = renderState {
      localRect = localSelectionRect(for: globalRect)
    } else {
      localRect = nil
    }

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    outlineLayer.path = localRect.map {
      CGPath(
        roundedRect: $0,
        cornerWidth: style.outline.cornerRadius,
        cornerHeight: style.outline.cornerRadius,
        transform: nil
      )
    }
    CATransaction.commit()

    if localRect == nil || !style.outline.animates {
      outlineLayer.removeAnimation(forKey: Self.outlineAnimationKey)
    } else if outlineLayer.animation(forKey: Self.outlineAnimationKey) == nil {
      outlineLayer.add(makeOutlineAnimation(), forKey: Self.outlineAnimationKey)
    }
  }

  private func makeOutlineAnimation() -> CABasicAnimation {
    let animation = CABasicAnimation(keyPath: "lineDashPhase")
    animation.fromValue = 0
    animation.toValue = -(style.outline.dashLength + style.outline.gapLength)
    animation.duration = style.outline.phaseDuration
    animation.repeatCount = .infinity
    animation.timingFunction = CAMediaTimingFunction(name: .linear)
    return animation
  }

  private func localSelectionRect(for globalRect: CGRect) -> CGRect? {
    let localRect =
      globalRect
      .offsetBy(dx: -displayFrame.minX, dy: -displayFrame.minY)
      .intersection(bounds)
    return localRect.isNull ? nil : localRect
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
  typealias ActivationFallbackScheduler =
    @MainActor (@escaping @MainActor @Sendable () -> Void) -> Void

  private let notificationCenter: NotificationCenter
  private let observedApplication: AnyObject?
  private let isApplicationActive: () -> Bool
  private let activateApplication: () -> Void
  private let deactivateApplication: () -> Void
  private let frontmostApplication: () -> NSRunningApplication?
  private let currentProcessIdentifier: () -> pid_t
  private let requestPreviousApplicationActivation: (NSRunningApplication) -> Void
  private let scheduleActivationFallback: ActivationFallbackScheduler
  private var previousApplication: NSRunningApplication?
  private var hasActiveHandoff = false
  private var isObservingActivation = false
  private var isObservingDeactivation = false
  private var activationReady: (@MainActor @Sendable () -> Void)?
  private var activationUnavailable: (@MainActor @Sendable () -> Void)?
  private var restorationReady: (@MainActor @Sendable () -> Void)?

  override convenience init() {
    self.init(
      notificationCenter: .default,
      observedApplication: NSApp,
      isApplicationActive: { NSApp.isActive },
      activateApplication: { NSApp.activate(ignoringOtherApps: true) },
      deactivateApplication: { NSApp.deactivate() },
      frontmostApplication: { NSWorkspace.shared.frontmostApplication },
      currentProcessIdentifier: { NSRunningApplication.current.processIdentifier },
      requestPreviousApplicationActivation: { application in
        NSApp.yieldActivation(to: application)
        _ = application.activate(from: .current, options: [])
      },
      scheduleActivationFallback: Self.scheduleDefaultActivationFallback
    )
  }

  private static func scheduleDefaultActivationFallback(
    _ work: @escaping @MainActor @Sendable () -> Void
  ) {
    Task { @MainActor in
      try? await Task.sleep(for: .seconds(1))
      work()
    }
  }

  func activateForSelection(whenActive: @escaping @MainActor @Sendable () -> Void) {
    activateForSelection(whenActive: whenActive, whenUnavailable: {})
  }

  func activateForSelection(
    whenActive: @escaping @MainActor @Sendable () -> Void,
    whenUnavailable: @escaping @MainActor @Sendable () -> Void
  ) {
    guard !hasActiveHandoff else { return }
    hasActiveHandoff = true

    if let frontmostApplication = frontmostApplication(),
      frontmostApplication.processIdentifier != currentProcessIdentifier()
    {
      previousApplication = frontmostApplication
    }

    activationReady = whenActive
    activationUnavailable = whenUnavailable
    if isApplicationActive() {
      completeActivation()
      return
    }

    notificationCenter.addObserver(
      self,
      selector: #selector(applicationDidBecomeActive(_:)),
      name: NSApplication.didBecomeActiveNotification,
      object: observedApplication
    )
    isObservingActivation = true
    activateApplication()
    scheduleActivationFallback { [weak self] in
      self?.failActivationIfStillPending()
    }
  }

  private func failActivationIfStillPending() {
    guard hasActiveHandoff, activationReady != nil else { return }
    stopObservingActivation()
    activationReady = nil
    let activationUnavailable = activationUnavailable
    self.activationUnavailable = nil
    activationUnavailable?()
  }

  init(
    notificationCenter: NotificationCenter,
    observedApplication: AnyObject?,
    isApplicationActive: @escaping () -> Bool,
    activateApplication: @escaping () -> Void,
    deactivateApplication: @escaping () -> Void = {},
    frontmostApplication: @escaping () -> NSRunningApplication? = {
      NSWorkspace.shared.frontmostApplication
    },
    currentProcessIdentifier: @escaping () -> pid_t = {
      NSRunningApplication.current.processIdentifier
    },
    requestPreviousApplicationActivation: @escaping (NSRunningApplication) -> Void = {
      application in
      NSApp.yieldActivation(to: application)
      _ = application.activate(from: .current, options: [])
    },
    scheduleActivationFallback: @escaping ActivationFallbackScheduler =
      SystemSelectionApplicationActivationManager.scheduleDefaultActivationFallback
  ) {
    self.notificationCenter = notificationCenter
    self.observedApplication = observedApplication
    self.isApplicationActive = isApplicationActive
    self.activateApplication = activateApplication
    self.deactivateApplication = deactivateApplication
    self.frontmostApplication = frontmostApplication
    self.currentProcessIdentifier = currentProcessIdentifier
    self.requestPreviousApplicationActivation = requestPreviousApplicationActivation
    self.scheduleActivationFallback = scheduleActivationFallback
    super.init()
  }

  func restorePreviousApplication(
    whenInactive: @escaping @MainActor @Sendable () -> Void
  ) {
    guard hasActiveHandoff else {
      whenInactive()
      return
    }
    hasActiveHandoff = false
    stopObservingActivation()
    activationReady = nil
    activationUnavailable = nil

    guard isApplicationActive() else {
      previousApplication = nil
      whenInactive()
      return
    }

    restorationReady = whenInactive
    notificationCenter.addObserver(
      self,
      selector: #selector(applicationDidResignActive(_:)),
      name: NSApplication.didResignActiveNotification,
      object: observedApplication
    )
    isObservingDeactivation = true

    guard let previousApplication else {
      deactivateApplication()
      return
    }
    self.previousApplication = nil
    guard !previousApplication.isTerminated else {
      deactivateApplication()
      return
    }

    requestPreviousApplicationActivation(previousApplication)
    deactivateApplication()
  }

  @objc private func applicationDidBecomeActive(_ notification: Notification) {
    completeActivation()
  }

  @objc private func applicationDidResignActive(_ notification: Notification) {
    completeRestoration()
  }

  private func completeActivation() {
    guard hasActiveHandoff else { return }
    stopObservingActivation()
    let activationReady = activationReady
    self.activationReady = nil
    activationUnavailable = nil
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

  private func completeRestoration() {
    stopObservingDeactivation()
    let restorationReady = restorationReady
    self.restorationReady = nil
    restorationReady?()
  }

  private func stopObservingDeactivation() {
    guard isObservingDeactivation else { return }
    notificationCenter.removeObserver(
      self,
      name: NSApplication.didResignActiveNotification,
      object: observedApplication
    )
    isObservingDeactivation = false
  }

  deinit {
    notificationCenter.removeObserver(self)
  }
}

@MainActor
final class SystemSelectionOverlayLifecycleObserver: NSObject,
  SelectionOverlayLifecycleObserving
{
  private let applicationCenter: NotificationCenter
  private let workspaceCenter: NotificationCenter
  private var displayChange: (() -> Void)?
  private var systemInterruption: (() -> Void)?
  private var applicationTermination: (() -> Void)?
  private var isObserving = false

  init(
    applicationCenter: NotificationCenter = .default,
    workspaceCenter: NotificationCenter = NSWorkspace.shared.notificationCenter
  ) {
    self.applicationCenter = applicationCenter
    self.workspaceCenter = workspaceCenter
    super.init()
  }

  func start(
    displayChange: @escaping () -> Void,
    systemInterruption: @escaping () -> Void,
    applicationTermination: @escaping () -> Void
  ) {
    stop()
    self.displayChange = displayChange
    self.systemInterruption = systemInterruption
    self.applicationTermination = applicationTermination
    applicationCenter.addObserver(
      self,
      selector: #selector(screenParametersChanged(_:)),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )
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
    displayChange = nil
    systemInterruption = nil
    applicationTermination = nil
    isObserving = false
  }

  @objc private func screenParametersChanged(_ notification: Notification) {
    displayChange?()
  }

  @objc private func systemInterrupted(_ notification: Notification) {
    systemInterruption?()
  }

  @objc private func applicationWillTerminate(_ notification: Notification) {
    applicationTermination?()
  }

  deinit {
    applicationCenter.removeObserver(self)
    workspaceCenter.removeObserver(self)
  }
}
