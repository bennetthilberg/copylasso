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

struct SystemInteractivePointerState: Equatable, Sendable {
  let location: CGPoint
  let isLeftButtonPressed: Bool
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
    case waitingForRelease
    case waitingForPress
    case dragging(display: DisplayGeometry, start: CGPoint)
    case finished(SelectionOutcome)
  }

  private let displays: [DisplayGeometry]
  private var phase: Phase

  init(
    displays: [DisplayGeometry],
    initialPointerState: SystemInteractivePointerState
  ) {
    self.displays = displays
    phase =
      initialPointerState.isLeftButtonPressed
      ? .waitingForRelease
      : .waitingForPress
  }

  mutating func observe(
    _ pointerState: SystemInteractivePointerState
  ) -> SelectionOutcome? {
    switch phase {
    case .waitingForRelease:
      if !pointerState.isLeftButtonPressed {
        phase = .waitingForPress
      }
      return nil

    case .waitingForPress:
      guard pointerState.isLeftButtonPressed else { return nil }
      guard
        let display = displays.first(where: {
          $0.contains(coreGraphicsPoint: pointerState.location)
        })
      else {
        return nil
      }
      phase = .dragging(display: display, start: pointerState.location)
      return nil

    case .dragging(let display, let start):
      guard !pointerState.isLeftButtonPressed else { return nil }
      let outcome: SelectionOutcome
      do {
        if let selection = try display.selectionResultFromCoreGraphics(
          from: start,
          to: pointerState.location
        ) {
          outcome = .selected(selection)
        } else {
          outcome = .cancelled(.tooSmall)
        }
      } catch {
        outcome = .cancelled(.displayChanged)
      }
      phase = .finished(outcome)
      return outcome

    case .finished(let outcome):
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
  typealias PointerStateProvider = @Sendable () -> SystemInteractivePointerState
  typealias DisplayProvider = @MainActor () throws -> [DisplayGeometry]

  private let controlModifierProvider: ControlModifierProvider
  private let pointerStateProvider: PointerStateProvider
  private let displayProvider: DisplayProvider

  init(
    controlModifierProvider: @escaping ControlModifierProvider = {
      CGEventSource.flagsState(.combinedSessionState).contains(.maskControl)
    },
    pointerStateProvider: @escaping PointerStateProvider = {
      SystemInteractivePointerState(
        location: CGEvent(source: nil)?.location ?? .zero,
        isLeftButtonPressed: CGEventSource.buttonState(
          .combinedSessionState,
          button: .left
        )
      )
    },
    displayProvider: @escaping DisplayProvider = {
      try SystemSelectionDisplayProvider().currentDisplays()
    }
  ) {
    self.controlModifierProvider = controlModifierProvider
    self.pointerStateProvider = pointerStateProvider
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

    let process = Process()
    process.executableURL = configuration.executableURL
    process.arguments = configuration.arguments
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice

    do {
      try process.run()
    } catch {
      throw SystemInteractiveCaptureProcessError.launchFailed
    }

    return LiveSystemInteractiveCaptureProcessSession(
      process: process,
      displays: displays,
      initialPointerState: pointerStateProvider(),
      pointerStateProvider: pointerStateProvider,
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
    initialPointerState: SystemInteractivePointerState,
    pointerStateProvider: @escaping @Sendable () -> SystemInteractivePointerState,
    controlModifierProvider: @escaping @Sendable () -> Bool
  ) {
    let resources = ProcessResources(
      process: process,
      displays: displays,
      initialPointerState: initialPointerState,
      pointerStateProvider: pointerStateProvider,
      controlModifierProvider: controlModifierProvider
    )
    self.resources = resources
    resultTask = Task.detached(priority: .userInitiated) {
      resources.collectResult()
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
  private let initialPointerState: SystemInteractivePointerState
  private let pointerStateProvider: @Sendable () -> SystemInteractivePointerState
  private let controlModifierProvider: @Sendable () -> Bool
  private let lock = NSLock()
  private var wasCancelled = false
  private var wasCancelledForControlModifier = false

  init(
    process: Process,
    displays: [DisplayGeometry],
    initialPointerState: SystemInteractivePointerState,
    pointerStateProvider: @escaping @Sendable () -> SystemInteractivePointerState,
    controlModifierProvider: @escaping @Sendable () -> Bool
  ) {
    self.process = process
    self.displays = displays
    self.initialPointerState = initialPointerState
    self.pointerStateProvider = pointerStateProvider
    self.controlModifierProvider = controlModifierProvider
  }

  func collectResult() -> SystemInteractiveCaptureProcessResult {
    var tracker = SystemInteractiveSelectionTracker(
      displays: displays,
      initialPointerState: initialPointerState
    )
    var selectionOutcome: SelectionOutcome?

    while process.isRunning {
      if selectionOutcome == nil {
        if controlModifierProvider() {
          cancelForControlModifier()
        } else {
          selectionOutcome = tracker.observe(pointerStateProvider())
        }
      }
      Thread.sleep(forTimeInterval: 0.001)
    }

    if selectionOutcome == nil,
      !lock.withLock({ wasCancelledForControlModifier })
    {
      selectionOutcome = tracker.observe(pointerStateProvider())
    }

    process.waitUntilExit()
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

  func cancelForControlModifier() {
    lock.withLock {
      guard !wasCancelled, process.isRunning else { return }
      wasCancelled = true
      wasCancelledForControlModifier = true
      process.interrupt()
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
