import Combine
import Foundation

enum CaptureHistoryPresentationState: Equatable, Sendable {
  case disabled
  case ready
  case locked
  case unavailable
}

enum CaptureHistoryDisableResult: Equatable, Sendable {
  case disabled
  case confirmationRequired
  case failed
}

enum CaptureHistoryRecordingResult: Equatable, Sendable {
  case recorded
  case notEnabled
  case skipped
  case failed
}

@MainActor
protocol CaptureHistoryRecording: AnyObject {
  func record(
    content: String,
    kind: CaptureHistoryContentKind
  ) async -> CaptureHistoryRecordingResult
}

@MainActor
final class NoopCaptureHistoryRecorder: CaptureHistoryRecording {
  func record(
    content _: String,
    kind _: CaptureHistoryContentKind
  ) async -> CaptureHistoryRecordingResult {
    .notEnabled
  }
}

@MainActor
protocol CaptureHistoryExpirationScheduling: AnyObject {
  func schedule(at date: Date, action: @escaping @MainActor () async -> Void)
  func cancel()
}

@MainActor
final class SystemCaptureHistoryExpirationScheduler: CaptureHistoryExpirationScheduling {
  private var task: Task<Void, Never>?

  func schedule(at date: Date, action: @escaping @MainActor () async -> Void) {
    cancel()
    let interval = max(0, date.timeIntervalSinceNow)
    task = Task { @MainActor in
      do {
        try await Task.sleep(for: .seconds(interval))
      } catch {
        return
      }
      guard !Task.isCancelled else { return }
      await action()
    }
  }

  func cancel() {
    task?.cancel()
    task = nil
  }
}

@MainActor
final class CaptureHistoryController: ObservableObject, CaptureHistoryRecording {
  @Published private(set) var entries: [CaptureHistoryEntry] = []
  @Published private(set) var presentationState: CaptureHistoryPresentationState
  @Published private(set) var requiresDisableConfirmation = false

  private let preferences: any CaptureHistoryPreferenceStoring
  private let store: any CaptureHistoryStoring
  private let clipboardService: any ClipboardService
  private let successSoundPlayer: any SuccessSoundPlaying
  private let feedbackService: any FeedbackService
  private let expirationScheduler: any CaptureHistoryExpirationScheduling
  private let now: () -> Date
  private var isWindowOpen = false
  private var isLocked = false
  private var reloadGeneration = 0
  private var activeRecordingCount = 0
  private var isDestructiveOperationInProgress = false
  private var recordingDrainContinuations: [CheckedContinuation<Void, Never>] = []

  var isEnabled: Bool {
    preferences.isCaptureHistoryEnabled
  }

  init(
    preferences: any CaptureHistoryPreferenceStoring,
    store: any CaptureHistoryStoring,
    clipboardService: any ClipboardService,
    successSoundPlayer: any SuccessSoundPlaying,
    feedbackService: any FeedbackService,
    expirationScheduler: any CaptureHistoryExpirationScheduling =
      SystemCaptureHistoryExpirationScheduler(),
    now: @escaping () -> Date = Date.init
  ) {
    self.preferences = preferences
    self.store = store
    self.clipboardService = clipboardService
    self.successSoundPlayer = successSoundPlayer
    self.feedbackService = feedbackService
    self.expirationScheduler = expirationScheduler
    self.now = now
    presentationState = preferences.isCaptureHistoryEnabled ? .ready : .disabled
  }

  func start() async {
    guard isEnabled else {
      try? await store.deleteAll()
      setDisabledState()
      return
    }
    await reload()
  }

  func enable() async -> Bool {
    guard !isDestructiveOperationInProgress else { return false }
    do {
      try await store.prepare()
      preferences.isCaptureHistoryEnabled = true
      presentationState = .ready
      requiresDisableConfirmation = false
      await reload()
      return true
    } catch {
      preferences.isCaptureHistoryEnabled = false
      entries = []
      presentationState = .unavailable
      expirationScheduler.cancel()
      return false
    }
  }

  func requestDisable() async -> CaptureHistoryDisableResult {
    guard isEnabled else {
      setDisabledState()
      return .disabled
    }

    do {
      let storedEntries = try await store.load(now: now())
      scheduleExpiration(for: storedEntries)
      if storedEntries.isEmpty {
        return await disableImmediately()
      }
    } catch {
      presentationState = .unavailable
    }

    requiresDisableConfirmation = true
    return .confirmationRequired
  }

  func cancelDisable() {
    requiresDisableConfirmation = false
  }

  func confirmDisable() async -> Bool {
    guard isEnabled, !isDestructiveOperationInProgress else { return false }
    let wasEnabled = preferences.isCaptureHistoryEnabled
    preferences.isCaptureHistoryEnabled = false
    isDestructiveOperationInProgress = true
    await waitForActiveRecordings()
    do {
      try await store.deleteAll()
      setDisabledState()
      return true
    } catch {
      preferences.isCaptureHistoryEnabled = wasEnabled
      isDestructiveOperationInProgress = false
      requiresDisableConfirmation = false
      presentationState = .unavailable
      return false
    }
  }

  func record(
    content: String,
    kind: CaptureHistoryContentKind
  ) async -> CaptureHistoryRecordingResult {
    guard isEnabled, !isDestructiveOperationInProgress else { return .notEnabled }
    activeRecordingCount += 1
    defer { finishRecording() }
    do {
      _ = try await store.append(content: content, kind: kind, at: now())
      await reload()
      return .recorded
    } catch CaptureHistoryStoreError.contentTooLarge {
      return .skipped
    } catch {
      entries = []
      presentationState = .unavailable
      expirationScheduler.cancel()
      return .failed
    }
  }

  func openHistory() async {
    invalidatePendingReloads()
    isWindowOpen = true
    isLocked = false
    guard isEnabled else {
      setDisabledState()
      isWindowOpen = true
      return
    }
    await reload()
  }

  func closeHistory() {
    invalidatePendingReloads()
    isWindowOpen = false
    isLocked = false
    entries = []
  }

  func clearDecryptedState() {
    invalidatePendingReloads()
    entries = []
    guard isEnabled, isWindowOpen else { return }
    isLocked = true
    presentationState = .locked
  }

  @discardableResult
  func copy(id: UUID) -> Bool {
    guard let entry = entries.first(where: { $0.id == id }) else { return false }
    do {
      try clipboardService.writePlainText(entry.content)
      successSoundPlayer.play()
      let preview = FeedbackPreview(text: entry.content).text
      let feedback: CaptureFeedback =
        entry.kind == .code
        ? .codeSuccess(preview: preview)
        : .success(preview: preview)
      try? feedbackService.present(feedback)
      return true
    } catch {
      try? feedbackService.present(.failure(.clipboard))
      return false
    }
  }

  func delete(id: UUID) async -> Bool {
    do {
      try await store.delete(id: id, now: now())
      await reload()
      return true
    } catch {
      entries = []
      presentationState = .unavailable
      expirationScheduler.cancel()
      return false
    }
  }

  func clearAll() async -> Bool {
    guard isEnabled, !isDestructiveOperationInProgress else { return false }
    invalidatePendingReloads()
    isDestructiveOperationInProgress = true
    await waitForActiveRecordings()
    defer { isDestructiveOperationInProgress = false }
    do {
      try await store.deleteAll()
      try await store.prepare()
      entries = []
      presentationState = .ready
      isLocked = false
      expirationScheduler.cancel()
      return true
    } catch {
      entries = []
      presentationState = .unavailable
      expirationScheduler.cancel()
      return false
    }
  }

  func resetLocalDevelopmentState() async {
    invalidatePendingReloads()
    do {
      try await store.deleteAll()
    } catch {
      // Reset remains best effort and does not expose archive or Keychain details.
    }
    preferences.isCaptureHistoryEnabled = false
    setDisabledState()
  }

  private func disableImmediately() async -> CaptureHistoryDisableResult {
    invalidatePendingReloads()
    let wasEnabled = preferences.isCaptureHistoryEnabled
    preferences.isCaptureHistoryEnabled = false
    isDestructiveOperationInProgress = true
    await waitForActiveRecordings()
    do {
      try await store.deleteAll()
      setDisabledState()
      return .disabled
    } catch {
      preferences.isCaptureHistoryEnabled = wasEnabled
      isDestructiveOperationInProgress = false
      presentationState = .unavailable
      return .failed
    }
  }

  private func reload() async {
    let generation = reloadGeneration
    do {
      let loaded = try await store.load(now: now())
      guard generation == reloadGeneration, isEnabled else { return }
      entries = shouldRetainDecryptedContent ? loaded : []
      presentationState = isLocked ? .locked : .ready
      scheduleExpiration(for: loaded)
    } catch {
      guard generation == reloadGeneration, isEnabled else { return }
      entries = []
      presentationState = .unavailable
      expirationScheduler.cancel()
    }
  }

  private func scheduleExpiration(for loadedEntries: [CaptureHistoryEntry]) {
    guard let date = CaptureHistoryPolicy.nextExpiration(for: loadedEntries) else {
      expirationScheduler.cancel()
      return
    }
    expirationScheduler.schedule(at: date) { [weak self] in
      guard let self else { return }
      await self.reload()
    }
  }

  private func setDisabledState() {
    invalidatePendingReloads()
    entries = []
    presentationState = .disabled
    isLocked = false
    isDestructiveOperationInProgress = false
    requiresDisableConfirmation = false
    expirationScheduler.cancel()
  }

  private var shouldRetainDecryptedContent: Bool {
    isWindowOpen && !isLocked
  }

  private func invalidatePendingReloads() {
    reloadGeneration &+= 1
  }

  private func waitForActiveRecordings() async {
    guard activeRecordingCount > 0 else { return }
    await withCheckedContinuation { continuation in
      recordingDrainContinuations.append(continuation)
    }
  }

  private func finishRecording() {
    activeRecordingCount -= 1
    guard activeRecordingCount == 0 else { return }
    let continuations = recordingDrainContinuations
    recordingDrainContinuations.removeAll()
    for continuation in continuations {
      continuation.resume()
    }
  }
}
