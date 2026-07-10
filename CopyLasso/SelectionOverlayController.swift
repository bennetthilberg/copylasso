#if DEBUG
  import AppKit
  import CoreGraphics
  import Foundation

  enum SelectionOverlaySpikeError: Error, LocalizedError {
    case noDisplays
    case missingDisplayIdentifier
    case invalidDisplayGeometry

    var errorDescription: String? {
      switch self {
      case .noDisplays:
        "No displays are available for selection."
      case .missingDisplayIdentifier:
        "A connected display did not provide a Core Graphics identifier."
      case .invalidDisplayGeometry:
        "A connected display reported invalid geometry."
      }
    }
  }

  struct LiveDisplayDescriptor: Identifiable, Equatable {
    var id: CGDirectDisplayID { geometry.displayID }

    let name: String
    let geometry: DisplayGeometry
    let backingConversionScale: CGFloat

    var backingScaleMatchesConversion: Bool {
      abs(geometry.backingScale - backingConversionScale) < 0.001
    }

    static func current() throws -> [LiveDisplayDescriptor] {
      guard !NSScreen.screens.isEmpty else {
        throw SelectionOverlaySpikeError.noDisplays
      }

      return try NSScreen.screens.map { screen in
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else {
          throw SelectionOverlaySpikeError.missingDisplayIdentifier
        }

        let displayID = CGDirectDisplayID(number.uint32Value)
        let geometry: DisplayGeometry
        do {
          geometry = try DisplayGeometry(
            displayID: displayID,
            appKitFrame: screen.frame,
            coreGraphicsBounds: CGDisplayBounds(displayID),
            backingScale: screen.backingScaleFactor
          )
        } catch {
          throw SelectionOverlaySpikeError.invalidDisplayGeometry
        }

        let referenceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let convertedRect = screen.convertRectToBacking(referenceRect)
        return LiveDisplayDescriptor(
          name: screen.localizedName,
          geometry: geometry,
          backingConversionScale: convertedRect.width / referenceRect.width
        )
      }
    }
  }

  @MainActor
  final class SelectionOverlayController: NSObject {
    private struct Overlay {
      let panel: SelectionOverlayPanel
      let view: SelectionOverlayView
      let descriptor: LiveDisplayDescriptor
    }

    private let screens: [NSScreen]
    private let descriptors: [LiveDisplayDescriptor]
    private let completion: (SelectionOutcome) -> Void
    private var overlays: [Overlay] = []
    private var session: SelectionSession?
    private var started = false
    private var isFinishing = false
    private var pushedCrosshair = false

    init(
      screens: [NSScreen] = NSScreen.screens,
      descriptors: [LiveDisplayDescriptor]? = nil,
      completion: @escaping (SelectionOutcome) -> Void
    ) throws {
      guard !screens.isEmpty else {
        throw SelectionOverlaySpikeError.noDisplays
      }
      let resolvedDescriptors = try descriptors ?? LiveDisplayDescriptor.current()
      guard resolvedDescriptors.count == screens.count else {
        throw SelectionOverlaySpikeError.invalidDisplayGeometry
      }

      self.screens = screens
      self.descriptors = resolvedDescriptors
      self.completion = completion
      super.init()
    }

    func start() {
      guard !started else { return }
      started = true
      session = SelectionSession(displays: descriptors.map(\.geometry)) { [weak self] outcome in
        self?.finish(with: outcome)
      }

      overlays = zip(screens, descriptors).map { screen, descriptor in
        let panel = SelectionOverlayPanel(screen: screen)
        let view = SelectionOverlayView(
          frame: CGRect(origin: .zero, size: screen.frame.size),
          displayID: descriptor.id,
          displayFrame: descriptor.geometry.appKitFrame,
          controller: self
        )
        panel.contentView = view
        return Overlay(panel: panel, view: view, descriptor: descriptor)
      }

      NotificationCenter.default.addObserver(
        self,
        selector: #selector(screenParametersDidChange),
        name: NSApplication.didChangeScreenParametersNotification,
        object: nil
      )
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(applicationWillTerminate),
        name: NSApplication.willTerminateNotification,
        object: nil
      )

      NSCursor.crosshair.push()
      pushedCrosshair = true
      for overlay in overlays {
        overlay.panel.orderFrontRegardless()
      }

      let pointer = NSEvent.mouseLocation
      if let pointerOverlay = overlays.first(where: {
        $0.descriptor.geometry.contains(point: pointer)
      }) {
        pointerOverlay.panel.makeKey()
        pointerOverlay.panel.makeFirstResponder(pointerOverlay.view)
      }
      NSCursor.crosshair.set()
    }

    func mouseDown(at point: CGPoint, on displayID: CGDirectDisplayID) {
      guard !isFinishing, session?.begin(on: displayID, at: point) == true else { return }
      if let overlay = overlays.first(where: { $0.descriptor.id == displayID }) {
        overlay.panel.makeKey()
        overlay.panel.makeFirstResponder(overlay.view)
      }
      updateOverlayViews()
    }

    func mouseDragged(to point: CGPoint) {
      guard !isFinishing else { return }
      session?.update(to: point)
      updateOverlayViews()
    }

    func mouseUp(at point: CGPoint) {
      guard !isFinishing else { return }
      session?.finish(at: point)
    }

    func cancelWithEscape() {
      session?.cancel(.escape)
    }

    private func updateOverlayViews() {
      let initiatingDisplayID = session?.currentDisplayID
      let selectionRect = session?.currentAppKitRect
      for overlay in overlays {
        overlay.view.selectionRect =
          overlay.descriptor.id == initiatingDisplayID ? selectionRect : nil
      }
    }

    private func finish(with outcome: SelectionOutcome) {
      guard !isFinishing else { return }
      isFinishing = true
      cleanupOverlays()

      precondition(
        overlays.allSatisfy { !$0.panel.isVisible },
        "Selection overlay panels must be hidden before completion"
      )

      Task { @MainActor [completion] in
        await Task.yield()
        completion(outcome)
      }
    }

    private func cleanupOverlays() {
      NotificationCenter.default.removeObserver(self)
      for overlay in overlays {
        overlay.view.selectionRect = nil
        overlay.panel.orderOut(nil)
      }
      if pushedCrosshair {
        NSCursor.pop()
        pushedCrosshair = false
      }
    }

    @objc private func screenParametersDidChange() {
      session?.cancel(.displayChanged)
    }

    @objc private func applicationWillTerminate() {
      session?.cancel(.applicationTerminated)
    }

    deinit {
      NotificationCenter.default.removeObserver(self)
    }
  }

  @MainActor
  private final class SelectionOverlayPanel: NSPanel {
    init(screen: NSScreen) {
      super.init(
        contentRect: screen.frame,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
      )
      level = .screenSaver
      collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
      isOpaque = false
      backgroundColor = .clear
      hasShadow = false
      hidesOnDeactivate = false
      ignoresMouseEvents = false
      animationBehavior = .none
      isReleasedWhenClosed = false
      acceptsMouseMovedEvents = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
  }

  @MainActor
  private final class SelectionOverlayView: NSView {
    let displayID: CGDirectDisplayID
    let displayFrame: CGRect
    weak var controller: SelectionOverlayController?

    var selectionRect: CGRect? {
      didSet { needsDisplay = true }
    }

    init(
      frame: CGRect,
      displayID: CGDirectDisplayID,
      displayFrame: CGRect,
      controller: SelectionOverlayController
    ) {
      self.displayID = displayID
      self.displayFrame = displayFrame
      self.controller = controller
      super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
      addCursorRect(bounds, cursor: .crosshair)
    }

    override func cursorUpdate(with event: NSEvent) {
      NSCursor.crosshair.set()
    }

    override func mouseMoved(with event: NSEvent) {
      NSCursor.crosshair.set()
    }

    override func mouseDown(with event: NSEvent) {
      NSCursor.crosshair.set()
      guard let point = globalPoint(for: event) else { return }
      controller?.mouseDown(at: point, on: displayID)
    }

    override func mouseDragged(with event: NSEvent) {
      NSCursor.crosshair.set()
      guard let point = globalPoint(for: event) else { return }
      controller?.mouseDragged(to: point)
    }

    override func mouseUp(with event: NSEvent) {
      guard let point = globalPoint(for: event) else { return }
      controller?.mouseUp(at: point)
    }

    override func keyDown(with event: NSEvent) {
      if event.keyCode == 53 || event.charactersIgnoringModifiers == "\u{1b}" {
        controller?.cancelWithEscape()
      } else {
        super.keyDown(with: event)
      }
    }

    override func draw(_ dirtyRect: NSRect) {
      super.draw(dirtyRect)
      guard let selectionRect else { return }

      let localSelection = selectionRect.offsetBy(
        dx: -displayFrame.minX,
        dy: -displayFrame.minY
      )
      guard let context = NSGraphicsContext.current?.cgContext else { return }

      context.saveGState()
      context.setFillColor(NSColor.black.withAlphaComponent(0.18).cgColor)
      context.fill(bounds)
      context.setBlendMode(.clear)
      context.fill(localSelection)
      context.restoreGState()

      let borderRect = localSelection.insetBy(dx: 1.5, dy: 1.5)
      let border = NSBezierPath(rect: borderRect)
      border.lineJoinStyle = .miter
      border.lineWidth = 3
      NSColor.black.setStroke()
      border.stroke()
      border.lineWidth = 1
      NSColor.white.setStroke()
      border.stroke()
    }

    private func globalPoint(for event: NSEvent) -> CGPoint? {
      window?.convertPoint(toScreen: event.locationInWindow)
    }
  }
#endif
