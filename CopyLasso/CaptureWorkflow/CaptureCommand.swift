import CoreGraphics

@MainActor
protocol ActiveCaptureCancelling: AnyObject {
  @discardableResult
  func cancelActiveOperation(reason: CaptureCancellationReason) -> Bool
}

@MainActor
final class CaptureCommand: CaptureRequesting, ActiveCaptureCancelling {
  typealias Work = @MainActor @Sendable () async -> Void
  typealias WorkScheduler = @MainActor (@escaping Work) -> Void

  private let coordinator: CaptureCoordinator
  private let permissionService: any ScreenCapturePermissionService
  private let selectionService: any RegionSelectionService
  private let screenCaptureService: any ScreenCaptureService
  private let ocrService: any OCRService
  private let textAssembler: any TextAssembling
  private let clipboardService: any ClipboardService
  private let feedbackService: any FeedbackService
  private let recoveryPresenter: any PermissionRecoveryPresenting
  private let scheduleWork: WorkScheduler?
  private var activeTask: Task<Void, Never>?
  private var requestedCancellationReason: CaptureCancellationReason?
  private var requestGeneration: UInt = 0

  var isEnabled: Bool {
    coordinator.state == .idle || coordinator.state == .completing
  }

  init(
    coordinator: CaptureCoordinator,
    permissionService: any ScreenCapturePermissionService,
    selectionService: any RegionSelectionService,
    screenCaptureService: any ScreenCaptureService,
    ocrService: any OCRService,
    textAssembler: any TextAssembling,
    clipboardService: any ClipboardService,
    feedbackService: any FeedbackService,
    recoveryPresenter: any PermissionRecoveryPresenting,
    scheduleWork: WorkScheduler? = nil
  ) {
    self.coordinator = coordinator
    self.permissionService = permissionService
    self.selectionService = selectionService
    self.screenCaptureService = screenCaptureService
    self.ocrService = ocrService
    self.textAssembler = textAssembler
    self.clipboardService = clipboardService
    self.feedbackService = feedbackService
    self.recoveryPresenter = recoveryPresenter
    self.scheduleWork = scheduleWork
  }

  @discardableResult
  func perform() -> CaptureTransitionResult {
    let result = coordinator.handle(.requestCapture)
    guard case .transitioned(let previousState, _) = result else {
      return result
    }

    requestGeneration &+= 1
    let generation = requestGeneration
    if previousState == .completing {
      feedbackService.dismiss()
    }

    let work: Work = { [weak self] in
      await self?.runScheduledOperation(generation: generation)
    }
    if let scheduleWork {
      scheduleWork(work)
    } else {
      activeTask = Task { @MainActor in
        await Task.yield()
        await work()
      }
    }
    return result
  }

  @discardableResult
  func cancelActiveOperation(reason: CaptureCancellationReason) -> Bool {
    guard requestedCancellationReason == nil else { return false }
    switch coordinator.state {
    case .requestingPermission, .selecting, .capturing, .recognizing, .completing:
      requestedCancellationReason = reason
      if coordinator.state == .selecting {
        selectionService.cancelSelection()
      } else if coordinator.state == .completing {
        feedbackService.dismiss()
      }
      activeTask?.cancel()
      return true
    case .idle, .cancelled, .failed:
      return false
    }
  }

  private func runScheduledOperation(generation: UInt) async {
    defer {
      if generation == requestGeneration {
        activeTask = nil
        requestedCancellationReason = nil
      }
    }
    guard generation == requestGeneration else { return }
    guard !transitionToRequestedCancellationIfNeeded(generation: generation) else {
      resetTerminalState(generation: generation)
      return
    }
    await runPermissionFlowIfStillRequested(generation: generation)
  }

  private func runPermissionFlowIfStillRequested(generation: UInt) async {
    guard generation == requestGeneration,
      coordinator.state == .requestingPermission
    else {
      return
    }
    guard !transitionToRequestedCancellationIfNeeded(generation: generation) else {
      resetTerminalState(generation: generation)
      return
    }

    let observation = permissionService.currentObservation()
    switch observation {
    case .granted:
      await proceedToSelectionUnlessCancelled(generation: generation)
    case .notGrantedNeverRequested:
      let requestObservation = permissionService.requestAccess()
      if requestObservation == .granted {
        await proceedToSelectionUnlessCancelled(generation: generation)
      } else {
        finishPermissionFailure(requestObservation, generation: generation)
      }
    case .notGrantedAfterRequest, .notGrantedAfterPreviouslyGranted:
      finishPermissionFailure(observation, generation: generation)
    }
  }

  private func proceedToSelectionUnlessCancelled(generation: UInt) async {
    guard !transitionToRequestedCancellationIfNeeded(generation: generation) else {
      resetTerminalState(generation: generation)
      return
    }
    await proceedToSelection(generation: generation)
  }

  private func proceedToSelection(generation: UInt) async {
    guard generation == requestGeneration else { return }
    recoveryPresenter.dismiss()
    guard case .transitioned = coordinator.handle(.permissionGranted) else {
      return
    }

    do {
      let outcome = try await selectionService.selectRegion()
      guard generation == requestGeneration else { return }
      switch outcome {
      case .selected(let selection):
        if transitionToRequestedCancellationIfNeeded(generation: generation) {
          break
        }
        await completeSelection(selection, generation: generation)
      case .cancelled(let reason):
        _ = coordinator.handle(
          .cancel(requestedCancellationReason ?? reason.captureCancellationReason)
        )
      }
    } catch {
      guard generation == requestGeneration else { return }
      if !transitionToRequestedCancellationIfNeeded(generation: generation) {
        await presentTerminalFailure(.selection, generation: generation)
      }
    }
    resetTerminalState(generation: generation)
  }

  private func completeSelection(_ selection: SelectionResult, generation: UInt) async {
    guard generation == requestGeneration else { return }
    guard case .transitioned = coordinator.handle(.selectionCompleted) else {
      return
    }

    do {
      let feedback = try await runPrivateOperation(selection, generation: generation)
      await presentCompletionFeedback(feedback, generation: generation)
    } catch let interruption as CaptureOperationInterruption {
      await handle(interruption, generation: generation)
    } catch {
      await presentTerminalFailure(.internal, generation: generation)
    }
  }

  private func runPrivateOperation(
    _ selection: SelectionResult,
    generation: UInt
  ) async throws -> CaptureFeedback {
    try throwIfCancellationRequested(generation: generation)
    let image: CGImage
    do {
      image = try await screenCaptureService.capture(selection)
      permissionService.recordCaptureSuccess()
    } catch {
      if let reason = cancellationReasonIfRequested(generation: generation) {
        throw CaptureOperationInterruption.cancelled(reason)
      }
      if error as? ScreenCaptureError == .permissionDenied {
        recoveryPresenter.present(permissionService.recordCaptureDenial())
        throw CaptureOperationInterruption.permissionRecoveryPresented
      }
      throw CaptureOperationInterruption.failure(.capture)
    }
    try throwIfCancellationRequested(generation: generation)

    guard case .transitioned = coordinator.handle(.captureCompleted) else {
      throw CaptureOperationInterruption.failure(.internal)
    }

    let observations: [RecognizedTextObservation]
    do {
      observations = try await ocrService.recognizeText(in: image)
    } catch VisionOCRError.cancelled {
      throw CaptureOperationInterruption.cancelled(
        requestedCancellationReason ?? .user
      )
    } catch {
      if let reason = cancellationReasonIfRequested(generation: generation) {
        throw CaptureOperationInterruption.cancelled(reason)
      }
      throw CaptureOperationInterruption.failure(.recognition)
    }
    try throwIfCancellationRequested(generation: generation)

    guard case .transitioned = coordinator.handle(.recognitionCompleted) else {
      throw CaptureOperationInterruption.failure(.internal)
    }

    let text = textAssembler.assemble(observations)
    if text.isEmpty {
      return .noText
    }

    do {
      try clipboardService.writePlainText(text)
    } catch {
      throw CaptureOperationInterruption.failure(.clipboard)
    }

    let preview = FeedbackPreview(text: text).text
    return .success(preview: preview)
  }

  private func handle(
    _ interruption: CaptureOperationInterruption,
    generation: UInt
  ) async {
    guard generation == requestGeneration else { return }
    switch interruption {
    case .cancelled(let reason):
      _ = coordinator.handle(.cancel(reason))
    case .failure(let stage):
      await presentTerminalFailure(stage, generation: generation)
    case .permissionRecoveryPresented:
      _ = coordinator.handle(.fail(.capture))
    }
  }

  private func presentCompletionFeedback(_ feedback: CaptureFeedback, generation: UInt) async {
    do {
      try await feedbackService.present(feedback)
      guard generation == requestGeneration else { return }
      if transitionToRequestedCancellationIfNeeded(generation: generation) {
        return
      }
      guard case .transitioned = coordinator.handle(.completionFinished) else {
        _ = coordinator.handle(.fail(.internal))
        return
      }
    } catch {
      guard generation == requestGeneration else { return }
      if !transitionToRequestedCancellationIfNeeded(generation: generation) {
        _ = coordinator.handle(.fail(.feedback))
      }
    }
  }

  private func presentTerminalFailure(
    _ stage: CaptureFailureStage,
    generation: UInt
  ) async {
    guard generation == requestGeneration else { return }
    if coordinator.state != .completing {
      guard case .transitioned = coordinator.handle(.feedbackBegan) else {
        _ = coordinator.handle(.fail(.internal))
        return
      }
    }

    do {
      try await feedbackService.present(.failure(stage))
      guard generation == requestGeneration else { return }
      if !transitionToRequestedCancellationIfNeeded(generation: generation) {
        _ = coordinator.handle(.fail(stage))
      }
    } catch {
      guard generation == requestGeneration else { return }
      if !transitionToRequestedCancellationIfNeeded(generation: generation) {
        _ = coordinator.handle(.fail(.feedback))
      }
    }
  }

  private func finishPermissionFailure(
    _ observation: ScreenCaptureAuthorizationObservation,
    generation: UInt
  ) {
    guard generation == requestGeneration else { return }
    _ = coordinator.handle(.fail(.permission))
    recoveryPresenter.present(observation)
    resetTerminalState(generation: generation)
  }

  private func resetTerminalState(generation: UInt) {
    guard generation == requestGeneration else { return }
    switch coordinator.state {
    case .cancelled, .failed:
      _ = coordinator.handle(.reset)
    case .idle, .requestingPermission, .selecting, .capturing, .recognizing, .completing:
      break
    }
  }

  private func cancellationReasonIfRequested(
    generation: UInt
  ) -> CaptureCancellationReason? {
    guard generation == requestGeneration else { return .systemInterrupted }
    if let requestedCancellationReason {
      return requestedCancellationReason
    }
    return Task.isCancelled ? .systemInterrupted : nil
  }

  private func throwIfCancellationRequested(generation: UInt) throws {
    if let reason = cancellationReasonIfRequested(generation: generation) {
      throw CaptureOperationInterruption.cancelled(reason)
    }
  }

  private func transitionToRequestedCancellationIfNeeded(generation: UInt) -> Bool {
    guard generation == requestGeneration else { return true }
    guard let reason = requestedCancellationReason else { return false }
    _ = coordinator.handle(.cancel(reason))
    return true
  }
}

private enum CaptureOperationInterruption: Error {
  case cancelled(CaptureCancellationReason)
  case failure(CaptureFailureStage)
  case permissionRecoveryPresented
}

extension SelectionCancellationReason {
  fileprivate var captureCancellationReason: CaptureCancellationReason {
    switch self {
    case .escape:
      .user
    case .tooSmall:
      .selectionTooSmall
    case .displayChanged:
      .displayChanged
    case .applicationTerminated:
      .applicationTerminated
    }
  }
}
