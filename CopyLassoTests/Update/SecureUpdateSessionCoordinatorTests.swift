import Foundation
import XCTest

@testable import CopyLasso

@MainActor
final class SecureUpdateSessionCoordinatorTests: XCTestCase {
  func testOfferFormatsTheAuthenticatedDownloadSize() {
    let offer = SecureUpdateOffer(
      displayVersion: "0.2.0",
      build: "3",
      releaseNotes: "Notes",
      contentLength: 2_048
    )

    XCTAssertEqual(offer.formattedDownloadSize, "2 KB")
    XCTAssertEqual(
      offer.authenticatedSource,
      "GitHub Releases (github.com/bennetthilberg/copylasso)"
    )
  }

  private let policy = SecureUpdatePolicy(maximumDownloadBytes: 16)

  func testDeferralAdvancesAuthenticatedHighWaterWithoutStartingDownload() {
    let harness = makeHarness()
    var disposition: SecureUpdateSessionDisposition?

    harness.session.present(.sessionValid) { disposition = $0 }
    harness.presenter.updateReply?(.later)

    XCTAssertEqual(disposition, .dismiss)
    XCTAssertEqual(harness.store.highestAuthenticatedBuild, "3")
    XCTAssertEqual(harness.store.deferredBuild, "3")
    XCTAssertEqual(harness.presenter.offers.map(\.displayVersion), ["0.2.0"])
    XCTAssertEqual(harness.presenter.downloadProgress.count, 0)
  }

  func testExplicitDownloadChoiceClearsDeferralAndStartsOnlyAfterSparkleCallback() {
    let harness = makeHarness()
    harness.store.deferredBuild = "3"
    var disposition: SecureUpdateSessionDisposition?

    harness.session.present(.sessionValid) { disposition = $0 }
    harness.presenter.updateReply?(.proceed)

    XCTAssertEqual(disposition, .install)
    XCTAssertNil(harness.store.deferredBuild)
    XCTAssertTrue(harness.presenter.downloadProgress.isEmpty)

    harness.session.beginDownload {}
    XCTAssertEqual(harness.presenter.downloadProgress, [.init(received: 0, total: 8)])
  }

  func testInvalidCandidateFailsClosedAndLeavesStateUnchanged() {
    let harness = makeHarness()
    var candidate = SecureUpdateCandidate.sessionValid
    candidate.feedAuthenticated = false
    var disposition: SecureUpdateSessionDisposition?

    harness.session.present(candidate) { disposition = $0 }
    harness.presenter.acknowledgement?()

    XCTAssertEqual(disposition, .dismiss)
    XCTAssertEqual(harness.presenter.errorCount, 1)
    XCTAssertEqual(harness.store.highestAuthenticatedBuild, "2")
    XCTAssertNil(harness.store.deferredBuild)
  }

  func testCompleteBoundedDownloadRequiresSeparateInstallConfirmation() {
    let harness = makeHarness()
    harness.session.present(.sessionValid) { _ in }
    harness.presenter.updateReply?(.proceed)
    harness.session.beginDownload {}
    harness.session.receiveExpectedContentLength(8)
    harness.session.receiveData(ofLength: 3)
    harness.session.receiveData(ofLength: 5)
    harness.session.beginExtraction()
    harness.session.showExtractionProgress(0.75)
    var disposition: SecureUpdateSessionDisposition?

    harness.session.readyToInstall { disposition = $0 }
    harness.presenter.installReply?(.proceed)

    XCTAssertEqual(disposition, .install)
    XCTAssertEqual(harness.presenter.extractionProgress, [0, 0.75])
    XCTAssertEqual(harness.presenter.readyCount, 1)
    XCTAssertEqual(harness.presenter.errorCount, 0)
  }

  func testResumedDownloadedUpdateSkipsRepeatDownloadOfferAndRequiresInstallConfirmation() {
    let harness = makeHarness()
    var initialDisposition: SecureUpdateSessionDisposition?

    harness.session.present(.sessionValid, stage: .downloaded) {
      initialDisposition = $0
    }
    harness.session.beginExtraction()
    var installDisposition: SecureUpdateSessionDisposition?
    harness.session.readyToInstall { installDisposition = $0 }
    harness.presenter.installReply?(.proceed)

    XCTAssertEqual(initialDisposition, .install)
    XCTAssertEqual(installDisposition, .install)
    XCTAssertTrue(harness.presenter.offers.isEmpty)
    XCTAssertEqual(harness.presenter.extractionProgress, [0])
    XCTAssertEqual(harness.presenter.readyCount, 1)
    XCTAssertEqual(harness.presenter.errorCount, 0)
  }

  func testResumedInstallingUpdateRequiresConsentBeforeSparkleContinues() {
    let harness = makeHarness()
    var disposition: SecureUpdateSessionDisposition?

    harness.session.present(.sessionValid, stage: .installing) { disposition = $0 }
    harness.presenter.installReply?(.later)

    XCTAssertEqual(disposition, .dismiss)
    XCTAssertTrue(harness.presenter.offers.isEmpty)
    XCTAssertEqual(harness.presenter.readyCount, 1)
    XCTAssertEqual(harness.store.deferredBuild, "3")
  }

  func testLengthMismatchCancelsOnceAndRefusesExtractionAndInstall() {
    let harness = makeHarness()
    harness.session.present(.sessionValid) { _ in }
    harness.presenter.updateReply?(.proceed)
    var cancellationCount = 0
    harness.session.beginDownload { cancellationCount += 1 }

    harness.session.receiveExpectedContentLength(7)
    harness.session.receiveExpectedContentLength(7)
    harness.session.beginExtraction()
    var disposition: SecureUpdateSessionDisposition?
    harness.session.readyToInstall { disposition = $0 }
    harness.presenter.acknowledgement?()

    XCTAssertEqual(cancellationCount, 1)
    XCTAssertEqual(disposition, .dismiss)
    XCTAssertEqual(harness.presenter.errorCount, 3)
    XCTAssertEqual(harness.presenter.readyCount, 0)
  }

  func testMissingCandidateCancelsDownloadAndInstallRetryIsRouted() {
    let harness = makeHarness()
    var cancellationCount = 0
    harness.session.beginDownload { cancellationCount += 1 }
    var retryCount = 0
    harness.session.showInstalling(applicationTerminated: false) { retryCount += 1 }
    harness.presenter.retry?()

    XCTAssertEqual(cancellationCount, 1)
    XCTAssertEqual(harness.presenter.errorCount, 1)
    XCTAssertEqual(retryCount, 1)
  }

  private func makeHarness() -> Harness {
    let store = StubSecureUpdateStateStore()
    store.highestAuthenticatedBuild = "2"
    let presenter = StubSecureUpdatePresenter()
    let session = SecureUpdateSessionCoordinator(
      installedBuild: "2",
      stateStore: store,
      policy: policy,
      presenter: presenter
    )
    return Harness(store: store, presenter: presenter, session: session)
  }
}

@MainActor
private struct Harness {
  let store: StubSecureUpdateStateStore
  let presenter: StubSecureUpdatePresenter
  let session: SecureUpdateSessionCoordinator
}

@MainActor
private final class StubSecureUpdateStateStore: SecureUpdateStateStoring {
  var highestAuthenticatedBuild: String?
  var deferredBuild: String?
}

@MainActor
private final class StubSecureUpdatePresenter: SecureUpdatePresenting {
  struct Progress: Equatable {
    let received: UInt64
    let total: UInt64
  }

  var acknowledgement: (() -> Void)?
  var installReply: ((SecureUpdateConsentChoice) -> Void)?
  var retry: (() -> Void)?
  var updateReply: ((SecureUpdateConsentChoice) -> Void)?
  private(set) var downloadProgress: [Progress] = []
  private(set) var errorCount = 0
  private(set) var extractionProgress: [Double] = []
  private(set) var offers: [SecureUpdateOffer] = []
  private(set) var readyCount = 0

  func showChecking(cancellation: @escaping () -> Void) {}

  func showUpdateAvailable(
    _ offer: SecureUpdateOffer,
    reply: @escaping (SecureUpdateConsentChoice) -> Void
  ) {
    offers.append(offer)
    updateReply = reply
  }

  func showNoUpdate(acknowledgement: @escaping () -> Void) {
    self.acknowledgement = acknowledgement
  }

  func showError(acknowledgement: @escaping () -> Void) {
    errorCount += 1
    self.acknowledgement = acknowledgement
  }

  func showDownloading(
    receivedBytes: UInt64,
    totalBytes: UInt64,
    cancellation: @escaping () -> Void
  ) {
    downloadProgress.append(.init(received: receivedBytes, total: totalBytes))
  }

  func showExtracting(progress: Double) {
    extractionProgress.append(progress)
  }

  func showReadyToInstall(reply: @escaping (SecureUpdateConsentChoice) -> Void) {
    readyCount += 1
    installReply = reply
  }

  func showInstalling(applicationTerminated: Bool, retry: @escaping () -> Void) {
    self.retry = retry
  }

  func showInstalled(relaunched: Bool, acknowledgement: @escaping () -> Void) {
    self.acknowledgement = acknowledgement
  }

  func dismiss() {}
  func focus() {}
}

extension SecureUpdateCandidate {
  fileprivate static let sessionValid = SecureUpdateCandidate(
    feedAuthenticated: true,
    informationOnly: false,
    build: "3",
    displayVersion: "0.2.0",
    releaseNotes: .inlinePlainText("Security and reliability improvements."),
    contentLength: 8,
    downloadURL: URL(
      string:
        "https://github.com/bennetthilberg/copylasso/releases/download/v0.2.0/CopyLasso-0.2.0.dmg"
    )!
  )
}
