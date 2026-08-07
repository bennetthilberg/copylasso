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

  private enum InteractiveCaptureResolution {
    case feedback(CaptureFeedback)
    case finished
  }

  private let coordinator: CaptureCoordinator
  private let permissionService: any ScreenCapturePermissionService
  private let selectionService: (any RegionSelectionService)?
  private let screenCaptureService: (any ScreenCaptureService)?
  private let interactiveCaptureService: (any InteractiveCaptureService)?
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
  private var selectionTransitionPrepared = false

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
    barcodeService: any BarcodeRecognitionService,
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
    interactiveCaptureService = nil
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

  init(
    coordinator: CaptureCoordinator,
    permissionService: any ScreenCapturePermissionService,
    interactiveCaptureService: any InteractiveCaptureService,
    ocrService: any OCRService,
    textAssembler: any TextAssembling,
    barcodeService: any BarcodeRecognitionService,
    codePayloadAssembler: any CodePayloadAssembling = CodePayloadAssembler(),
    clipboardService: any ClipboardService,
    successSoundPlayer: any SuccessSoundPlaying = NoopSuccessSoundPlayer(),
    feedbackService: any FeedbackService,
    recoveryPresenter: any PermissionRecoveryPresenting,
    scheduleWork: WorkScheduler? = nil
  ) {
    self.coordinator = coordinator
    self.permissionService = permissionService
    selectionService = nil
    screenCaptureService = nil
    self.interactiveCaptureService = interactiveCaptureService
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
    requestCapture(preflightForImmediateSelection: false)
  }

  @discardableResult
  func performFromGlobalShortcut() -> CaptureTransitionResult {
    requestCapture(preflightForImmediateSelection: true)
  }

  private func requestCapture(
    preflightForImmediateSelection: Bool
  ) -> CaptureTransitionResult {
    let result = coordinator.handle(.requestCapture)
    guard case .transitioned = result else {
      return result
    }
    let beganFromIdle: Bool
    if case .transitioned(from: .idle, to: .requestingPermission) = result {
      beganFromIdle = true
      feedbackService.dismiss()
    } else {
      beganFromIdle = false
    }

    let initialObservation: ScreenCaptureAuthorizationObservation?
    if preflightForImmediateSelection {
      let observation = permissionService.currentObservation()
      initialObservation = observation
      if observation == .granted {
        prepareForCaptureTransition()
        selectionTransitionPrepared = true
        if !beganFromIdle {
          feedbackService.dismiss()
        }
      }
    } else {
      initialObservation = nil
    }

    let work: Work = { [weak self] in
      await self?.runScheduledOperation(initialObservation: initialObservation)
    }
    if let scheduleWork {
      scheduleWork(work)
    } else {
      activeTask = Task { @MainActor in
        await work()
      }
    }
    return result
  }

  @discardableResult
  func retryLastRequest() -> CaptureTransitionResult {
    perform()
  }

  @discardableResult
  func cancelActiveOperation(reason: CaptureCancellationReason) -> Bool {
    feedbackService.dismiss()
    successSoundPlayer.stop()
    guard requestedCancellationReason == nil else { return false }
    switch coordinator.state {
    case .requestingPermission, .selecting, .capturing, .recognizing, .completing:
      requestedCancellationReason = reason
      if selectionTransitionPrepared {
        cancelPreparedCaptureTransition()
        selectionTransitionPrepared = false
      }
      if coordinator.state == .selecting {
        if let interactiveCaptureService {
          interactiveCaptureService.cancelCapture()
        } else {
          selectionService?.cancelSelection()
        }
      }
      activeTask?.cancel()
      return true
    case .idle, .cancelled, .failed:
      return false
    }
  }

  private func runScheduledOperation(
    initialObservation: ScreenCaptureAuthorizationObservation?
  ) async {
    defer {
      if selectionTransitionPrepared {
        cancelPreparedCaptureTransition()
        selectionTransitionPrepared = false
      }
      activeTask = nil
      requestedCancellationReason = nil
    }
    guard !transitionToRequestedCancellationIfNeeded() else {
      resetTerminalState()
      return
    }
    await runPermissionFlowIfStillRequested(initialObservation: initialObservation)
  }

  private func runPermissionFlowIfStillRequested(
    initialObservation: ScreenCaptureAuthorizationObservation?
  ) async {
    guard coordinator.state == .requestingPermission else {
      return
    }
    guard !transitionToRequestedCancellationIfNeeded() else {
      resetTerminalState()
      return
    }

    let observation = initialObservation ?? permissionService.currentObservation()
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
    if !selectionTransitionPrepared {
      prepareForCaptureTransition()
      selectionTransitionPrepared = true
    }
    feedbackService.dismiss()

    if let interactiveCaptureService {
      await proceedToInteractiveCapture(using: interactiveCaptureService)
      resetTerminalState()
      return
    }

    do {
      selectionTransitionPrepared = false
      guard let selectionService else {
        throw CaptureOperationInterruption.failure(.internal)
      }
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

  private func proceedToInteractiveCapture(
    using service: any InteractiveCaptureService
  ) async {
    let resolution = await resolveInteractiveCapture(using: service)
    if case .feedback(let feedback) = resolution {
      presentCompletionFeedback(feedback)
    }
  }

  private func resolveInteractiveCapture(
    using service: any InteractiveCaptureService
  ) async -> InteractiveCaptureResolution {
    do {
      selectionTransitionPrepared = false
      let outcome = try await service.capture()
      switch outcome {
      case .captured(let image):
        guard !transitionToRequestedCancellationIfNeeded() else {
          return .finished
        }
        return await completeInteractiveCapture(image).map(
          InteractiveCaptureResolution.feedback
        ) ?? .finished
      case .cancelled(let reason):
        let observation = await permissionService.authoritativeObservation()
        if observation == .granted {
          _ = coordinator.handle(
            .cancel(requestedCancellationReason ?? reason.captureCancellationReason)
          )
        } else {
          recoveryPresenter.present(permissionService.recordCaptureDenial())
          _ = coordinator.handle(.fail(.capture))
        }
        return .finished
      }
    } catch let error as InteractiveCaptureError {
      if transitionToRequestedCancellationIfNeeded() {
        return .finished
      }
      if error == .permissionDenied {
        recoveryPresenter.present(permissionService.recordCaptureDenial())
        _ = coordinator.handle(.fail(.capture))
      } else {
        presentTerminalFailure(.capture)
      }
    } catch {
      if !transitionToRequestedCancellationIfNeeded() {
        presentTerminalFailure(.capture)
      }
    }
    return .finished
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

  private func completeInteractiveCapture(_ image: CGImage) async -> CaptureFeedback? {
    guard case .transitioned = coordinator.handle(.selectionCompleted) else {
      return nil
    }
    permissionService.recordCaptureSuccess()

    do {
      try throwIfCancellationRequested()
      guard case .transitioned = coordinator.handle(.captureCompleted) else {
        throw CaptureOperationInterruption.failure(.internal)
      }
      return try await recognizeAndWrite(image)
    } catch let interruption as CaptureOperationInterruption {
      handle(interruption)
    } catch {
      presentTerminalFailure(.internal)
    }
    return nil
  }

  private func runPrivateOperation(_ selection: SelectionResult) async throws -> CaptureFeedback {
    try throwIfCancellationRequested()
    let image: CGImage
    do {
      guard let screenCaptureService else {
        throw CaptureOperationInterruption.failure(.internal)
      }
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

    return try await recognizeAndWrite(image)
  }

  private func recognizeAndWrite(_ image: CGImage) async throws -> CaptureFeedback {
    async let textAttempt = recognizeText(in: image)
    async let codeAttempt = recognizeCodes(in: image)
    let attempts = await (textAttempt, codeAttempt)
    try throwIfCancellationRequested()
    guard case .transitioned = coordinator.handle(.recognitionCompleted) else {
      throw CaptureOperationInterruption.failure(.internal)
    }

    let resolution = try resolveRecognition(
      textAttempt: attempts.0,
      codeAttempt: attempts.1
    )
    let content: String
    let successFeedback: (String) -> CaptureFeedback
    switch resolution {
    case .text(let recognizedText):
      content = recognizedText
      successFeedback = { .success(preview: $0) }
    case .code(let payload):
      content = payload
      successFeedback = { .codeSuccess(preview: $0) }
    case .noContent:
      return .noContent
    case .ambiguousCodes:
      return .ambiguousCodes
    }

    do {
      try clipboardService.writePlainText(content)
    } catch {
      throw CaptureOperationInterruption.failure(.clipboard)
    }

    successSoundPlayer.play()
    let preview = FeedbackPreview(text: content).text
    return successFeedback(preview)
  }

  private func prepareForCaptureTransition() {
    if let interactiveCaptureService {
      interactiveCaptureService.prepareForCaptureTransition()
    } else {
      selectionService?.prepareForSelectionTransition()
    }
  }

  private func cancelPreparedCaptureTransition() {
    if let interactiveCaptureService {
      interactiveCaptureService.cancelCapture()
    } else {
      selectionService?.cancelSelection()
    }
  }

  private func recognizeText(
    in image: CGImage
  ) async -> RecognitionAttempt<[RecognizedTextObservation]> {
    do {
      return .success(try await ocrService.recognizeText(in: image))
    } catch VisionOCRError.cancelled {
      return .cancelled
    } catch {
      return cancellationReasonIfRequested == nil ? .failure : .cancelled
    }
  }

  private func recognizeCodes(
    in image: CGImage
  ) async -> RecognitionAttempt<[RecognizedCodeObservation]> {
    do {
      return .success(try await barcodeService.recognizeCodes(in: image))
    } catch VisionBarcodeError.cancelled {
      return .cancelled
    } catch {
      return cancellationReasonIfRequested == nil ? .failure : .cancelled
    }
  }

  private func resolveRecognition(
    textAttempt: RecognitionAttempt<[RecognizedTextObservation]>,
    codeAttempt: RecognitionAttempt<[RecognizedCodeObservation]>
  ) throws -> UnifiedRecognitionResolution {
    if textAttempt.isCancelled || codeAttempt.isCancelled {
      throw CaptureOperationInterruption.cancelled(
        requestedCancellationReason ?? .user
      )
    }

    let recognitionFailed = textAttempt.isFailure || codeAttempt.isFailure
    if case .success(let codeObservations) = codeAttempt {
      switch codePayloadAssembler.assemble(codeObservations) {
      case .content(let payload):
        return .code(payload)
      case .ambiguous:
        return .ambiguousCodes
      case .noCode:
        break
      }
    }

    if case .success(let textObservations) = textAttempt {
      let text = textAssembler.assemble(textObservations)
      if !text.isEmpty {
        return .text(text)
      }
    }

    if recognitionFailed {
      throw CaptureOperationInterruption.failure(.recognition)
    }
    return .noContent
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
    feedbackService.dismiss()
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

private enum RecognitionAttempt<Output: Sendable>: Sendable {
  case success(Output)
  case cancelled
  case failure

  var isCancelled: Bool {
    if case .cancelled = self {
      return true
    }
    return false
  }

  var isFailure: Bool {
    if case .failure = self {
      return true
    }
    return false
  }
}

private enum UnifiedRecognitionResolution {
  case text(String)
  case code(String)
  case noContent
  case ambiguousCodes
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
