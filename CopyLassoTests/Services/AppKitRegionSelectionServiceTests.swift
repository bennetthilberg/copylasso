import AppKit
import CoreGraphics
import XCTest

@testable import CopyLasso

@MainActor
final class AppKitRegionSelectionServiceTests: XCTestCase {
  func testServiceConstructionDoesNotEnumerateOrShowAnything() throws {
    let display = try makeDisplay()
    let provider = StubSelectionDisplayProvider(results: [.success([display])])
    let factory = RecordingSelectionOverlaySurfaceFactory()
    let context = makeContext(provider: provider, factory: factory)

    XCTAssertNotNil(context.service)
    XCTAssertEqual(provider.callCount, 0)
    XCTAssertEqual(factory.requestedDisplayIDs, [])
    XCTAssertEqual(context.lifecycle.startCallCount, 0)
    XCTAssertEqual(context.cursor.pushCallCount, 0)
  }

  func testSelectionEnumeratesFreshDisplaysAndBuildsOneSurfacePerDisplay() async throws {
    let first = try makeDisplay(id: 1, origin: .zero)
    let second = try makeDisplay(id: 2, origin: CGPoint(x: -100, y: 0))
    let provider = StubSelectionDisplayProvider(results: [.success([first, second])])
    let factory = RecordingSelectionOverlaySurfaceFactory()
    let context = makeContext(provider: provider, factory: factory)

    let task = Task { try await context.service.selectRegion() }
    await Task.yield()

    XCTAssertEqual(provider.callCount, 1)
    XCTAssertEqual(factory.requestedDisplayIDs, [1, 2])
    XCTAssertEqual(factory.surfaces.map(\.frame), [first.appKitFrame, second.appKitFrame])
    XCTAssertTrue(factory.surfaces.allSatisfy(\.isVisible))
    XCTAssertEqual(context.lifecycle.startCallCount, 1)
    XCTAssertEqual(context.cursor.pushCallCount, 1)

    factory.surfaces[0].send(.escape)

    do {
      _ = try await context.service.selectRegion()
      XCTFail("Expected pending-continuation overlap rejection")
    } catch {
      XCTAssertEqual(error as? AppKitRegionSelectionError, .selectionAlreadyActive)
    }

    await context.scheduler.runNext()
    let outcome = try await task.value
    XCTAssertEqual(outcome, .cancelled(.escape))
  }

  func testSelectionActivatesBeforeShowingSurfacesAndRestoresBeforeCompletion() async throws {
    let display = try makeDisplay()
    let startupEvents = RecordingSelectionStartupEvents()
    let provider = StubSelectionDisplayProvider(results: [.success([display])])
    let factory = RecordingSelectionOverlaySurfaceFactory(startupEvents: startupEvents)
    let lifecycle = RecordingSelectionOverlayLifecycleObserver()
    let cursor = RecordingSelectionCursorManager(startupEvents: startupEvents)
    let activation = RecordingSelectionApplicationActivationManager(
      startupEvents: startupEvents
    )
    let scheduler = ManualSelectionCompletionScheduler()
    let service = AppKitRegionSelectionService(
      displayProvider: provider,
      surfaceFactory: factory,
      lifecycleObserver: lifecycle,
      cursorManager: cursor,
      activationManager: activation,
      scheduleCompletion: scheduler.schedule
    )

    let task = Task { try await service.selectRegion() }
    await Task.yield()

    XCTAssertEqual(startupEvents.events.first, .applicationActivationRequested)
    XCTAssertEqual(activation.activateCallCount, 1)
    XCTAssertEqual(activation.restoreCallCount, 0)

    factory.surfaces[0].send(.escape)

    XCTAssertEqual(activation.restoreCallCount, 1)
    XCTAssertEqual(startupEvents.events.last, .previousApplicationRestored)
    XCTAssertEqual(scheduler.pendingCount, 1)

    await scheduler.runNext()
    let outcome = try await task.value
    XCTAssertEqual(outcome, .cancelled(.escape))
  }

  func testSelectionWaitsForApplicationActivationBeforeShowingSurfacesOrCrosshair()
    async throws
  {
    let display = try makeDisplay()
    let provider = StubSelectionDisplayProvider(results: [.success([display])])
    let factory = RecordingSelectionOverlaySurfaceFactory()
    let activation = RecordingSelectionApplicationActivationManager(
      automaticallyCompletesActivation: false
    )
    let lifecycle = RecordingSelectionOverlayLifecycleObserver()
    let cursor = RecordingSelectionCursorManager()
    let scheduler = ManualSelectionCompletionScheduler()
    let service = AppKitRegionSelectionService(
      displayProvider: provider,
      surfaceFactory: factory,
      lifecycleObserver: lifecycle,
      cursorManager: cursor,
      activationManager: activation,
      scheduleCompletion: scheduler.schedule
    )

    let task = Task { try await service.selectRegion() }
    await Task.yield()

    XCTAssertEqual(activation.activateCallCount, 1)
    XCTAssertEqual(factory.requestedDisplayIDs, [])
    XCTAssertTrue(factory.surfaces.isEmpty)
    XCTAssertEqual(cursor.pushCallCount, 0)

    activation.completeActivation()

    XCTAssertEqual(factory.requestedDisplayIDs, [display.displayID])
    XCTAssertTrue(factory.surfaces[0].isVisible)
    XCTAssertEqual(factory.surfaces[0].suspendCursorRectManagementCallCount, 1)
    XCTAssertEqual(factory.surfaces[0].makeInputReadyCallCount, 1)
    XCTAssertEqual(cursor.pushCallCount, 1)

    factory.surfaces[0].send(.escape)
    await scheduler.runNext()
    let outcome = try await task.value
    XCTAssertEqual(outcome, .cancelled(.escape))
  }

  func testCancellationBeforeActivationIgnoresLateActivationReadiness() async throws {
    let display = try makeDisplay()
    let provider = StubSelectionDisplayProvider(results: [.success([display])])
    let factory = RecordingSelectionOverlaySurfaceFactory()
    let activation = RecordingSelectionApplicationActivationManager(
      automaticallyCompletesActivation: false
    )
    let lifecycle = RecordingSelectionOverlayLifecycleObserver()
    let cursor = RecordingSelectionCursorManager()
    let scheduler = ManualSelectionCompletionScheduler()
    let service = AppKitRegionSelectionService(
      displayProvider: provider,
      surfaceFactory: factory,
      lifecycleObserver: lifecycle,
      cursorManager: cursor,
      activationManager: activation,
      scheduleCompletion: scheduler.schedule
    )

    let task = Task { try await service.selectRegion() }
    await Task.yield()

    service.cancelSelection()
    XCTAssertEqual(activation.restoreCallCount, 1)
    activation.completeActivation()

    XCTAssertEqual(factory.requestedDisplayIDs, [])
    XCTAssertEqual(cursor.pushCallCount, 0)

    await scheduler.runNext()
    let outcome = try await task.value
    XCTAssertEqual(outcome, .cancelled(.applicationTerminated))
  }

  func testSelectionWaitsForPointerSurfaceToBecomeKeyBeforeInstallingCrosshair()
    async throws
  {
    let first = try makeDisplay(id: 1, origin: CGPoint(x: 50_000, y: 50_000))
    let second = try makeDisplay(id: 2, origin: CGPoint(x: 50_100, y: 50_000))
    let provider = StubSelectionDisplayProvider(results: [.success([first, second])])
    let factory = RecordingSelectionOverlaySurfaceFactory(
      automaticallyCompletesInputReadiness: false
    )
    let context = makeContext(provider: provider, factory: factory)

    let task = Task { try await context.service.selectRegion() }
    await Task.yield()

    XCTAssertTrue(factory.surfaces.allSatisfy(\.isVisible))
    XCTAssertEqual(factory.surfaces.map(\.makeInputReadyCallCount), [1, 0])
    XCTAssertEqual(factory.surfaces.map(\.suspendCursorRectManagementCallCount), [1, 1])
    XCTAssertEqual(context.cursor.pushCallCount, 0)

    factory.surfaces[0].completeInputReadiness()
    factory.surfaces[0].completeInputReadiness()

    XCTAssertEqual(context.cursor.pushCallCount, 1)

    factory.surfaces[0].send(.escape)
    await context.scheduler.runNext()
    let outcome = try await task.value
    XCTAssertEqual(outcome, .cancelled(.escape))
  }

  func testCursorRectManagementIsSuspendedBeforeKeyHandoffAndRestoredAfterHide()
    async throws
  {
    let first = try makeDisplay(id: 1, origin: CGPoint(x: 50_000, y: 50_000))
    let second = try makeDisplay(id: 2, origin: CGPoint(x: 50_100, y: 50_000))
    let provider = StubSelectionDisplayProvider(results: [.success([first, second])])
    let factory = RecordingSelectionOverlaySurfaceFactory(
      automaticallyCompletesInputReadiness: false
    )
    let context = makeContext(provider: provider, factory: factory)

    let task = Task { try await context.service.selectRegion() }
    await Task.yield()

    XCTAssertTrue(factory.surfaces.allSatisfy(\.isVisible))
    XCTAssertEqual(factory.surfaces.map(\.suspendCursorRectManagementCallCount), [1, 1])
    XCTAssertEqual(factory.surfaces.map(\.restoreCursorRectManagementCallCount), [0, 0])
    XCTAssertEqual(context.cursor.pushCallCount, 0)

    factory.surfaces[0].completeInputReadiness()
    XCTAssertEqual(context.cursor.pushCallCount, 1)

    factory.surfaces[0].send(.escape)

    XCTAssertTrue(factory.surfaces.allSatisfy { !$0.isVisible })
    XCTAssertEqual(factory.surfaces.map(\.restoreCursorRectManagementCallCount), [1, 1])
    XCTAssertEqual(factory.surfaces.map(\.restoreWhileVisibleCallCount), [0, 0])
    XCTAssertEqual(context.cursor.popCallCount, 1)

    await context.scheduler.runNext()
    let outcome = try await task.value
    XCTAssertEqual(outcome, .cancelled(.escape))
  }

  func testCancellationBeforePointerSurfaceBecomesKeySuppressesLateReadiness()
    async throws
  {
    let display = try makeDisplay()
    let provider = StubSelectionDisplayProvider(results: [.success([display])])
    let factory = RecordingSelectionOverlaySurfaceFactory(
      automaticallyCompletesInputReadiness: false
    )
    let context = makeContext(provider: provider, factory: factory)

    let task = Task { try await context.service.selectRegion() }
    await Task.yield()

    context.service.cancelSelection()
    factory.surfaces[0].completeInputReadiness()

    XCTAssertEqual(factory.surfaces[0].cancelInputReadinessCallCount, 1)
    XCTAssertEqual(factory.surfaces[0].suspendCursorRectManagementCallCount, 1)
    XCTAssertEqual(factory.surfaces[0].restoreCursorRectManagementCallCount, 1)
    XCTAssertEqual(context.cursor.pushCallCount, 0)
    XCTAssertEqual(context.cursor.popCallCount, 0)

    await context.scheduler.runNext()
    let outcome = try await task.value
    XCTAssertEqual(outcome, .cancelled(.applicationTerminated))
  }

  func testMouseDownKeyHandoffBeforeInitialReadinessStillInstallsCrosshairOnce()
    async throws
  {
    let first = try makeDisplay(id: 1, origin: CGPoint(x: 50_000, y: 50_000))
    let second = try makeDisplay(id: 2, origin: CGPoint(x: 50_100, y: 50_000))
    let provider = StubSelectionDisplayProvider(results: [.success([first, second])])
    let factory = RecordingSelectionOverlaySurfaceFactory(
      automaticallyCompletesInputReadiness: false
    )
    let context = makeContext(provider: provider, factory: factory)

    let task = Task { try await context.service.selectRegion() }
    await Task.yield()

    factory.surfaces[1].send(.mouseDown(CGPoint(x: 50_110, y: 50_010)))
    factory.surfaces[1].completeInputReadiness()
    factory.surfaces[0].completeInputReadiness()

    XCTAssertEqual(factory.surfaces.map(\.suspendCursorRectManagementCallCount), [1, 1])
    XCTAssertEqual(context.cursor.pushCallCount, 1)

    factory.surfaces[1].send(.escape)
    await context.scheduler.runNext()
    let outcome = try await task.value
    XCTAssertEqual(outcome, .cancelled(.escape))
  }

  func testCrosshairIsAppliedAfterVisibleSurfacesSuspendCursorRectsAndBecomeInputReady()
    async throws
  {
    let first = try makeDisplay(id: 1, origin: CGPoint(x: 50_000, y: 50_000))
    let second = try makeDisplay(id: 2, origin: CGPoint(x: 50_100, y: 50_000))
    let startupEvents = RecordingSelectionStartupEvents()
    let provider = StubSelectionDisplayProvider(results: [.success([first, second])])
    let factory = RecordingSelectionOverlaySurfaceFactory(startupEvents: startupEvents)
    let lifecycle = RecordingSelectionOverlayLifecycleObserver()
    let cursor = RecordingSelectionCursorManager(startupEvents: startupEvents)
    let activation = RecordingSelectionApplicationActivationManager(
      startupEvents: startupEvents
    )
    let scheduler = ManualSelectionCompletionScheduler()
    let service = AppKitRegionSelectionService(
      displayProvider: provider,
      surfaceFactory: factory,
      lifecycleObserver: lifecycle,
      cursorManager: cursor,
      activationManager: activation,
      scheduleCompletion: scheduler.schedule
    )

    let task = Task { try await service.selectRegion() }
    await Task.yield()

    XCTAssertEqual(
      startupEvents.events,
      [
        .applicationActivationRequested,
        .surfaceCursorRectsSuspended(1),
        .surfaceCursorRectsSuspended(2),
        .surfaceShown(1),
        .surfaceShown(2),
        .surfaceInputReady(1),
        .surfaceBecameKey(1),
        .crosshairPushed,
      ]
    )
    XCTAssertTrue(factory.surfaces.allSatisfy(\.isVisible))

    factory.surfaces[0].send(.escape)
    await scheduler.runNext()
    let outcome = try await task.value
    XCTAssertEqual(outcome, .cancelled(.escape))
  }

  func testSystemActivationManagerWaitsForDidBecomeActiveNotification() {
    let notificationCenter = NotificationCenter()
    let observedApplication = NSObject()
    var isActive = false
    var activateCallCount = 0
    var readyCallCount = 0
    let manager = SystemSelectionApplicationActivationManager(
      notificationCenter: notificationCenter,
      observedApplication: observedApplication,
      isApplicationActive: { isActive },
      activateApplication: { activateCallCount += 1 }
    )

    manager.activateForSelection {
      readyCallCount += 1
    }

    XCTAssertEqual(activateCallCount, 1)
    XCTAssertEqual(readyCallCount, 0)

    isActive = true
    notificationCenter.post(
      name: NSApplication.didBecomeActiveNotification,
      object: observedApplication
    )
    notificationCenter.post(
      name: NSApplication.didBecomeActiveNotification,
      object: observedApplication
    )

    XCTAssertEqual(readyCallCount, 1)
  }

  func testSystemActivationManagerCompletesImmediatelyWhenApplicationIsAlreadyActive() {
    let notificationCenter = NotificationCenter()
    let observedApplication = NSObject()
    var activateCallCount = 0
    var readyCallCount = 0
    let manager = SystemSelectionApplicationActivationManager(
      notificationCenter: notificationCenter,
      observedApplication: observedApplication,
      isApplicationActive: { true },
      activateApplication: { activateCallCount += 1 }
    )

    manager.activateForSelection {
      readyCallCount += 1
    }

    XCTAssertEqual(activateCallCount, 0)
    XCTAssertEqual(readyCallCount, 1)
  }

  func testRegionSelectionPanelCompletesKeyReadinessOnceAfterBecomingKey() {
    let panel = RegionSelectionPanel(
      contentRect: CGRect(x: 0, y: 0, width: 100, height: 100),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    var readyCallCount = 0

    panel.whenKey {
      readyCallCount += 1
    }
    XCTAssertEqual(readyCallCount, 0)

    panel.becomeKey()
    panel.becomeKey()

    XCTAssertEqual(readyCallCount, 1)
  }

  func testRegionSelectionPanelCanCancelPendingKeyReadiness() {
    let panel = RegionSelectionPanel(
      contentRect: CGRect(x: 0, y: 0, width: 100, height: 100),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    var readyCallCount = 0

    panel.whenKey {
      readyCallCount += 1
    }
    panel.cancelKeyReadiness()
    panel.becomeKey()

    XCTAssertEqual(readyCallCount, 0)
  }

  func testDraggingUsesOneThinGrayDashedOutlineWithSteadyLinearMotion() throws {
    let view = RegionSelectionView(
      frame: CGRect(x: 0, y: 0, width: 200, height: 100),
      style: SelectionOverlayStyle(
        dimOpacity: 0.18,
        outline: SelectionOutlineStyle(
          lineWidth: 1,
          grayWhiteComponent: 0.68,
          dashLength: 6,
          gapLength: 4,
          cornerRadius: 2,
          phaseDuration: 0.6,
          animates: true
        )
      )
    )
    view.displayFrame = CGRect(x: 1_000, y: 500, width: 200, height: 100)

    view.renderState = .dragging(
      rect: CGRect(x: 1_020, y: 530, width: 80, height: 40)
    )

    let outlineLayers = view.layer?.sublayers?.compactMap { $0 as? CAShapeLayer } ?? []
    guard outlineLayers.count == 1 else {
      return XCTFail("Expected one dedicated dashed outline layer")
    }
    let outline = outlineLayers[0]

    XCTAssertEqual(outline.name, "copylasso.selection.outline")
    XCTAssertEqual(outline.lineWidth, 1)
    XCTAssertEqual(outline.lineDashPattern, [6, 4])
    XCTAssertEqual(
      outline.path?.boundingBoxOfPath,
      CGRect(x: 20, y: 30, width: 80, height: 40)
    )
    let outlinePath = try XCTUnwrap(outline.path)
    var curveCount = 0
    outlinePath.applyWithBlock { element in
      if element.pointee.type == .addCurveToPoint {
        curveCount += 1
      }
    }
    XCTAssertEqual(curveCount, 4)

    let strokeColor = try XCTUnwrap(outline.strokeColor)
    let grayColor = try XCTUnwrap(NSColor(cgColor: strokeColor))
    XCTAssertEqual(grayColor.whiteComponent, 0.68, accuracy: 0.01)
    XCTAssertEqual(grayColor.alphaComponent, 1, accuracy: 0.01)

    XCTAssertEqual(outline.animationKeys(), ["selectionOutlinePhase"])
    let animation = try XCTUnwrap(
      outline.animation(forKey: "selectionOutlinePhase") as? CABasicAnimation
    )
    XCTAssertEqual(animation.keyPath, "lineDashPhase")
    XCTAssertEqual((animation.fromValue as? NSNumber)?.doubleValue, 0)
    XCTAssertEqual((animation.toValue as? NSNumber)?.doubleValue, -10)
    XCTAssertEqual(animation.duration, 0.6)
    XCTAssertEqual(animation.repeatCount, .infinity)

    let timingFunction = try XCTUnwrap(animation.timingFunction)
    var firstControlPoint = [Float](repeating: 0, count: 2)
    timingFunction.getControlPoint(at: 1, values: &firstControlPoint)
    var secondControlPoint = [Float](repeating: 0, count: 2)
    timingFunction.getControlPoint(at: 2, values: &secondControlPoint)
    XCTAssertEqual(firstControlPoint, [0, 0])
    XCTAssertEqual(secondControlPoint, [1, 1])
  }

  func testDashedOutlineTracksDragWithoutImplicitPathAnimationAndClears() throws {
    let appearance = AccessibilityAppearance(
      increaseContrast: false,
      differentiateWithoutColor: false,
      reduceTransparency: false,
      reduceMotion: false
    )
    let view = RegionSelectionView(
      frame: CGRect(x: 0, y: 0, width: 200, height: 100),
      style: appearance.selectionOverlayStyle
    )
    view.displayFrame = CGRect(x: 1_000, y: 500, width: 200, height: 100)

    view.renderState = .dragging(
      rect: CGRect(x: 1_020, y: 530, width: 80, height: 40)
    )
    let outline = try XCTUnwrap(
      view.layer?.sublayers?.compactMap { $0 as? CAShapeLayer }.first
    )

    view.renderState = .dragging(
      rect: CGRect(x: 1_040, y: 510, width: 120, height: 70)
    )

    XCTAssertEqual(
      outline.path?.boundingBoxOfPath,
      CGRect(x: 40, y: 10, width: 120, height: 70)
    )
    XCTAssertNil(outline.animation(forKey: "path"))
    XCTAssertEqual(outline.animationKeys(), ["selectionOutlinePhase"])

    view.renderState = .clear

    XCTAssertNil(outline.path)
    XCTAssertNil(outline.animationKeys())
  }

  func testReduceMotionUsesTheSameDashedOutlineWithoutPhaseAnimation() throws {
    let appearance = AccessibilityAppearance(
      increaseContrast: false,
      differentiateWithoutColor: false,
      reduceTransparency: false,
      reduceMotion: true
    )
    let view = RegionSelectionView(
      frame: CGRect(x: 0, y: 0, width: 200, height: 100),
      style: appearance.selectionOverlayStyle
    )
    view.renderState = .dragging(rect: CGRect(x: 20, y: 30, width: 80, height: 40))

    let outline = try XCTUnwrap(
      view.layer?.sublayers?.compactMap { $0 as? CAShapeLayer }.first
    )
    XCTAssertEqual(outline.lineDashPattern, [6, 4])
    XCTAssertNotNil(outline.path)
    XCTAssertNil(outline.animationKeys())
  }

  func testMouseDownMakesClickedNonInitialSurfaceInputReadyBeforeDragHandling()
    async throws
  {
    let first = try makeDisplay(id: 1, origin: CGPoint(x: 50_000, y: 50_000))
    let second = try makeDisplay(id: 2, origin: CGPoint(x: 50_100, y: 50_000))
    let startupEvents = RecordingSelectionStartupEvents()
    let provider = StubSelectionDisplayProvider(results: [.success([first, second])])
    let factory = RecordingSelectionOverlaySurfaceFactory(startupEvents: startupEvents)
    let context = makeContext(provider: provider, factory: factory)

    let task = Task { try await context.service.selectRegion() }
    await Task.yield()

    XCTAssertEqual(factory.surfaces.map(\.makeInputReadyCallCount), [1, 0])
    startupEvents.events.removeAll()

    factory.surfaces[1].send(.mouseDown(CGPoint(x: 50_110, y: 50_010)))

    XCTAssertEqual(factory.surfaces.map(\.makeInputReadyCallCount), [1, 1])
    XCTAssertEqual(
      startupEvents.events,
      [
        .surfaceInputReady(2),
        .surfaceBecameKey(2),
        .surfaceDragRendered(2),
      ]
    )

    factory.surfaces[1].send(.escape)
    await context.scheduler.runNext()
    let outcome = try await task.value
    XCTAssertEqual(outcome, .cancelled(.escape))
  }

  func testOverlayStartsClearAndOnlyInitiatingDisplayDimsDuringDrag() async throws {
    let first = try makeDisplay(id: 1, origin: .zero)
    let second = try makeDisplay(id: 2, origin: CGPoint(x: 100, y: 0))
    let factory = RecordingSelectionOverlaySurfaceFactory()
    let context = makeContext(
      provider: StubSelectionDisplayProvider(results: [.success([first, second])]),
      factory: factory
    )

    let task = Task { try await context.service.selectRegion() }
    await Task.yield()

    XCTAssertTrue(factory.surfaces.allSatisfy { $0.renderedStates == [.clear] })

    factory.surfaces[0].send(.mouseDown(CGPoint(x: 10, y: 10)))
    factory.surfaces[0].send(.mouseDragged(CGPoint(x: 150, y: 60)))

    XCTAssertEqual(
      factory.surfaces[0].renderedStates.last,
      .dragging(rect: CGRect(x: 10, y: 10, width: 90, height: 50))
    )
    XCTAssertEqual(factory.surfaces[1].renderedStates.last, .clear)

    factory.surfaces[0].send(.mouseUp(CGPoint(x: 150, y: 60)))
    await context.scheduler.runNext()
    let outcome = try await task.value
    guard case .selected(let result) = outcome else {
      return XCTFail("Expected a valid selection")
    }
    XCTAssertEqual(result.displayID, 1)
    XCTAssertEqual(result.appKitGlobalRect, CGRect(x: 10, y: 10, width: 90, height: 50))
    XCTAssertEqual(context.activation.activateCallCount, 1)
    XCTAssertEqual(context.activation.restoreCallCount, 1)
  }

  func testEveryMixedScaleDisplayCanInitiateUsingItsCompleteFrameAndIdentity() async throws {
    let displays = [
      try makeDisplay(id: 1, origin: .zero, scale: 1),
      try makeDisplay(id: 2, origin: CGPoint(x: -100, y: 25), scale: 2),
      try makeDisplay(id: 3, origin: CGPoint(x: 100, y: -40), scale: 1.5),
    ]

    for initiatingIndex in displays.indices {
      let factory = RecordingSelectionOverlaySurfaceFactory()
      let context = makeContext(
        provider: StubSelectionDisplayProvider(results: [.success(displays)]),
        factory: factory
      )
      let task = Task { try await context.service.selectRegion() }
      await Task.yield()

      XCTAssertEqual(factory.surfaces.map(\.frame), displays.map(\.appKitFrame))
      let display = displays[initiatingIndex]
      let start = CGPoint(x: display.appKitFrame.minX + 10, y: display.appKitFrame.minY + 10)
      let end = CGPoint(x: start.x + 50, y: start.y + 40)
      factory.surfaces[initiatingIndex].send(.mouseDown(start))
      factory.surfaces[initiatingIndex].send(.mouseUp(end))
      await context.scheduler.runNext()

      let outcome = try await task.value
      guard case .selected(let result) = outcome else {
        return XCTFail("Expected a selection on display \(display.displayID)")
      }
      XCTAssertEqual(result.displayID, display.displayID)
      XCTAssertEqual(result.displayPointSize, display.appKitFrame.size)
      XCTAssertEqual(result.backingScale, display.backingScale)
      XCTAssertEqual(
        result.backingPixelRect.size,
        CGSize(width: 50 * display.backingScale, height: 40 * display.backingScale)
      )
      XCTAssertTrue(factory.surfaces.allSatisfy { !$0.isVisible })
    }
  }

  func testEscapeCleansEverythingBeforeDeferredCompletion() async throws {
    let display = try makeDisplay()
    let factory = RecordingSelectionOverlaySurfaceFactory()
    let context = makeContext(
      provider: StubSelectionDisplayProvider(results: [.success([display])]),
      factory: factory
    )

    let task = Task { try await context.service.selectRegion() }
    await Task.yield()
    let surface = try XCTUnwrap(factory.surfaces.first)
    XCTAssertTrue(context.service.hasActiveSelection)

    surface.send(.escape)

    XCTAssertFalse(context.service.hasActiveSelection)
    XCTAssertFalse(surface.isVisible)
    XCTAssertNil(surface.eventHandler)
    XCTAssertEqual(surface.renderedStates.last, .clear)
    XCTAssertEqual(context.lifecycle.stopCallCount, 1)
    XCTAssertEqual(context.cursor.popCallCount, 1)
    XCTAssertEqual(context.scheduler.pendingCount, 1)

    await context.scheduler.runNext()
    let outcome = try await task.value
    XCTAssertEqual(outcome, .cancelled(.escape))
  }

  func testClickWithoutMeaningfulDragCancelsAsTooSmall() async throws {
    let display = try makeDisplay()
    let factory = RecordingSelectionOverlaySurfaceFactory()
    let context = makeContext(
      provider: StubSelectionDisplayProvider(results: [.success([display])]),
      factory: factory
    )

    let task = Task { try await context.service.selectRegion() }
    await Task.yield()
    factory.surfaces[0].send(.mouseDown(CGPoint(x: 25, y: 25)))
    factory.surfaces[0].send(.mouseUp(CGPoint(x: 25, y: 25)))
    await context.scheduler.runNext()

    let outcome = try await task.value
    XCTAssertEqual(outcome, .cancelled(.tooSmall))
    XCTAssertFalse(factory.surfaces[0].isVisible)
  }

  func testSurfaceThatRemainsVisibleFailsInsteadOfDeliveringAnOutcome() async throws {
    let display = try makeDisplay()
    let factory = RecordingSelectionOverlaySurfaceFactory(hideSucceeds: false)
    let context = makeContext(
      provider: StubSelectionDisplayProvider(results: [.success([display])]),
      factory: factory
    )

    let task = Task { try await context.service.selectRegion() }
    await Task.yield()
    factory.surfaces[0].send(.escape)
    await context.scheduler.runNext()

    do {
      _ = try await task.value
      XCTFail("Expected cleanup failure")
    } catch {
      XCTAssertEqual(error as? AppKitRegionSelectionError, .overlayFailedToHide)
    }
    XCTAssertEqual(context.activation.activateCallCount, 1)
    XCTAssertEqual(context.activation.restoreCallCount, 1)
  }

  func testDisplayChangeAndApplicationTerminationCancelExactlyOnce() async throws {
    for reason in [SelectionCancellationReason.displayChanged, .applicationTerminated] {
      let display = try makeDisplay()
      let factory = RecordingSelectionOverlaySurfaceFactory()
      let context = makeContext(
        provider: StubSelectionDisplayProvider(results: [.success([display])]),
        factory: factory
      )
      let task = Task { try await context.service.selectRegion() }
      await Task.yield()

      if reason == .displayChanged {
        context.lifecycle.sendDisplayChange()
        context.lifecycle.sendDisplayChange()
      } else {
        context.lifecycle.sendApplicationTermination()
        context.lifecycle.sendApplicationTermination()
      }

      XCTAssertEqual(context.scheduler.pendingCount, 1)
      await context.scheduler.runNext()
      let outcome = try await task.value
      XCTAssertEqual(outcome, .cancelled(reason))
      XCTAssertEqual(context.lifecycle.stopCallCount, 1)
      XCTAssertEqual(context.cursor.popCallCount, 1)
    }
  }

  func testExplicitLifecycleCancellationRemovesTheOverlay() async throws {
    let display = try makeDisplay()
    let factory = RecordingSelectionOverlaySurfaceFactory()
    let context = makeContext(
      provider: StubSelectionDisplayProvider(results: [.success([display])]),
      factory: factory
    )
    let task = Task { try await context.service.selectRegion() }
    await Task.yield()

    context.service.cancelSelection()
    await context.scheduler.runNext()

    let outcome = try await task.value
    XCTAssertEqual(outcome, .cancelled(.applicationTerminated))
    XCTAssertFalse(factory.surfaces[0].isVisible)
  }

  func testPartialSurfaceConstructionFailureCleansCreatedSurfacesAndCursor() async {
    let first = try? makeDisplay(id: 1, origin: .zero)
    let second = try? makeDisplay(id: 2, origin: CGPoint(x: 100, y: 0))
    guard let first, let second else {
      return XCTFail("Expected valid test geometry")
    }
    let factory = RecordingSelectionOverlaySurfaceFactory(failingDisplayID: 2)
    let context = makeContext(
      provider: StubSelectionDisplayProvider(results: [.success([first, second])]),
      factory: factory
    )

    let task = Task { try await context.service.selectRegion() }
    await Task.yield()
    await context.scheduler.runNext()

    do {
      _ = try await task.value
      XCTFail("Expected construction failure")
    } catch {
      XCTAssertEqual(error as? AppKitRegionSelectionError, .surfaceCreationFailed)
    }

    XCTAssertEqual(factory.surfaces.count, 1)
    XCTAssertFalse(factory.surfaces[0].isVisible)
    XCTAssertNil(factory.surfaces[0].eventHandler)
    XCTAssertEqual(context.lifecycle.stopCallCount, 1)
    XCTAssertEqual(context.cursor.pushCallCount, 0)
    XCTAssertEqual(context.cursor.popCallCount, 0)
    XCTAssertEqual(context.activation.activateCallCount, 1)
    XCTAssertEqual(context.activation.restoreCallCount, 1)
  }

  func testNoDisplaysAndDuplicateDisplayIdentifiersAreRejected() async throws {
    let duplicate = try makeDisplay(id: 7, origin: .zero)
    let cases: [([DisplayGeometry], AppKitRegionSelectionError)] = [
      ([], .noDisplays),
      ([duplicate, duplicate], .duplicateDisplayIdentifier),
    ]

    for (displays, expectedError) in cases {
      let context = makeContext(
        provider: StubSelectionDisplayProvider(results: [.success(displays)]),
        factory: RecordingSelectionOverlaySurfaceFactory()
      )
      do {
        _ = try await context.service.selectRegion()
        XCTFail("Expected invalid display rejection")
      } catch {
        XCTAssertEqual(error as? AppKitRegionSelectionError, expectedError)
      }
      XCTAssertEqual(context.cursor.pushCallCount, 0)
      XCTAssertEqual(context.activation.activateCallCount, 0)
      XCTAssertEqual(context.activation.restoreCallCount, 0)
    }
  }

  func testDisplayMetadataRejectsMissingDuplicateInvalidAndMismatchedValues() throws {
    let valid = SelectionDisplayMetadata(
      displayID: 1,
      appKitFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
      coreGraphicsBounds: CGRect(x: 0, y: 0, width: 100, height: 100),
      backingScale: 2,
      hundredPointBackingSize: CGSize(width: 200, height: 200)
    )
    var identifiers = Set<CGDirectDisplayID>()
    XCTAssertNoThrow(
      try SystemSelectionDisplayProvider.geometry(
        from: valid,
        identifiers: &identifiers
      )
    )

    let cases: [(SelectionDisplayMetadata, AppKitRegionSelectionError)] = [
      (
        SelectionDisplayMetadata(
          displayID: nil,
          appKitFrame: valid.appKitFrame,
          coreGraphicsBounds: valid.coreGraphicsBounds,
          backingScale: valid.backingScale,
          hundredPointBackingSize: valid.hundredPointBackingSize
        ),
        .missingDisplayIdentifier
      ),
      (valid, .duplicateDisplayIdentifier),
      (
        SelectionDisplayMetadata(
          displayID: 2,
          appKitFrame: .zero,
          coreGraphicsBounds: valid.coreGraphicsBounds,
          backingScale: valid.backingScale,
          hundredPointBackingSize: valid.hundredPointBackingSize
        ),
        .invalidDisplayGeometry
      ),
      (
        SelectionDisplayMetadata(
          displayID: 3,
          appKitFrame: valid.appKitFrame,
          coreGraphicsBounds: valid.coreGraphicsBounds,
          backingScale: valid.backingScale,
          hundredPointBackingSize: CGSize(width: 100, height: 100)
        ),
        .backingScaleMismatch
      ),
      (
        SelectionDisplayMetadata(
          displayID: 4,
          appKitFrame: valid.appKitFrame,
          coreGraphicsBounds: CGRect(x: 0, y: 0, width: 100, height: 99),
          backingScale: valid.backingScale,
          hundredPointBackingSize: valid.hundredPointBackingSize
        ),
        .invalidDisplayGeometry
      ),
    ]

    for (metadata, expectedError) in cases {
      var caseIdentifiers = metadata.displayID == 1 ? identifiers : []
      XCTAssertThrowsError(
        try SystemSelectionDisplayProvider.geometry(
          from: metadata,
          identifiers: &caseIdentifiers
        )
      ) { error in
        XCTAssertEqual(error as? AppKitRegionSelectionError, expectedError)
      }
    }
  }

  func testOverlappingSelectionIsRejectedThenServiceCanBeReused() async throws {
    let display = try makeDisplay()
    let provider = StubSelectionDisplayProvider(
      results: [.success([display]), .success([display])]
    )
    let factory = RecordingSelectionOverlaySurfaceFactory()
    let context = makeContext(provider: provider, factory: factory)

    let first = Task { try await context.service.selectRegion() }
    await Task.yield()

    do {
      _ = try await context.service.selectRegion()
      XCTFail("Expected overlap rejection")
    } catch {
      XCTAssertEqual(error as? AppKitRegionSelectionError, .selectionAlreadyActive)
    }

    factory.surfaces[0].send(.escape)
    await context.scheduler.runNext()
    let firstOutcome = try await first.value
    XCTAssertEqual(firstOutcome, .cancelled(.escape))

    let second = Task { try await context.service.selectRegion() }
    await Task.yield()
    XCTAssertEqual(provider.callCount, 2)
    factory.surfaces[1].send(.escape)
    await context.scheduler.runNext()
    let secondOutcome = try await second.value
    XCTAssertEqual(secondOutcome, .cancelled(.escape))
  }

  func testTwentySequentialSelectionsLeaveNoVisibleSurfaceOrObserver() async throws {
    let display = try makeDisplay()
    let provider = StubSelectionDisplayProvider(
      results: Array(repeating: .success([display]), count: 20)
    )
    let factory = RecordingSelectionOverlaySurfaceFactory()
    let context = makeContext(provider: provider, factory: factory)

    for index in 0..<20 {
      let task = Task { try await context.service.selectRegion() }
      await Task.yield()
      factory.surfaces[index].send(.escape)
      await context.scheduler.runNext()
      let outcome = try await task.value
      XCTAssertEqual(outcome, .cancelled(.escape))
    }

    XCTAssertEqual(provider.callCount, 20)
    XCTAssertEqual(context.lifecycle.startCallCount, 20)
    XCTAssertEqual(context.lifecycle.stopCallCount, 20)
    XCTAssertEqual(context.cursor.pushCallCount, 20)
    XCTAssertEqual(context.cursor.popCallCount, 20)
    XCTAssertEqual(context.activation.activateCallCount, 20)
    XCTAssertEqual(context.activation.restoreCallCount, 20)
    XCTAssertTrue(factory.surfaces.allSatisfy { !$0.isVisible && $0.eventHandler == nil })
  }

  private func makeContext(
    provider: StubSelectionDisplayProvider,
    factory: RecordingSelectionOverlaySurfaceFactory
  ) -> Context {
    let lifecycle = RecordingSelectionOverlayLifecycleObserver()
    let cursor = RecordingSelectionCursorManager()
    let activation = RecordingSelectionApplicationActivationManager()
    let scheduler = ManualSelectionCompletionScheduler()
    let service = AppKitRegionSelectionService(
      displayProvider: provider,
      surfaceFactory: factory,
      lifecycleObserver: lifecycle,
      cursorManager: cursor,
      activationManager: activation,
      scheduleCompletion: scheduler.schedule
    )
    return Context(
      service: service,
      lifecycle: lifecycle,
      cursor: cursor,
      activation: activation,
      scheduler: scheduler
    )
  }

  private func makeDisplay(
    id: CGDirectDisplayID = 1,
    origin: CGPoint = .zero,
    scale: CGFloat = 1
  ) throws -> DisplayGeometry {
    try DisplayGeometry(
      displayID: id,
      appKitFrame: CGRect(origin: origin, size: CGSize(width: 100, height: 100)),
      coreGraphicsBounds: CGRect(origin: origin, size: CGSize(width: 100, height: 100)),
      backingScale: scale
    )
  }

  private struct Context {
    let service: AppKitRegionSelectionService
    let lifecycle: RecordingSelectionOverlayLifecycleObserver
    let cursor: RecordingSelectionCursorManager
    let activation: RecordingSelectionApplicationActivationManager
    let scheduler: ManualSelectionCompletionScheduler
  }
}

@MainActor
private final class StubSelectionDisplayProvider: SelectionDisplayProviding {
  private var results: [Result<[DisplayGeometry], AppKitRegionSelectionError>]
  private(set) var callCount = 0

  init(results: [Result<[DisplayGeometry], AppKitRegionSelectionError>]) {
    self.results = results
  }

  func currentDisplays() throws -> [DisplayGeometry] {
    callCount += 1
    guard !results.isEmpty else {
      throw AppKitRegionSelectionError.noDisplays
    }
    return try results.removeFirst().get()
  }
}

@MainActor
private final class RecordingSelectionOverlaySurfaceFactory: SelectionOverlaySurfaceMaking {
  let failingDisplayID: CGDirectDisplayID?
  let hideSucceeds: Bool
  let startupEvents: RecordingSelectionStartupEvents?
  let automaticallyCompletesInputReadiness: Bool
  private(set) var requestedDisplayIDs: [CGDirectDisplayID] = []
  private(set) var surfaces: [RecordingSelectionOverlaySurface] = []

  init(
    failingDisplayID: CGDirectDisplayID? = nil,
    hideSucceeds: Bool = true,
    startupEvents: RecordingSelectionStartupEvents? = nil,
    automaticallyCompletesInputReadiness: Bool = true
  ) {
    self.failingDisplayID = failingDisplayID
    self.hideSucceeds = hideSucceeds
    self.startupEvents = startupEvents
    self.automaticallyCompletesInputReadiness = automaticallyCompletesInputReadiness
  }

  func makeSurface(for display: DisplayGeometry) throws -> any SelectionOverlaySurface {
    requestedDisplayIDs.append(display.displayID)
    if display.displayID == failingDisplayID {
      throw AppKitRegionSelectionError.surfaceCreationFailed
    }
    let surface = RecordingSelectionOverlaySurface(
      displayID: display.displayID,
      frame: display.appKitFrame,
      hideSucceeds: hideSucceeds,
      startupEvents: startupEvents,
      automaticallyCompletesInputReadiness: automaticallyCompletesInputReadiness
    )
    surfaces.append(surface)
    return surface
  }
}

@MainActor
private final class RecordingSelectionOverlaySurface: SelectionOverlaySurface {
  let displayID: CGDirectDisplayID
  let frame: CGRect
  let hideSucceeds: Bool
  var eventHandler: ((SelectionOverlayEvent) -> Void)?
  private(set) var isVisible = false
  private(set) var renderedStates: [SelectionOverlayRenderState] = []
  private(set) var makeInputReadyCallCount = 0
  private(set) var cancelInputReadinessCallCount = 0
  private(set) var suspendCursorRectManagementCallCount = 0
  private(set) var restoreCursorRectManagementCallCount = 0
  private(set) var restoreWhileVisibleCallCount = 0
  private let startupEvents: RecordingSelectionStartupEvents?
  private let automaticallyCompletesInputReadiness: Bool
  private var inputReadiness: (@MainActor @Sendable () -> Void)?

  init(
    displayID: CGDirectDisplayID,
    frame: CGRect,
    hideSucceeds: Bool,
    startupEvents: RecordingSelectionStartupEvents?,
    automaticallyCompletesInputReadiness: Bool
  ) {
    self.displayID = displayID
    self.frame = frame
    self.hideSucceeds = hideSucceeds
    self.startupEvents = startupEvents
    self.automaticallyCompletesInputReadiness = automaticallyCompletesInputReadiness
  }

  func show() {
    isVisible = true
    startupEvents?.events.append(.surfaceShown(displayID))
  }

  func makeInputReady(whenKey: @escaping @MainActor @Sendable () -> Void) {
    makeInputReadyCallCount += 1
    startupEvents?.events.append(.surfaceInputReady(displayID))
    inputReadiness = whenKey
    if automaticallyCompletesInputReadiness {
      completeInputReadiness()
    }
  }

  func cancelInputReadiness() {
    cancelInputReadinessCallCount += 1
    inputReadiness = nil
  }

  func completeInputReadiness() {
    let inputReadiness = inputReadiness
    self.inputReadiness = nil
    guard inputReadiness != nil else { return }
    startupEvents?.events.append(.surfaceBecameKey(displayID))
    inputReadiness?()
  }

  func suspendCursorRectManagement() {
    suspendCursorRectManagementCallCount += 1
    startupEvents?.events.append(.surfaceCursorRectsSuspended(displayID))
  }

  func restoreCursorRectManagement() {
    restoreCursorRectManagementCallCount += 1
    startupEvents?.events.append(.surfaceCursorRectsRestored(displayID))
    if isVisible {
      restoreWhileVisibleCallCount += 1
    }
  }

  func render(_ state: SelectionOverlayRenderState) {
    renderedStates.append(state)
    if case .dragging = state {
      startupEvents?.events.append(.surfaceDragRendered(displayID))
    }
  }

  func hide() {
    if hideSucceeds {
      isVisible = false
    }
  }

  func send(_ event: SelectionOverlayEvent) {
    eventHandler?(event)
  }
}

@MainActor
private final class RecordingSelectionOverlayLifecycleObserver: SelectionOverlayLifecycleObserving {
  private var displayChange: (() -> Void)?
  private var applicationTermination: (() -> Void)?
  private(set) var startCallCount = 0
  private(set) var stopCallCount = 0

  func start(
    displayChange: @escaping () -> Void,
    applicationTermination: @escaping () -> Void
  ) {
    startCallCount += 1
    self.displayChange = displayChange
    self.applicationTermination = applicationTermination
  }

  func stop() {
    stopCallCount += 1
    displayChange = nil
    applicationTermination = nil
  }

  func sendDisplayChange() {
    displayChange?()
  }

  func sendApplicationTermination() {
    applicationTermination?()
  }
}

@MainActor
private final class RecordingSelectionCursorManager: SelectionCursorManaging {
  private(set) var pushCallCount = 0
  private(set) var popCallCount = 0
  private let startupEvents: RecordingSelectionStartupEvents?

  init(startupEvents: RecordingSelectionStartupEvents? = nil) {
    self.startupEvents = startupEvents
  }

  func pushCrosshair() {
    pushCallCount += 1
    startupEvents?.events.append(.crosshairPushed)
  }

  func popCrosshair() {
    popCallCount += 1
  }
}

@MainActor
private final class RecordingSelectionApplicationActivationManager:
  SelectionApplicationActivationManaging
{
  private(set) var activateCallCount = 0
  private(set) var restoreCallCount = 0
  private let startupEvents: RecordingSelectionStartupEvents?
  private let automaticallyCompletesActivation: Bool
  private var activationReady: (@MainActor @Sendable () -> Void)?

  init(
    startupEvents: RecordingSelectionStartupEvents? = nil,
    automaticallyCompletesActivation: Bool = true
  ) {
    self.startupEvents = startupEvents
    self.automaticallyCompletesActivation = automaticallyCompletesActivation
  }

  func activateForSelection(whenActive: @escaping @MainActor @Sendable () -> Void) {
    activateCallCount += 1
    startupEvents?.events.append(.applicationActivationRequested)
    activationReady = whenActive
    if automaticallyCompletesActivation {
      completeActivation()
    }
  }

  func completeActivation() {
    let activationReady = activationReady
    self.activationReady = nil
    activationReady?()
  }

  func restorePreviousApplication() {
    activationReady = nil
    restoreCallCount += 1
    startupEvents?.events.append(.previousApplicationRestored)
  }
}

@MainActor
private final class RecordingSelectionStartupEvents {
  enum Event: Equatable {
    case applicationActivationRequested
    case surfaceShown(CGDirectDisplayID)
    case surfaceInputReady(CGDirectDisplayID)
    case surfaceBecameKey(CGDirectDisplayID)
    case surfaceCursorRectsSuspended(CGDirectDisplayID)
    case surfaceCursorRectsRestored(CGDirectDisplayID)
    case surfaceDragRendered(CGDirectDisplayID)
    case crosshairPushed
    case previousApplicationRestored
  }

  var events: [Event] = []
}

@MainActor
private final class ManualSelectionCompletionScheduler {
  typealias Work = @MainActor @Sendable () -> Void
  private var pending: [Work] = []

  var pendingCount: Int {
    pending.count
  }

  func schedule(_ work: @escaping Work) {
    pending.append(work)
  }

  func runNext() async {
    guard !pending.isEmpty else {
      return XCTFail("Expected deferred selection completion")
    }
    await Task.yield()
    pending.removeFirst()()
  }
}
