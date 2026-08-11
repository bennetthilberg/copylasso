import Foundation
import XCTest

@testable import CopyLasso

@MainActor
final class CaptureHistoryControllerTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 2_000_000)

  func testHistoryDefaultsOffAndEnablesWithOneExplicitAction() async {
    let context = makeContext()

    await context.controller.start()
    XCTAssertFalse(context.controller.isEnabled)
    XCTAssertEqual(context.controller.presentationState, .disabled)

    let enabled = await context.controller.enable()
    XCTAssertTrue(enabled)
    XCTAssertTrue(context.controller.isEnabled)
    XCTAssertTrue(context.preferences.isCaptureHistoryEnabled)
    XCTAssertEqual(context.controller.presentationState, .ready)
    let prepareCallCount = await context.store.prepareCallCount
    XCTAssertEqual(prepareCallCount, 1)
  }

  func testDisabledStartupBestEffortPurgesResidualArchiveAndKey() async {
    let context = makeContext(entries: [entry(content: "residual private content")])

    await context.controller.start()

    XCTAssertFalse(context.controller.isEnabled)
    XCTAssertEqual(context.controller.presentationState, .disabled)
    let deleteAllCallCount = await context.store.deleteAllCallCount
    XCTAssertEqual(deleteAllCallCount, 1)
    let remaining = try? await context.store.load(now: now)
    XCTAssertEqual(remaining, [])
  }

  func testEnableFailureLeavesPreferenceOffAndShowsUnavailableState() async {
    let context = makeContext()
    await context.store.setError(.writeFailed)

    let enabled = await context.controller.enable()
    XCTAssertFalse(enabled)

    XCTAssertFalse(context.preferences.isCaptureHistoryEnabled)
    XCTAssertFalse(context.controller.isEnabled)
    XCTAssertEqual(context.controller.presentationState, .unavailable)
  }

  func testDisableWithoutEntriesDeletesDirectly() async {
    let context = makeContext(enabled: true)
    await context.controller.start()

    let disableResult = await context.controller.requestDisable()
    XCTAssertEqual(disableResult, .disabled)

    XCTAssertFalse(context.preferences.isCaptureHistoryEnabled)
    XCTAssertFalse(context.controller.isEnabled)
    let deleteAllCallCount = await context.store.deleteAllCallCount
    XCTAssertEqual(deleteAllCallCount, 1)
  }

  func testDisableWithEntriesRequiresConfirmationAndCancelPreservesEverything() async {
    let context = makeContext(enabled: true, entries: [entry(content: "private")])
    await context.controller.start()

    let disableResult = await context.controller.requestDisable()
    XCTAssertEqual(disableResult, .confirmationRequired)
    XCTAssertTrue(context.controller.requiresDisableConfirmation)
    context.controller.cancelDisable()

    XCTAssertTrue(context.preferences.isCaptureHistoryEnabled)
    XCTAssertTrue(context.controller.isEnabled)
    let deleteAllCallCount = await context.store.deleteAllCallCount
    XCTAssertEqual(deleteAllCallCount, 0)
  }

  func testConfirmedDisableDeletesArchiveAndKeyThenClearsDecryptedState() async {
    let context = makeContext(enabled: true, entries: [entry(content: "private")])
    await context.controller.openHistory()
    XCTAssertFalse(context.controller.entries.isEmpty)
    _ = await context.controller.requestDisable()

    let disabled = await context.controller.confirmDisable()
    XCTAssertTrue(disabled)

    XCTAssertFalse(context.controller.isEnabled)
    XCTAssertEqual(context.controller.entries, [])
    XCTAssertEqual(context.controller.presentationState, .disabled)
    let deleteAllCallCount = await context.store.deleteAllCallCount
    XCTAssertEqual(deleteAllCallCount, 1)
  }

  func testUnreadableHistoryAlsoRequiresDestructiveConfirmation() async {
    let context = makeContext(enabled: true)
    await context.store.setError(.authenticationFailed)
    await context.controller.start()

    XCTAssertEqual(context.controller.presentationState, .unavailable)
    let disableResult = await context.controller.requestDisable()
    XCTAssertEqual(disableResult, .confirmationRequired)
  }

  func testRecordStoresOnlyWhenEnabledAndRetainsDuplicates() async {
    let context = makeContext()

    let disabledResult = await context.controller.record(content: "same", kind: .text)
    XCTAssertEqual(disabledResult, .notEnabled)
    let enabled = await context.controller.enable()
    XCTAssertTrue(enabled)
    let firstResult = await context.controller.record(content: "same", kind: .text)
    let secondResult = await context.controller.record(content: "same", kind: .text)
    XCTAssertEqual(firstResult, .recorded)
    XCTAssertEqual(secondResult, .recorded)

    let appendedContents = await context.store.appendedContents
    XCTAssertEqual(appendedContents, ["same", "same"])
  }

  func testRecordFailureDoesNotExposeContentOrDisableThePreference() async {
    let context = makeContext(enabled: true)
    await context.store.setAppendError(.writeFailed)

    let result = await context.controller.record(content: "must remain private", kind: .text)
    XCTAssertEqual(result, .failed)

    XCTAssertTrue(context.controller.isEnabled)
    XCTAssertEqual(context.controller.presentationState, .unavailable)
    XCTAssertEqual(context.controller.entries, [])
  }

  func testOversizedRecordIsSkippedWithoutInvalidatingExistingHistory() async {
    let existing = entry(content: "existing")
    let context = makeContext(enabled: true, entries: [existing])
    await context.controller.openHistory()
    await context.store.setAppendError(.contentTooLarge)

    let result = await context.controller.record(content: "oversized", kind: .text)

    XCTAssertEqual(result, .skipped)
    XCTAssertTrue(context.controller.isEnabled)
    XCTAssertEqual(context.controller.presentationState, .ready)
    XCTAssertEqual(context.controller.entries, [existing])
  }

  func testOpeningLoadsNewestFirstAndClosingOrLockClearsDecryptedContent() async {
    let entries = [
      entry(content: "older", offset: -2),
      entry(content: "newer", offset: -1),
    ]
    let context = makeContext(enabled: true, entries: entries)

    await context.controller.openHistory()
    XCTAssertEqual(context.controller.entries.map(\.content), ["newer", "older"])

    context.controller.closeHistory()
    XCTAssertEqual(context.controller.entries, [])

    await context.controller.openHistory()
    context.controller.clearDecryptedState()
    XCTAssertEqual(context.controller.entries, [])
    XCTAssertEqual(context.controller.presentationState, .locked)
  }

  func testCopyWritesExactlyOncePlaysSoundShowsTypedFeedbackAndDoesNotRecord() async {
    let text = entry(content: "stored text", kind: .text)
    let code = entry(content: "https://copylasso.com", kind: .code)
    let context = makeContext(enabled: true, entries: [text, code])
    await context.controller.openHistory()

    XCTAssertTrue(context.controller.copy(id: text.id))
    XCTAssertTrue(context.controller.copy(id: code.id))

    XCTAssertEqual(context.clipboard.writtenTexts, ["stored text", "https://copylasso.com"])
    XCTAssertEqual(context.sound.playCallCount, 2)
    XCTAssertEqual(
      context.feedback.presentedFeedback,
      [.success(preview: "stored text"), .codeSuccess(preview: "https://copylasso.com")]
    )
    let appendedContents = await context.store.appendedContents
    XCTAssertEqual(appendedContents, [])
  }

  func testClipboardFailureFromHistoryIsSilentAndPresentsExistingFailure() async {
    let stored = entry(content: "stored")
    let context = makeContext(enabled: true, entries: [stored])
    context.clipboard.error = .injected
    await context.controller.openHistory()

    XCTAssertFalse(context.controller.copy(id: stored.id))

    XCTAssertEqual(context.sound.playCallCount, 0)
    XCTAssertEqual(context.feedback.presentedFeedback, [.failure(.clipboard)])
  }

  func testDeleteAndClearUpdateTheWindowWhileClearRotatesTheKey() async {
    let first = entry(content: "first")
    let second = entry(content: "second")
    let context = makeContext(enabled: true, entries: [first, second])
    await context.controller.openHistory()

    let didDelete = await context.controller.delete(id: first.id)
    XCTAssertTrue(didDelete)
    XCTAssertEqual(context.controller.entries.map(\.id), [second.id])

    let didClear = await context.controller.clearAll()
    XCTAssertTrue(didClear)
    XCTAssertEqual(context.controller.entries, [])
    XCTAssertTrue(context.controller.isEnabled)
    let deleteAllCallCount = await context.store.deleteAllCallCount
    let prepareCallCount = await context.store.prepareCallCount
    XCTAssertEqual(deleteAllCallCount, 1)
    XCTAssertEqual(prepareCallCount, 1)
  }

  func testClearAllCannotOverlapConfirmedDisableOrRecreateItsKey() async {
    let stored = entry(content: "private")
    let preferences = StubAppSettingsStore()
    preferences.isCaptureHistoryEnabled = true
    let store = SuspendedFirstDeleteAllCaptureHistoryStore(entries: [stored])
    let controller = CaptureHistoryController(
      preferences: preferences,
      store: store,
      clipboardService: SpyClipboardService(),
      successSoundPlayer: SpySuccessSoundPlayer(),
      feedbackService: SpyFeedbackService(),
      expirationScheduler: StubCaptureHistoryExpirationScheduler(),
      now: { self.now }
    )
    let disableRequest = await controller.requestDisable()
    XCTAssertEqual(disableRequest, .confirmationRequired)

    let disabling = Task { await controller.confirmDisable() }
    await store.waitUntilFirstDeleteStarts()

    let didClear = await controller.clearAll()
    XCTAssertFalse(didClear)
    let deleteCountWhileDisabling = await store.deleteAllCallCount
    let prepareCountWhileDisabling = await store.prepareCallCount
    XCTAssertEqual(deleteCountWhileDisabling, 1)
    XCTAssertEqual(prepareCountWhileDisabling, 0)

    await store.resumeFirstDelete()
    let didDisable = await disabling.value
    XCTAssertTrue(didDisable)
    XCTAssertFalse(controller.isEnabled)
    XCTAssertEqual(controller.presentationState, .disabled)
  }

  func testConfirmedDisableCannotOverlapClearAllOrOverrideItsKeyRotation() async {
    let stored = entry(content: "private")
    let preferences = StubAppSettingsStore()
    preferences.isCaptureHistoryEnabled = true
    let store = SuspendedFirstDeleteAllCaptureHistoryStore(entries: [stored])
    let controller = CaptureHistoryController(
      preferences: preferences,
      store: store,
      clipboardService: SpyClipboardService(),
      successSoundPlayer: SpySuccessSoundPlayer(),
      feedbackService: SpyFeedbackService(),
      expirationScheduler: StubCaptureHistoryExpirationScheduler(),
      now: { self.now }
    )
    let disableRequest = await controller.requestDisable()
    XCTAssertEqual(disableRequest, .confirmationRequired)

    let clearing = Task { await controller.clearAll() }
    await store.waitUntilFirstDeleteStarts()

    let didDisable = await controller.confirmDisable()
    XCTAssertFalse(didDisable)
    XCTAssertTrue(preferences.isCaptureHistoryEnabled)
    let deleteCountWhileClearing = await store.deleteAllCallCount
    XCTAssertEqual(deleteCountWhileClearing, 1)

    await store.resumeFirstDelete()
    let didClear = await clearing.value
    XCTAssertTrue(didClear)
    XCTAssertTrue(controller.isEnabled)
    XCTAssertEqual(controller.presentationState, .ready)
    let prepareCallCount = await store.prepareCallCount
    XCTAssertEqual(prepareCallCount, 1)
  }

  func testExpirationSchedulerPrunesWithoutRetainingClosedWindowContent() async {
    let stored = entry(content: "expires", offset: -1)
    let scheduler = StubCaptureHistoryExpirationScheduler()
    let context = makeContext(enabled: true, entries: [stored], scheduler: scheduler)

    await context.controller.start()
    XCTAssertEqual(context.controller.entries, [])
    XCTAssertNotNil(scheduler.scheduledDate)

    await scheduler.fire()
    let loadCallCount = await context.store.loadCallCount
    XCTAssertEqual(loadCallCount, 2)
    XCTAssertEqual(context.controller.entries, [])
  }

  func testScheduledExpirationPreservesLockedPresentationUntilExplicitReload() async {
    let stored = entry(content: "expires later", offset: -1)
    let scheduler = StubCaptureHistoryExpirationScheduler()
    let context = makeContext(enabled: true, entries: [stored], scheduler: scheduler)
    await context.controller.openHistory()
    context.controller.clearDecryptedState()

    await scheduler.fire()

    XCTAssertEqual(context.controller.entries, [])
    XCTAssertEqual(context.controller.presentationState, .locked)
    XCTAssertNotNil(scheduler.scheduledDate)
  }

  func testConfirmedDisableWaitsForAnAcceptedRecordThenDeletesIt() async {
    let existing = entry(content: "existing")
    let preferences = StubAppSettingsStore()
    preferences.isCaptureHistoryEnabled = true
    let store = SuspendedAppendCaptureHistoryStore(entries: [existing])
    let controller = CaptureHistoryController(
      preferences: preferences,
      store: store,
      clipboardService: SpyClipboardService(),
      successSoundPlayer: SpySuccessSoundPlayer(),
      feedbackService: SpyFeedbackService(),
      expirationScheduler: StubCaptureHistoryExpirationScheduler(),
      now: { self.now }
    )
    let confirmationResult = await controller.requestDisable()
    XCTAssertEqual(confirmationResult, .confirmationRequired)

    let recording = Task { await controller.record(content: "racing", kind: .text) }
    await store.waitUntilAppendStarts()
    let disabling = Task { await controller.confirmDisable() }
    for _ in 0..<10 { await Task.yield() }

    XCTAssertFalse(preferences.isCaptureHistoryEnabled)
    let deleteCountBeforeResume = await store.deleteAllCallCount
    XCTAssertEqual(deleteCountBeforeResume, 0)

    await store.resumeAppend()
    let recordingResult = await recording.value
    let disableResult = await disabling.value
    XCTAssertEqual(recordingResult, .recorded)
    XCTAssertTrue(disableResult)
    let remainingContents = await store.contents
    XCTAssertEqual(remainingContents, [])
    XCTAssertFalse(controller.isEnabled)
  }

  func testFailedConfirmedDisableRestoresConsentAndAcceptsLaterRecords() async {
    let context = makeContext(enabled: true, entries: [entry(content: "existing")])
    let confirmationResult = await context.controller.requestDisable()
    XCTAssertEqual(confirmationResult, .confirmationRequired)
    await context.store.setError(.deletionFailed)

    let didDisable = await context.controller.confirmDisable()
    XCTAssertFalse(didDisable)
    XCTAssertTrue(context.controller.isEnabled)

    await context.store.setError(nil)
    let laterResult = await context.controller.record(content: "later", kind: .text)
    XCTAssertEqual(laterResult, .recorded)
  }

  func testOpeningHistoryInvalidatesAnOlderLaunchLoad() async {
    let stored = entry(content: "visible after immediate open")
    let preferences = StubAppSettingsStore()
    preferences.isCaptureHistoryEnabled = true
    let store = SuspendedFirstLoadCaptureHistoryStore(entries: [stored])
    let controller = CaptureHistoryController(
      preferences: preferences,
      store: store,
      clipboardService: SpyClipboardService(),
      successSoundPlayer: SpySuccessSoundPlayer(),
      feedbackService: SpyFeedbackService(),
      expirationScheduler: StubCaptureHistoryExpirationScheduler(),
      now: { self.now }
    )

    let startup = Task { await controller.start() }
    await store.waitUntilFirstLoadStarts()
    await controller.openHistory()
    XCTAssertEqual(controller.entries, [stored])

    await store.resumeFirstLoad()
    await startup.value
    XCTAssertEqual(controller.entries, [stored])
    XCTAssertEqual(controller.presentationState, .ready)
  }

  private func makeContext(
    enabled: Bool = false,
    entries: [CaptureHistoryEntry] = [],
    scheduler: StubCaptureHistoryExpirationScheduler = StubCaptureHistoryExpirationScheduler()
  ) -> Context {
    let preferences = StubAppSettingsStore()
    preferences.isCaptureHistoryEnabled = enabled
    let store = StubCaptureHistoryStore(entries: entries)
    let clipboard = SpyClipboardService()
    let sound = SpySuccessSoundPlayer()
    let feedback = SpyFeedbackService()
    let controller = CaptureHistoryController(
      preferences: preferences,
      store: store,
      clipboardService: clipboard,
      successSoundPlayer: sound,
      feedbackService: feedback,
      expirationScheduler: scheduler,
      now: { self.now }
    )
    return Context(
      controller: controller,
      preferences: preferences,
      store: store,
      clipboard: clipboard,
      sound: sound,
      feedback: feedback
    )
  }

  private func entry(
    content: String,
    kind: CaptureHistoryContentKind = .text,
    offset: TimeInterval = 0
  ) -> CaptureHistoryEntry {
    CaptureHistoryEntry(
      id: UUID(),
      capturedAt: now.addingTimeInterval(offset),
      kind: kind,
      content: content
    )
  }

  private struct Context {
    let controller: CaptureHistoryController
    let preferences: StubAppSettingsStore
    let store: StubCaptureHistoryStore
    let clipboard: SpyClipboardService
    let sound: SpySuccessSoundPlayer
    let feedback: SpyFeedbackService
  }
}

private actor StubCaptureHistoryStore: CaptureHistoryStoring {
  private(set) var entries: [CaptureHistoryEntry]
  private(set) var prepareCallCount = 0
  private(set) var deleteAllCallCount = 0
  private(set) var loadCallCount = 0
  private(set) var appendedContents: [String] = []
  private var error: CaptureHistoryStoreError?
  private var appendError: CaptureHistoryStoreError?

  init(entries: [CaptureHistoryEntry]) {
    self.entries = entries
  }

  func setError(_ error: CaptureHistoryStoreError?) {
    self.error = error
  }

  func setAppendError(_ error: CaptureHistoryStoreError?) {
    appendError = error
  }

  func prepare() throws {
    prepareCallCount += 1
    if let error { throw error }
  }

  func load(now: Date) throws -> [CaptureHistoryEntry] {
    loadCallCount += 1
    if let error { throw error }
    entries = CaptureHistoryPolicy.retainedEntries(entries, now: now)
    return entries
  }

  func append(
    content: String,
    kind: CaptureHistoryContentKind,
    at date: Date
  ) throws -> CaptureHistoryEntry {
    if let appendError { throw appendError }
    let entry = CaptureHistoryEntry(id: UUID(), capturedAt: date, kind: kind, content: content)
    entries = CaptureHistoryPolicy.retainedEntries([entry] + entries, now: date)
    appendedContents.append(content)
    return entry
  }

  func delete(id: UUID, now: Date) {
    entries = CaptureHistoryPolicy.retainedEntries(
      entries.filter { $0.id != id },
      now: now
    )
  }

  func deleteAll() throws {
    deleteAllCallCount += 1
    if let error { throw error }
    entries = []
  }
}

private actor SuspendedFirstLoadCaptureHistoryStore: CaptureHistoryStoring {
  private let entries: [CaptureHistoryEntry]
  private var shouldSuspend = true
  private var firstLoadContinuation: CheckedContinuation<Void, Never>?

  init(entries: [CaptureHistoryEntry]) {
    self.entries = entries
  }

  func prepare() {}

  func load(now _: Date) async -> [CaptureHistoryEntry] {
    if shouldSuspend {
      shouldSuspend = false
      await withCheckedContinuation { continuation in
        firstLoadContinuation = continuation
      }
    }
    return entries
  }

  func append(
    content: String,
    kind: CaptureHistoryContentKind,
    at date: Date
  ) -> CaptureHistoryEntry {
    CaptureHistoryEntry(id: UUID(), capturedAt: date, kind: kind, content: content)
  }

  func delete(id _: UUID, now _: Date) {}

  func deleteAll() {}

  func waitUntilFirstLoadStarts() async {
    while firstLoadContinuation == nil {
      await Task.yield()
    }
  }

  func resumeFirstLoad() {
    firstLoadContinuation?.resume()
    firstLoadContinuation = nil
  }
}

private actor SuspendedAppendCaptureHistoryStore: CaptureHistoryStoring {
  private var entries: [CaptureHistoryEntry]
  private var appendContinuation: CheckedContinuation<Void, Never>?
  private(set) var deleteAllCallCount = 0

  init(entries: [CaptureHistoryEntry]) {
    self.entries = entries
  }

  var contents: [String] {
    entries.map(\.content)
  }

  func prepare() {}

  func load(now _: Date) -> [CaptureHistoryEntry] {
    entries
  }

  func append(
    content: String,
    kind: CaptureHistoryContentKind,
    at date: Date
  ) async -> CaptureHistoryEntry {
    await withCheckedContinuation { continuation in
      appendContinuation = continuation
    }
    let entry = CaptureHistoryEntry(id: UUID(), capturedAt: date, kind: kind, content: content)
    entries.insert(entry, at: 0)
    return entry
  }

  func delete(id: UUID, now _: Date) {
    entries.removeAll { $0.id == id }
  }

  func deleteAll() {
    deleteAllCallCount += 1
    entries = []
  }

  func waitUntilAppendStarts() async {
    while appendContinuation == nil {
      await Task.yield()
    }
  }

  func resumeAppend() {
    appendContinuation?.resume()
    appendContinuation = nil
  }
}

private actor SuspendedFirstDeleteAllCaptureHistoryStore: CaptureHistoryStoring {
  private var entries: [CaptureHistoryEntry]
  private var shouldSuspendDelete = true
  private var firstDeleteContinuation: CheckedContinuation<Void, Never>?
  private(set) var deleteAllCallCount = 0
  private(set) var prepareCallCount = 0

  init(entries: [CaptureHistoryEntry]) {
    self.entries = entries
  }

  func prepare() {
    prepareCallCount += 1
  }

  func load(now _: Date) -> [CaptureHistoryEntry] {
    entries
  }

  func append(
    content: String,
    kind: CaptureHistoryContentKind,
    at date: Date
  ) -> CaptureHistoryEntry {
    let entry = CaptureHistoryEntry(id: UUID(), capturedAt: date, kind: kind, content: content)
    entries.insert(entry, at: 0)
    return entry
  }

  func delete(id: UUID, now _: Date) {
    entries.removeAll { $0.id == id }
  }

  func deleteAll() async {
    deleteAllCallCount += 1
    if shouldSuspendDelete {
      shouldSuspendDelete = false
      await withCheckedContinuation { continuation in
        firstDeleteContinuation = continuation
      }
    }
    entries = []
  }

  func waitUntilFirstDeleteStarts() async {
    while firstDeleteContinuation == nil {
      await Task.yield()
    }
  }

  func resumeFirstDelete() {
    firstDeleteContinuation?.resume()
    firstDeleteContinuation = nil
  }
}

@MainActor
private final class StubCaptureHistoryExpirationScheduler: CaptureHistoryExpirationScheduling {
  private(set) var scheduledDate: Date?
  private var action: (@MainActor () async -> Void)?

  func schedule(at date: Date, action: @escaping @MainActor () async -> Void) {
    scheduledDate = date
    self.action = action
  }

  func cancel() {
    scheduledDate = nil
    action = nil
  }

  func fire() async {
    let action = self.action
    self.action = nil
    await action?()
  }
}
