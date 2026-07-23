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
  private let barcodeService: any BarcodeRecognitionService
  private let codePayloadAssembler: any CodePayloadAssembling
  private let clipboardService: any ClipboardService
  private let successSoundPlayer: any SuccessSoundPlaying
  private let feedbackService: any FeedbackService
  private let recoveryPresenter: any PermissionRecoveryPresenting
  private let scheduleWork: WorkScheduler?
  private var activeTask: Task<Void, Never>?
  private var requestedCancellationReason: CaptureCancellationReason?
  private var pendingMode: CaptureMode?
  private var lastRequestedMode: CaptureMode = .text

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
    barcodeService: any BarcodeRecognitionService = VisionBarcodeService(),
    codePayloadAssembler: any CodePayloadAssembling = CodePayloadAssembler(),
    clipboardService: any ClipboardService,
    successSoundPlayer: any SuccessSoundPlaying = NoopSuccessSoundPlayer(),
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
    self.barcodeService = barcodeService
    self.codePayloadAssembler = codePayloadAssembler
    self.clipboardService = clipboardService
    self.successSoundPlayer = successSoundPlayer
    self.feedbackService = feedbackService
    self.recoveryPresenter = recoveryPresenter
    self.scheduleWork = scheduleWork
  }

  @discardableResult
  func perform() -> CaptureTransitionResult {
    perform(mode: .text)
  }

  @discardableResult
  func perform(mode: CaptureMode) -> CaptureTransitionResult {
    let result = coordinator.handle(.requestCapture)
    guard case .transitioned = result else {
      return result
    }

    pendingMode = mode
    lastRequestedMode = mode
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
  func retryLastRequest() -> CaptureTransitionResult {
    perform(mode: lastRequestedMode)
  }

  @discardableResult
  func cancelActiveOperation(reason: CaptureCancellationReason) -> Bool {
    feedbackService.dismiss()
    successSoundPlayer.stop()
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
    let mode = pendingMode ?? .text
    defer {
      activeTask = nil
      requestedCancellationReason = nil
      pendingMode = nil
    }
    guard !transitionToRequestedCancellationIfNeeded() else {
      resetTerminalState()
      return
    }
    await runPermissionFlowIfStillRequested(mode: mode)
  }

  private func runPermissionFlowIfStillRequested(mode: CaptureMode) async {
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
      await proceedToSelectionUnlessCancelled(mode: mode)
    case .notGrantedNeverRequested:
      let requestObservation = permissionService.requestAccess()
      if requestObservation == .granted {
        await proceedToSelectionUnlessCancelled(mode: mode)
      } else {
        finishPermissionFailure(requestObservation)
      }
    case .notGrantedAfterRequest, .notGrantedAfterPreviouslyGranted:
      finishPermissionFailure(observation)
    }
  }

  private func proceedToSelectionUnlessCancelled(mode: CaptureMode) async {
    guard !transitionToRequestedCancellationIfNeeded() else {
      resetTerminalState()
      return
    }
    await proceedToSelection(mode: mode)
  }

  private func proceedToSelection(mode: CaptureMode) async {
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
        await completeSelection(selection, mode: mode)
      case .cancelled(let reason):
        _ = coordinator.handle(
          .cancel(requestedCancellationReason ?? reason.captureCancellationReason)
        )
      }
    } catch {
      if !transitionToRequestedCancellationIfNeeded() {
        presentTerminalFailure(.selection, mode: mode)
      }
    }
    resetTerminalState()
  }

  private func completeSelection(_ selection: SelectionResult, mode: CaptureMode) async {
    guard case .transitioned = coordinator.handle(.selectionCompleted) else {
      return
    }

    do {
      let feedback = try await runPrivateOperation(selection, mode: mode)
      presentCompletionFeedback(feedback)
    } catch let interruption as CaptureOperationInterruption {
      handle(interruption, mode: mode)
    } catch {
      presentTerminalFailure(.internal, mode: mode)
    }
  }

  private func runPrivateOperation(
    _ selection: SelectionResult,
    mode: CaptureMode
  ) async throws -> CaptureFeedback {
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

    let content: String
    switch mode {
    case .text:
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
      content = textAssembler.assemble(observations)
      if content.isEmpty {
        return .noText
      }
    case .code:
      let observations: [RecognizedCodeObservation]
      do {
        observations = try await barcodeService.recognizeCodes(in: image)
      } catch VisionBarcodeError.cancelled {
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
      switch codePayloadAssembler.assemble(observations) {
      case .content(let payload):
        content = payload
      case .noCode:
        return .noCode
      case .ambiguous:
        return .ambiguousCodes
      }
    }

    do {
      try clipboardService.writePlainText(content)
    } catch {
      throw CaptureOperationInterruption.failure(.clipboard)
    }

    successSoundPlayer.play()
    let preview = FeedbackPreview(text: content).text
    return mode == .text ? .success(preview: preview) : .codeSuccess(preview: preview)
  }

  private func handle(
    _ interruption: CaptureOperationInterruption,
    mode: CaptureMode
  ) {
    switch interruption {
    case .cancelled(let reason):
      _ = coordinator.handle(.cancel(reason))
    case .failure(let stage):
      presentTerminalFailure(stage, mode: mode)
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

  private func presentTerminalFailure(
    _ stage: CaptureFailureStage,
    mode: CaptureMode
  ) {
    if coordinator.state != .completing {
      guard case .transitioned = coordinator.handle(.feedbackBegan) else {
        _ = coordinator.handle(.fail(.internal))
        return
      }
    }

    do {
      try feedbackService.present(
        mode == .text ? .failure(stage) : .codeFailure(stage)
      )
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
    case .systemInterrupted:
      .systemInterrupted
    case .applicationTerminated:
      .applicationTerminated
    }
  }
}
