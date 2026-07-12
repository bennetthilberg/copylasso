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
    guard case .transitioned = result else {
      return result
    }

    feedbackService.dismiss()
    let work: Work = { [weak self] in
      await self?.runScheduledOperation()
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
    feedbackService.dismiss()
    guard requestedCancellationReason == nil else { return false }
    switch coordinator.state {
    case .requestingPermission, .selecting, .capturing, .recognizing, .completing:
      requestedCancellationReason = reason
      if coordinator.state == .selecting {
        selectionService.cancelSelection()
      }
      activeTask?.cancel()
      return true
    case .idle, .cancelled, .failed:
      return false
    }
  }

  private func runScheduledOperation() async {
    defer {
      activeTask = nil
      requestedCancellationReason = nil
    }
    guard !transitionToRequestedCancellationIfNeeded() else {
      resetTerminalState()
      return
    }
    await runPermissionFlowIfStillRequested()
  }

  private func runPermissionFlowIfStillRequested() async {
    guard coordinator.state == .requestingPermission else {
      return
    }
    guard !transitionToRequestedCancellationIfNeeded() else {
      resetTerminalState()
      return
    }

    let observation = permissionService.currentObservation()
    switch observation {
    case .granted:
      await proceedToSelectionUnlessCancelled()
    case .notGrantedNeverRequested:
      let requestObservation = permissionService.requestAccess()
      if requestObservation == .granted {
        await proceedToSelectionUnlessCancelled()
      } else {
        finishPermissionFailure(requestObservation)
      }
    case .notGrantedAfterRequest, .notGrantedAfterPreviouslyGranted:
      finishPermissionFailure(observation)
    }
  }

  private func proceedToSelectionUnlessCancelled() async {
    guard !transitionToRequestedCancellationIfNeeded() else {
      resetTerminalState()
      return
    }
    await proceedToSelection()
  }

  private func proceedToSelection() async {
    recoveryPresenter.dismiss()
    guard case .transitioned = coordinator.handle(.permissionGranted) else {
      return
    }

    do {
      let outcome = try await selectionService.selectRegion()
      switch outcome {
      case .selected(let selection):
        if transitionToRequestedCancellationIfNeeded() {
          break
        }
        await completeSelection(selection)
      case .cancelled(let reason):
        _ = coordinator.handle(
          .cancel(requestedCancellationReason ?? reason.captureCancellationReason)
        )
      }
    } catch {
      if !transitionToRequestedCancellationIfNeeded() {
        presentTerminalFailure(.selection)
      }
    }
    resetTerminalState()
  }

  private func completeSelection(_ selection: SelectionResult) async {
    guard case .transitioned = coordinator.handle(.selectionCompleted) else {
      return
    }

    do {
      let feedback = try await runPrivateOperation(selection)
      presentCompletionFeedback(feedback)
    } catch let interruption as CaptureOperationInterruption {
      handle(interruption)
    } catch {
      presentTerminalFailure(.internal)
    }
  }

  private func runPrivateOperation(_ selection: SelectionResult) async throws -> CaptureFeedback {
    try throwIfCancellationRequested()
    let image: CGImage
    do {
      image = try await screenCaptureService.capture(selection)
      permissionService.recordCaptureSuccess()
    } catch {
      if let reason = cancellationReasonIfRequested {
        throw CaptureOperationInterruption.cancelled(reason)
      }
      if error as? ScreenCaptureError == .permissionDenied {
        recoveryPresenter.present(permissionService.recordCaptureDenial())
        throw CaptureOperationInterruption.permissionRecoveryPresented
      }
      throw CaptureOperationInterruption.failure(.capture)
    }
    try throwIfCancellationRequested()

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
      if let reason = cancellationReasonIfRequested {
        throw CaptureOperationInterruption.cancelled(reason)
      }
      throw CaptureOperationInterruption.failure(.recognition)
    }
    try throwIfCancellationRequested()

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

  private func handle(_ interruption: CaptureOperationInterruption) {
    switch interruption {
    case .cancelled(let reason):
      _ = coordinator.handle(.cancel(reason))
    case .failure(let stage):
      presentTerminalFailure(stage)
    case .permissionRecoveryPresented:
      _ = coordinator.handle(.fail(.capture))
    }
  }

  private func presentCompletionFeedback(_ feedback: CaptureFeedback) {
    do {
      try feedbackService.present(feedback)
      if transitionToRequestedCancellationIfNeeded() {
        return
      }
      guard case .transitioned = coordinator.handle(.completionFinished) else {
        _ = coordinator.handle(.fail(.internal))
        return
      }
    } catch {
      if !transitionToRequestedCancellationIfNeeded() {
        _ = coordinator.handle(.fail(.feedback))
      }
    }
  }

  private func presentTerminalFailure(_ stage: CaptureFailureStage) {
    if coordinator.state != .completing {
      guard case .transitioned = coordinator.handle(.feedbackBegan) else {
        _ = coordinator.handle(.fail(.internal))
        return
      }
    }

    do {
      try feedbackService.present(.failure(stage))
      if !transitionToRequestedCancellationIfNeeded() {
        _ = coordinator.handle(.fail(stage))
      }
    } catch {
      if !transitionToRequestedCancellationIfNeeded() {
        _ = coordinator.handle(.fail(.feedback))
      }
    }
  }

  private func finishPermissionFailure(_ observation: ScreenCaptureAuthorizationObservation) {
    _ = coordinator.handle(.fail(.permission))
    recoveryPresenter.present(observation)
    resetTerminalState()
  }

  private func resetTerminalState() {
    switch coordinator.state {
    case .cancelled, .failed:
      _ = coordinator.handle(.reset)
    case .idle, .requestingPermission, .selecting, .capturing, .recognizing, .completing:
      break
    }
  }

  private var cancellationReasonIfRequested: CaptureCancellationReason? {
    if let requestedCancellationReason {
      return requestedCancellationReason
    }
    return Task.isCancelled ? .systemInterrupted : nil
  }

  private func throwIfCancellationRequested() throws {
    if let reason = cancellationReasonIfRequested {
      throw CaptureOperationInterruption.cancelled(reason)
    }
  }

  private func transitionToRequestedCancellationIfNeeded() -> Bool {
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
