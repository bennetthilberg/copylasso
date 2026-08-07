import AppKit
import CoreGraphics
import Foundation

struct SystemInteractiveCaptureConfiguration: Equatable, Sendable {
  let executableURL: URL
  let arguments: [String]

  static let copyLasso = SystemInteractiveCaptureConfiguration(
    executableURL: URL(fileURLWithPath: "/usr/sbin/screencapture"),
    arguments: ["-i", "-s", "-x", "-t", "png", "/dev/null"]
  )
}

enum SystemInteractiveCaptureProcessTerminationReason: Equatable, Sendable {
  case exit
  case uncaughtSignal
}

struct SystemInteractivePointerTransition: Equatable, Sendable {
  enum Kind: Equatable, Sendable {
    case pressed
    case dragged
    case released
  }

  let kind: Kind
  let location: CGPoint
  let controlModifierActive: Bool
  let spaceModifierActive: Bool

  static func pressed(
    at location: CGPoint,
    controlModifierActive: Bool = false
  ) -> Self {
    Self(
      kind: .pressed,
      location: location,
      controlModifierActive: controlModifierActive,
      spaceModifierActive: false
    )
  }

  static func dragged(
    at location: CGPoint,
    controlModifierActive: Bool = false,
    spaceModifierActive: Bool = false
  ) -> Self {
    Self(
      kind: .dragged,
      location: location,
      controlModifierActive: controlModifierActive,
      spaceModifierActive: spaceModifierActive
    )
  }

  static func released(
    at location: CGPoint,
    controlModifierActive: Bool = false
  ) -> Self {
    Self(
      kind: .released,
      location: location,
      controlModifierActive: controlModifierActive,
      spaceModifierActive: false
    )
  }
}

protocol SystemInteractivePointerTransitionMonitoring: AnyObject, Sendable {
  func drainTransitions() -> [SystemInteractivePointerTransition]
  @MainActor func stop()
}

private final class SystemInteractivePointerTransitionBuffer: @unchecked Sendable {
  private let lock = NSLock()
  private var transitions: [SystemInteractivePointerTransition] = []

  func append(_ transition: SystemInteractivePointerTransition) {
    lock.withLock { transitions.append(transition) }
  }

  func drain() -> [SystemInteractivePointerTransition] {
    lock.withLock {
      let drained = transitions
      transitions.removeAll(keepingCapacity: true)
      return drained
    }
  }
}

@MainActor
private final class SystemInteractivePointerTransitionMonitor:
  SystemInteractivePointerTransitionMonitoring,
  @unchecked Sendable
{
  private let buffer: SystemInteractivePointerTransitionBuffer
  private var eventMonitor: Any?

  init(
    spaceModifierProvider: @escaping @Sendable () -> Bool = {
      CGEventSource.keyState(.combinedSessionState, key: 49)
    }
  ) throws {
    let buffer = SystemInteractivePointerTransitionBuffer()
    let eventMonitor = NSEvent.addGlobalMonitorForEvents(
      matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp],
      handler: { event in
        guard let cgEvent = event.cgEvent else { return }
        let location = cgEvent.location
        let controlModifierActive = cgEvent.flags.contains(.maskControl)
        switch event.type {
        case .leftMouseDown:
          buffer.append(
            .pressed(
              at: location,
              controlModifierActive: controlModifierActive
            )
          )
        case .leftMouseDragged:
          buffer.append(
            .dragged(
              at: location,
              controlModifierActive: controlModifierActive,
              spaceModifierActive: spaceModifierProvider()
            )
          )
        case .leftMouseUp:
          buffer.append(
            .released(
              at: location,
              controlModifierActive: controlModifierActive
            )
          )
        default:
          break
        }
      })
    guard let eventMonitor else {
      throw SystemInteractiveCaptureProcessError.launchFailed
    }
    self.buffer = buffer
    self.eventMonitor = eventMonitor
  }

  nonisolated func drainTransitions() -> [SystemInteractivePointerTransition] {
    buffer.drain()
  }

  func stop() {
    guard let eventMonitor else { return }
    NSEvent.removeMonitor(eventMonitor)
    self.eventMonitor = nil
  }
}

struct SystemInteractiveCaptureProcessResult: Equatable, Sendable {
  let terminationStatus: Int32
  let terminationReason: SystemInteractiveCaptureProcessTerminationReason
  let selectionOutcome: SelectionOutcome?
  let wasCancelledForControlModifier: Bool

  init(
    terminationStatus: Int32,
    terminationReason: SystemInteractiveCaptureProcessTerminationReason,
    selectionOutcome: SelectionOutcome? = nil,
    wasCancelledForControlModifier: Bool = false
  ) {
    self.terminationStatus = terminationStatus
    self.terminationReason = terminationReason
    self.selectionOutcome = selectionOutcome
    self.wasCancelledForControlModifier = wasCancelledForControlModifier
  }
}

enum SystemInteractiveCaptureProcessError: Error, Equatable, Sendable {
  case controlModifierActive
  case displayUnavailable
  case launchFailed
}

struct SystemInteractiveSelectionTracker {
  private enum Phase {
    case waitingForPress
    case dragging(display: DisplayGeometry, start: CGPoint, didDrag: Bool)
    case rejected(SelectionOutcome)
  }

  private let displays: [DisplayGeometry]
  private var phase: Phase

  init(displays: [DisplayGeometry]) {
    self.displays = displays
    phase = .waitingForPress
  }

  mutating func observe(
    _ transition: SystemInteractivePointerTransition
  ) -> SelectionOutcome? {
    switch phase {
    case .waitingForPress:
      guard transition.kind == .pressed else { return nil }
      guard
        let display = displays.first(where: {
          $0.contains(coreGraphicsPoint: transition.location)
        })
      else {
        return nil
      }
      phase = .dragging(
        display: display,
        start: transition.location,
        didDrag: false
      )
      return nil

    case .dragging(let display, let start, let didDrag):
      if transition.kind == .dragged {
        if transition.spaceModifierActive {
          let outcome = SelectionOutcome.cancelled(.systemInterrupted)
          phase = .rejected(outcome)
          return outcome
        }
        phase = .dragging(display: display, start: start, didDrag: true)
        return nil
      }
      guard transition.kind == .released else { return nil }
      phase = .waitingForPress
      guard didDrag else { return nil }
      let outcome: SelectionOutcome
      do {
        if let selection = try display.selectionResultFromCoreGraphics(
          from: start,
          to: transition.location
        ) {
          outcome = .selected(selection)
        } else {
          outcome = .cancelled(.tooSmall)
        }
      } catch {
        outcome = .cancelled(.displayChanged)
      }
      return outcome

    case .rejected(let outcome):
      return outcome
    }
  }
}

protocol SystemInteractiveCaptureProcessSession: AnyObject, Sendable {
  func result() async throws -> SystemInteractiveCaptureProcessResult
  func cancel()
}

@MainActor
protocol SystemInteractiveCaptureProcessLaunching: AnyObject {
  func start(
    _ configuration: SystemInteractiveCaptureConfiguration
  ) throws -> any SystemInteractiveCaptureProcessSession
}

@MainActor
final class SystemInteractiveCaptureProcessLauncher: SystemInteractiveCaptureProcessLaunching {
  typealias ControlModifierProvider = @Sendable () -> Bool
  typealias PointerTransitionMonitorProvider =
    @MainActor () throws -> any SystemInteractivePointerTransitionMonitoring
  typealias DisplayProvider = @MainActor () throws -> [DisplayGeometry]

  private let controlModifierProvider: ControlModifierProvider
  private let pointerTransitionMonitorProvider: PointerTransitionMonitorProvider
  private let displayProvider: DisplayProvider

  init(
    controlModifierProvider: @escaping ControlModifierProvider = {
      CGEventSource.flagsState(.combinedSessionState).contains(.maskControl)
    },
    pointerTransitionMonitorProvider: @escaping PointerTransitionMonitorProvider = {
      try SystemInteractivePointerTransitionMonitor()
    },
    displayProvider: @escaping DisplayProvider = {
      try SystemSelectionDisplayProvider().currentDisplays()
    }
  ) {
    self.controlModifierProvider = controlModifierProvider
    self.pointerTransitionMonitorProvider = pointerTransitionMonitorProvider
    self.displayProvider = displayProvider
  }

  func start(
    _ configuration: SystemInteractiveCaptureConfiguration
  ) throws -> any SystemInteractiveCaptureProcessSession {
    guard !controlModifierProvider() else {
      throw SystemInteractiveCaptureProcessError.controlModifierActive
    }

    let displays: [DisplayGeometry]
    do {
      displays = try displayProvider()
    } catch {
      throw SystemInteractiveCaptureProcessError.displayUnavailable
    }
    guard !displays.isEmpty else {
      throw SystemInteractiveCaptureProcessError.displayUnavailable
    }
    let pointerTransitionMonitor: any SystemInteractivePointerTransitionMonitoring
    do {
      pointerTransitionMonitor = try pointerTransitionMonitorProvider()
    } catch {
      throw SystemInteractiveCaptureProcessError.launchFailed
    }

    let process = Process()
    process.executableURL = configuration.executableURL
    process.arguments = configuration.arguments
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice

    do {
      try process.run()
    } catch {
      pointerTransitionMonitor.stop()
      throw SystemInteractiveCaptureProcessError.launchFailed
    }

    return LiveSystemInteractiveCaptureProcessSession(
      process: process,
      displays: displays,
      pointerTransitionMonitor: pointerTransitionMonitor,
      controlModifierProvider: controlModifierProvider
    )
  }
}

private final class LiveSystemInteractiveCaptureProcessSession:
  SystemInteractiveCaptureProcessSession,
  @unchecked Sendable
{
  private let resources: ProcessResources
  private let resultTask: Task<SystemInteractiveCaptureProcessResult, Never>

  init(
    process: Process,
    displays: [DisplayGeometry],
    pointerTransitionMonitor: any SystemInteractivePointerTransitionMonitoring,
    controlModifierProvider: @escaping @Sendable () -> Bool
  ) {
    let resources = ProcessResources(
      process: process,
      displays: displays,
      pointerTransitionMonitor: pointerTransitionMonitor,
      controlModifierProvider: controlModifierProvider
    )
    self.resources = resources
    resultTask = Task.detached(priority: .userInitiated) {
      await resources.collectResult()
    }
  }

  func result() async throws -> SystemInteractiveCaptureProcessResult {
    return try await withTaskCancellationHandler {
      let result = await resultTask.value
      try Task.checkCancellation()
      return result
    } onCancel: { [resources] in
      resources.cancel()
    }
  }

  func cancel() {
    resources.cancel()
  }
}

private final class ProcessResources: @unchecked Sendable {
  private let process: Process
  private let displays: [DisplayGeometry]
  private let pointerTransitionMonitor: any SystemInteractivePointerTransitionMonitoring
  private let controlModifierProvider: @Sendable () -> Bool
  private let lock = NSLock()
  private var wasCancelled = false
  private var wasCancelledForControlModifier = false

  init(
    process: Process,
    displays: [DisplayGeometry],
    pointerTransitionMonitor: any SystemInteractivePointerTransitionMonitoring,
    controlModifierProvider: @escaping @Sendable () -> Bool
  ) {
    self.process = process
    self.displays = displays
    self.pointerTransitionMonitor = pointerTransitionMonitor
    self.controlModifierProvider = controlModifierProvider
  }

  func collectResult() async -> SystemInteractiveCaptureProcessResult {
    var tracker = SystemInteractiveSelectionTracker(displays: displays)
    var selectionOutcome: SelectionOutcome?

    while process.isRunning {
      if controlModifierProvider() {
        cancelForControlModifier()
      } else if let latestOutcome = trackPendingTransitions(using: &tracker) {
        selectionOutcome = latestOutcome
      }
      try? await Task.sleep(for: .milliseconds(1))
    }

    process.waitUntilExit()
    await pointerTransitionMonitor.stop()
    if controlModifierProvider() {
      cancelForControlModifier()
    } else if !lock.withLock({ wasCancelledForControlModifier }),
      let latestOutcome = trackPendingTransitions(using: &tracker)
    {
      selectionOutcome = latestOutcome
    }

    let reason: SystemInteractiveCaptureProcessTerminationReason =
      process.terminationReason == .exit ? .exit : .uncaughtSignal
    let cancelledForControl = lock.withLock { wasCancelledForControlModifier }
    return SystemInteractiveCaptureProcessResult(
      terminationStatus: process.terminationStatus,
      terminationReason: reason,
      selectionOutcome: cancelledForControl ? nil : selectionOutcome,
      wasCancelledForControlModifier: cancelledForControl
    )
  }

  private func trackPendingTransitions(
    using tracker: inout SystemInteractiveSelectionTracker
  ) -> SelectionOutcome? {
    var latestOutcome: SelectionOutcome?
    for transition in pointerTransitionMonitor.drainTransitions() {
      if transition.controlModifierActive {
        cancelForControlModifier()
        return nil
      }
      if let outcome = tracker.observe(transition) {
        latestOutcome = outcome
        if outcome == .cancelled(.systemInterrupted) {
          cancelForUnsupportedAdjustment()
        }
      }
    }
    return latestOutcome
  }

  private func cancelForUnsupportedAdjustment() {
    lock.withLock {
      guard !wasCancelled else { return }
      wasCancelled = true
      if process.isRunning {
        process.interrupt()
      }
    }
  }

  func cancelForControlModifier() {
    lock.withLock {
      guard !wasCancelled else { return }
      wasCancelled = true
      wasCancelledForControlModifier = true
      if process.isRunning {
        process.interrupt()
      }
    }
  }

  func cancel() {
    lock.withLock {
      guard !wasCancelled else { return }
      wasCancelled = true
      if process.isRunning {
        process.terminate()
      }
    }
  }
}

@MainActor
final class SystemInteractiveCaptureService: InteractiveCaptureService {
  private struct PreparedCapture {
    let id: UUID
    let session: any SystemInteractiveCaptureProcessSession
  }

  private enum Preparation {
    case capture(PreparedCapture)
    case cancellation(SelectionCancellationReason)
    case failure(InteractiveCaptureError)
  }

  private let launcher: any SystemInteractiveCaptureProcessLaunching
  private let screenCaptureService: any ScreenCaptureService
  private var preparation: Preparation?

  init(
    launcher: any SystemInteractiveCaptureProcessLaunching =
      SystemInteractiveCaptureProcessLauncher(),
    screenCaptureService: any ScreenCaptureService = SystemScreenCaptureService()
  ) {
    self.launcher = launcher
    self.screenCaptureService = screenCaptureService
  }

  func prepareForCaptureTransition() {
    guard preparation == nil else { return }
    do {
      preparation = .capture(
        PreparedCapture(
          id: UUID(),
          session: try launcher.start(.copyLasso)
        )
      )
    } catch SystemInteractiveCaptureProcessError.controlModifierActive {
      preparation = .cancellation(.systemInterrupted)
    } catch {
      preparation = .failure(.captureFailed)
    }
  }

  func capture() async throws -> InteractiveCaptureOutcome {
    if preparation == nil {
      prepareForCaptureTransition()
    }
    guard let preparation else {
      throw InteractiveCaptureError.captureFailed
    }

    switch preparation {
    case .cancellation(let reason):
      self.preparation = nil
      return .cancelled(reason)
    case .failure(let error):
      self.preparation = nil
      throw error
    case .capture(let prepared):
      let result: SystemInteractiveCaptureProcessResult
      do {
        result = try await prepared.session.result()
      } catch is CancellationError {
        clearPreparation(matching: prepared.id)
        return .cancelled(.systemInterrupted)
      } catch {
        clearPreparation(matching: prepared.id)
        throw InteractiveCaptureError.captureFailed
      }

      guard matchesCurrentPreparation(prepared.id) else {
        return .cancelled(.systemInterrupted)
      }
      self.preparation = nil

      if result.wasCancelledForControlModifier {
        return .cancelled(.systemInterrupted)
      }
      if let selectionOutcome = result.selectionOutcome {
        return try await complete(selectionOutcome)
      }
      if result.terminationReason == .exit,
        result.terminationStatus == 0 || result.terminationStatus == 1
      {
        return .cancelled(.escape)
      }
      throw InteractiveCaptureError.processFailed(status: result.terminationStatus)
    }
  }

  func cancelCapture() {
    if case .capture(let prepared) = preparation {
      prepared.session.cancel()
    }
    preparation = nil
  }

  private func complete(
    _ selectionOutcome: SelectionOutcome
  ) async throws -> InteractiveCaptureOutcome {
    switch selectionOutcome {
    case .cancelled(let reason):
      return .cancelled(reason)
    case .selected(let selection):
      do {
        return .captured(try await screenCaptureService.capture(selection))
      } catch ScreenCaptureError.permissionDenied {
        throw InteractiveCaptureError.permissionDenied
      } catch {
        throw InteractiveCaptureError.captureFailed
      }
    }
  }

  private func matchesCurrentPreparation(_ id: UUID) -> Bool {
    guard case .capture(let current) = preparation else { return false }
    return current.id == id
  }

  private func clearPreparation(matching id: UUID) {
    if matchesCurrentPreparation(id) {
      preparation = nil
    }
  }
}
