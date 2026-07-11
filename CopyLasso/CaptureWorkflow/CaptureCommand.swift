import CoreGraphics

@MainActor
final class CaptureCommand: CaptureRequesting {
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
  private let scheduleWork: WorkScheduler

  var isEnabled: Bool {
    !coordinator.isBusy
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
    scheduleWork: @escaping WorkScheduler = CaptureCommand.scheduleOnNextMainActorTurn
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

    scheduleWork { [weak self] in
      await self?.runPermissionFlowIfStillRequested()
    }
    return result
  }

  private func runPermissionFlowIfStillRequested() async {
    guard coordinator.state == .requestingPermission else {
      return
    }

    let observation = permissionService.currentObservation()
    switch observation {
    case .granted:
      await proceedToSelection()
    case .notGrantedNeverRequested:
      let requestObservation = permissionService.requestAccess()
      if requestObservation == .granted {
        await proceedToSelection()
      } else {
        finishPermissionFailure(requestObservation)
      }
    case .notGrantedAfterRequest, .notGrantedAfterPreviouslyGranted:
      finishPermissionFailure(observation)
    }
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
        await completeSelection(selection)
      case .cancelled(let reason):
        _ = coordinator.handle(.cancel(reason.captureCancellationReason))
      }
    } catch {
      await presentTerminalFailure(.selection)
    }
    resetTerminalState()
  }

  private func completeSelection(_ selection: SelectionResult) async {
    guard case .transitioned = coordinator.handle(.selectionCompleted) else {
      return
    }

    do {
      let feedback = try await runPrivateOperation(selection)
      await presentCompletionFeedback(feedback)
    } catch let interruption as CaptureOperationInterruption {
      await handle(interruption)
    } catch {
      await presentTerminalFailure(.internal)
    }
  }

  private func runPrivateOperation(_ selection: SelectionResult) async throws -> CaptureFeedback {
    let image: CGImage
    do {
      image = try await screenCaptureService.capture(selection)
    } catch {
      if error as? ScreenCaptureError == .permissionDenied {
        recoveryPresenter.present(permissionService.recordCaptureDenial())
        throw CaptureOperationInterruption.permissionRecoveryPresented
      }
      throw CaptureOperationInterruption.failure(.capture)
    }

    guard case .transitioned = coordinator.handle(.captureCompleted) else {
      throw CaptureOperationInterruption.failure(.internal)
    }

    let observations: [RecognizedTextObservation]
    do {
      observations = try await ocrService.recognizeText(in: image)
    } catch VisionOCRError.cancelled {
      throw CaptureOperationInterruption.cancelled(.user)
    } catch {
      throw CaptureOperationInterruption.failure(.recognition)
    }

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

  private func handle(_ interruption: CaptureOperationInterruption) async {
    switch interruption {
    case .cancelled(let reason):
      _ = coordinator.handle(.cancel(reason))
    case .failure(let stage):
      await presentTerminalFailure(stage)
    case .permissionRecoveryPresented:
      _ = coordinator.handle(.fail(.capture))
    }
  }

  private func presentCompletionFeedback(_ feedback: CaptureFeedback) async {
    do {
      try await feedbackService.present(feedback)
      guard case .transitioned = coordinator.handle(.completionFinished) else {
        _ = coordinator.handle(.fail(.internal))
        return
      }
    } catch {
      _ = coordinator.handle(.fail(.feedback))
    }
  }

  private func presentTerminalFailure(_ stage: CaptureFailureStage) async {
    do {
      try await feedbackService.present(.failure(stage))
      _ = coordinator.handle(.fail(stage))
    } catch {
      _ = coordinator.handle(.fail(.feedback))
    }
  }

  private func finishPermissionFailure(
    _ observation: ScreenCaptureAuthorizationObservation
  ) {
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

  private static func scheduleOnNextMainActorTurn(_ work: @escaping Work) {
    Task { @MainActor in
      await Task.yield()
      await work()
    }
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
