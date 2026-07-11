import XCTest

@testable import CopyLasso

@MainActor
final class ScreenCapturePermissionServiceTests: XCTestCase {
  func testConstructionPerformsNoPermissionOrSettingsOperation() {
    let context = makeContext(preflight: false, request: false, openSettings: true)

    _ = context.service

    XCTAssertEqual(context.client.preflightCallCount, 0)
    XCTAssertEqual(context.client.requestCallCount, 0)
    XCTAssertEqual(context.client.openedURLs, [])
  }

  func testCurrentObservationPreservesEveryHistoryInference() {
    let fresh = makeContext(preflight: false)
    XCTAssertEqual(fresh.service.currentObservation(), .notGrantedNeverRequested)

    let requested = makeContext(
      history: ScreenCapturePermissionHistory(hasRequested: true),
      preflight: false
    )
    XCTAssertEqual(requested.service.currentObservation(), .notGrantedAfterRequest)

    let previouslyGranted = makeContext(
      history: ScreenCapturePermissionHistory(
        hasRequested: true,
        hasObservedGranted: true
      ),
      preflight: false
    )
    XCTAssertEqual(
      previouslyGranted.service.currentObservation(),
      .notGrantedAfterPreviouslyGranted
    )
  }

  func testCurrentGrantedObservationPersistsDirectlyObservedAccess() {
    let context = makeContext(preflight: true)

    XCTAssertEqual(context.service.currentObservation(), .granted)
    XCTAssertTrue(context.history.history.hasObservedGranted)
    XCTAssertFalse(context.history.history.hasRequested)
    XCTAssertEqual(context.client.preflightCallCount, 1)
    XCTAssertEqual(context.client.requestCallCount, 0)
  }

  func testRequestPersistsHistoryBeforeInvokingTheSystemClient() {
    let history = StubPermissionHistoryStore()
    var historyAtRequest: ScreenCapturePermissionHistory?
    let client = ScreenCapturePermissionClient(
      preflight: { false },
      request: {
        historyAtRequest = history.history
        return false
      },
      openURL: { _ in true }
    )
    let service = SystemScreenCapturePermissionService(
      historyStore: history,
      client: client
    )

    XCTAssertEqual(service.requestAccess(), .notGrantedAfterRequest)
    XCTAssertEqual(
      historyAtRequest,
      ScreenCapturePermissionHistory(hasRequested: true)
    )
    XCTAssertTrue(history.history.hasRequested)
    XCTAssertFalse(history.history.hasObservedGranted)
  }

  func testGrantedRequestPersistsBothHistoryFacts() {
    let context = makeContext(preflight: false, request: true)

    XCTAssertEqual(context.service.requestAccess(), .granted)
    XCTAssertEqual(
      context.history.history,
      ScreenCapturePermissionHistory(
        hasRequested: true,
        hasObservedGranted: true
      )
    )
    XCTAssertEqual(context.client.requestCallCount, 1)
  }

  func testAuthoritativeCaptureDenialRecordsLikelyRevokedWithoutAnotherSystemCall() {
    let context = makeContext(
      history: ScreenCapturePermissionHistory(hasObservedGranted: true),
      preflight: true,
      request: true
    )

    XCTAssertEqual(
      context.service.recordCaptureDenial(),
      .notGrantedAfterPreviouslyGranted
    )
    XCTAssertEqual(
      context.history.history,
      ScreenCapturePermissionHistory(
        hasRequested: true,
        hasObservedGranted: true
      )
    )
    XCTAssertEqual(
      context.service.currentObservation(),
      .notGrantedAfterPreviouslyGranted
    )
    XCTAssertEqual(context.client.preflightCallCount, 0)
    XCTAssertEqual(context.client.requestCallCount, 0)
  }

  func testExplicitUserRetryAllowsOneObservationUntilCaptureSucceeds() {
    let context = makeContext(
      history: ScreenCapturePermissionHistory(hasObservedGranted: true),
      preflight: true
    )
    _ = context.service.recordCaptureDenial()

    XCTAssertEqual(
      context.service.currentObservation(),
      .notGrantedAfterPreviouslyGranted
    )
    XCTAssertEqual(context.client.preflightCallCount, 0)

    context.service.beginUserInitiatedRetry()

    XCTAssertEqual(context.service.currentObservation(), .granted)
    XCTAssertEqual(context.client.preflightCallCount, 1)
    XCTAssertEqual(
      context.service.currentObservation(),
      .notGrantedAfterPreviouslyGranted
    )
    XCTAssertEqual(context.client.preflightCallCount, 1)

    context.service.recordCaptureSuccess()

    XCTAssertEqual(context.service.currentObservation(), .granted)
    XCTAssertEqual(context.client.preflightCallCount, 2)
  }

  func testOpenSystemSettingsUsesTheScreenRecordingPrivacyPaneAndReportsFailure() {
    let success = makeContext(openSettings: true)
    XCTAssertTrue(success.service.openSystemSettings())
    XCTAssertEqual(
      success.client.openedURLs.map(\.absoluteString),
      ["x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"]
    )

    let failure = makeContext(openSettings: false)
    XCTAssertFalse(failure.service.openSystemSettings())
    XCTAssertEqual(failure.client.openedURLs.count, 1)
  }

  private func makeContext(
    history: ScreenCapturePermissionHistory = ScreenCapturePermissionHistory(),
    preflight: Bool = false,
    request: Bool = false,
    openSettings: Bool = true
  ) -> Context {
    let historyStore = StubPermissionHistoryStore(history: history)
    let client = PermissionClientSpy(
      preflightResult: preflight,
      requestResult: request,
      openResult: openSettings
    )
    let service = SystemScreenCapturePermissionService(
      historyStore: historyStore,
      client: client.client
    )
    return Context(service: service, history: historyStore, client: client)
  }

  private struct Context {
    let service: SystemScreenCapturePermissionService
    let history: StubPermissionHistoryStore
    let client: PermissionClientSpy
  }
}

@MainActor
private final class StubPermissionHistoryStore: ScreenCapturePermissionHistoryStoring {
  var history: ScreenCapturePermissionHistory

  init(history: ScreenCapturePermissionHistory = ScreenCapturePermissionHistory()) {
    self.history = history
  }

  func reset() {
    history = ScreenCapturePermissionHistory()
  }
}

@MainActor
private final class PermissionClientSpy {
  let preflightResult: Bool
  let requestResult: Bool
  let openResult: Bool
  private(set) var preflightCallCount = 0
  private(set) var requestCallCount = 0
  private(set) var openedURLs: [URL] = []

  init(preflightResult: Bool, requestResult: Bool, openResult: Bool) {
    self.preflightResult = preflightResult
    self.requestResult = requestResult
    self.openResult = openResult
  }

  var client: ScreenCapturePermissionClient {
    ScreenCapturePermissionClient(
      preflight: { [weak self] in
        guard let self else { return false }
        preflightCallCount += 1
        return preflightResult
      },
      request: { [weak self] in
        guard let self else { return false }
        requestCallCount += 1
        return requestResult
      },
      openURL: { [weak self] url in
        guard let self else { return false }
        openedURLs.append(url)
        return openResult
      }
    )
  }
}
