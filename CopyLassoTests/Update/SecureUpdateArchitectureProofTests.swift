import Foundation
import Sparkle
import XCTest

final class SecureUpdateArchitectureProofTests: XCTestCase {
  private let policy = SecureUpdateProofPolicy(maximumDownloadBytes: 256 * 1_024 * 1_024)

  func testPinnedSparkleComparatorUsesBundleBuildOrdering() {
    let comparator = SUStandardVersionComparator.default

    XCTAssertEqual(comparator.compareVersion("2", toVersion: "2"), .orderedSame)
    XCTAssertEqual(comparator.compareVersion("3", toVersion: "2"), .orderedDescending)
    XCTAssertEqual(comparator.compareVersion("2", toVersion: "3"), .orderedAscending)
    XCTAssertEqual(comparator.compareVersion("10", toVersion: "9"), .orderedDescending)
  }

  func testAuthenticatedNewerMatchingCandidateReachesInstallDecision() {
    XCTAssertEqual(
      policy.decision(for: .valid, installedBuild: "2", highestAuthenticatedBuild: "2"),
      .installAllowed
    )
  }

  func testCurrentVersionIsNotAnUpdate() {
    var candidate = SecureUpdateProofCandidate.valid
    candidate.feedBuild = "2"
    candidate.archiveBuild = "2"

    XCTAssertEqual(
      policy.decision(for: candidate, installedBuild: "2", highestAuthenticatedBuild: "2"),
      .noUpdate
    )
  }

  func testCurrentBuildBelowAuthenticatedHighWaterIsReplay() {
    var candidate = SecureUpdateProofCandidate.valid
    candidate.feedBuild = "2"
    candidate.archiveBuild = "2"

    XCTAssertEqual(
      policy.decision(for: candidate, installedBuild: "2", highestAuthenticatedBuild: "3"),
      .rejected(.replay)
    )
  }

  func testFirstUpdaterLaunchSeedsHighWaterFromAuthenticatedInstalledBuild() {
    XCTAssertEqual(
      policy.initialHighWaterBuild(installedBuild: "2", persistedBuild: nil),
      "2"
    )
    XCTAssertEqual(
      policy.decision(for: .valid, installedBuild: "2", highestAuthenticatedBuild: nil),
      .installAllowed
    )
    XCTAssertEqual(
      policy.decision(for: .valid, installedBuild: "2", highestAuthenticatedBuild: ""),
      .rejected(.invalidVersion)
    )
  }

  func testUntrustedOrMismatchedCandidatesFailClosed() {
    assertRejected(\.feedAuthenticated, value: false, reason: .invalidFeedSignature)
    assertRejected(\.archiveAuthenticated, value: false, reason: .invalidArchiveSignature)
    assertRejected(\.archiveBuild, value: "4", reason: .versionMismatch)
    assertRejected(\.archiveDisplayVersion, value: "0.2.1", reason: .versionMismatch)
    assertRejected(\.actualDownloadBytes, value: 4_095, reason: .sizeMismatch)
  }

  func testOnlySignedInlinePlainTextReleaseNotesAreAccepted() {
    for source in [
      SecureUpdateProofReleaseNotes.externalURL,
      .inlineHTML,
      .inlinePlainText(" \n"),
      .missing,
    ] {
      var candidate = SecureUpdateProofCandidate.valid
      candidate.releaseNotes = source
      XCTAssertEqual(
        policy.decision(for: candidate, installedBuild: "2", highestAuthenticatedBuild: "2"),
        .rejected(.invalidReleaseNotes)
      )
    }
  }

  func testDowngradeReplayAndMalformedLocationFailClosed() {
    var downgrade = SecureUpdateProofCandidate.valid
    downgrade.feedBuild = "1"
    downgrade.archiveBuild = "1"
    XCTAssertEqual(
      policy.decision(for: downgrade, installedBuild: "2", highestAuthenticatedBuild: "2"),
      .rejected(.downgrade)
    )

    var replay = SecureUpdateProofCandidate.valid
    replay.feedBuild = "3"
    replay.archiveBuild = "3"
    XCTAssertEqual(
      policy.decision(for: replay, installedBuild: "2", highestAuthenticatedBuild: "4"),
      .rejected(.replay)
    )

    for location in [
      "http://github.com/bennetthilberg/copylasso/releases/download/v0.2.0/CopyLasso-0.2.0.dmg",
      "https://example.invalid/CopyLasso-0.2.0.dmg",
      "https://github.com/bennetthilberg/copylasso/archive/CopyLasso-0.2.0.dmg",
      "https://github.com/bennetthilberg/copylasso/releases/download/v0.2.0/update.zip",
      "https://github.com/bennetthilberg/copylasso/releases/download/v0.2.0/CopyLasso-0.2.0.dmg?tracking=1",
      "https://github.com/bennetthilberg/copylasso/releases/download/tag/%2e%2e/%2e%2e/evil/CopyLasso-0.2.0.dmg",
      "https://github.com/bennetthilberg/copylasso/releases/download//v0.2.0/CopyLasso-0.2.0.dmg",
    ] {
      var malformed = SecureUpdateProofCandidate.valid
      malformed.downloadURL = URL(string: location)!
      XCTAssertEqual(
        policy.decision(for: malformed, installedBuild: "2", highestAuthenticatedBuild: "2"),
        .rejected(.invalidDownloadLocation),
        location
      )
    }
  }

  func testBuildVersionsMustUseCanonicalPositiveDecimalIntegers() {
    for version in ["", "0", "01", "1.0", "+3", " 3", "3 ", "３", "1234567890123456789"] {
      var candidate = SecureUpdateProofCandidate.valid
      candidate.feedBuild = version
      candidate.archiveBuild = version
      XCTAssertEqual(
        policy.decision(for: candidate, installedBuild: "2", highestAuthenticatedBuild: "2"),
        .rejected(.invalidVersion),
        version
      )
    }

    XCTAssertEqual(
      policy.decision(
        for: .valid,
        installedBuild: "02",
        highestAuthenticatedBuild: "2"
      ),
      .rejected(.invalidVersion)
    )
    XCTAssertEqual(
      policy.decision(
        for: .valid,
        installedBuild: "2",
        highestAuthenticatedBuild: ""
      ),
      .rejected(.invalidVersion)
    )
  }

  func testEmptyAndOversizedDownloadsFailClosed() {
    for size in [0, 256 * 1_024 * 1_024 + 1] {
      var candidate = SecureUpdateProofCandidate.valid
      candidate.expectedDownloadBytes = size
      candidate.actualDownloadBytes = size
      XCTAssertEqual(
        policy.decision(for: candidate, installedBuild: "2", highestAuthenticatedBuild: "2"),
        .rejected(.invalidDownloadSize)
      )
    }
  }

  func testStreamingDownloadCancelsAtSignedLengthAndAbsoluteCap() {
    var signedLengthCancellationCount = 0
    var signedLengthBudget = SecureUpdateProofDownloadBudget(
      signedExpectedBytes: 4_096,
      maximumBytes: 256 * 1_024 * 1_024
    )
    signedLengthBudget.begin {
      signedLengthCancellationCount += 1
    }
    signedLengthBudget.receiveData(length: 4_096)
    XCTAssertFalse(signedLengthBudget.cancelled)
    signedLengthBudget.receiveData(length: 1)
    XCTAssertTrue(signedLengthBudget.cancelled)
    XCTAssertEqual(signedLengthCancellationCount, 1)
    signedLengthBudget.receiveData(length: UInt64.max)
    XCTAssertEqual(signedLengthCancellationCount, 1)

    var capCancellationCount = 0
    var capBudget = SecureUpdateProofDownloadBudget(
      signedExpectedBytes: 256 * 1_024 * 1_024,
      maximumBytes: 256 * 1_024 * 1_024
    )
    capBudget.begin {
      capCancellationCount += 1
    }
    capBudget.receiveExpectedContentLength(300 * 1_024 * 1_024)
    XCTAssertTrue(capBudget.cancelled)
    XCTAssertEqual(capCancellationCount, 1)
  }

  func testCancellationInterruptionAndOfflineFailureRemoveStagingAndPreserveInstall() {
    for failure in SecureUpdateProofFailure.allCases {
      var transaction = SecureUpdateProofTransaction(installedBuild: "2")
      transaction.beginCheck()
      transaction.beginDownload(candidateBuild: "3")
      transaction.fail(failure)

      XCTAssertEqual(transaction.installedBuild, "2", String(describing: failure))
      XCTAssertNil(transaction.stagedBuild, String(describing: failure))
      XCTAssertEqual(transaction.state, .failed(failure), String(describing: failure))
    }
  }

  func testDeferralAndSuccessfulCommitAreExplicitAndDeterministic() {
    var deferred = SecureUpdateProofTransaction(installedBuild: "2")
    deferred.beginCheck()
    deferred.deferUpdate(candidateBuild: "3")
    XCTAssertEqual(deferred.state, .deferred(candidateBuild: "3"))
    XCTAssertEqual(deferred.installedBuild, "2")
    XCTAssertNil(deferred.stagedBuild)

    var premature = SecureUpdateProofTransaction(installedBuild: "2")
    premature.beginCheck()
    premature.beginDownload(candidateBuild: "3")
    premature.commitInstallAfterConfirmation()
    XCTAssertEqual(premature.installedBuild, "2")
    XCTAssertEqual(premature.state, .downloading(candidateBuild: "3"))

    var installed = SecureUpdateProofTransaction(installedBuild: "2")
    installed.beginCheck()
    installed.beginDownload(candidateBuild: "3")
    installed.finishDownload()
    installed.commitInstallAfterConfirmation()
    XCTAssertEqual(installed.state, .idle)
    XCTAssertEqual(installed.installedBuild, "3")
    XCTAssertNil(installed.stagedBuild)
  }

  private func assertRejected<Value>(
    _ keyPath: WritableKeyPath<SecureUpdateProofCandidate, Value>,
    value: Value,
    reason: SecureUpdateProofRejection,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    var candidate = SecureUpdateProofCandidate.valid
    candidate[keyPath: keyPath] = value
    XCTAssertEqual(
      policy.decision(for: candidate, installedBuild: "2", highestAuthenticatedBuild: "2"),
      .rejected(reason),
      file: file,
      line: line
    )
  }
}

private struct SecureUpdateProofCandidate {
  var feedAuthenticated: Bool
  var archiveAuthenticated: Bool
  var feedBuild: String
  var archiveBuild: String
  var displayVersion: String
  var archiveDisplayVersion: String
  var releaseNotes: SecureUpdateProofReleaseNotes
  var expectedDownloadBytes: Int
  var actualDownloadBytes: Int
  var downloadURL: URL

  static let valid = SecureUpdateProofCandidate(
    feedAuthenticated: true,
    archiveAuthenticated: true,
    feedBuild: "3",
    archiveBuild: "3",
    displayVersion: "0.2.0",
    archiveDisplayVersion: "0.2.0",
    releaseNotes: .inlinePlainText("Security and reliability improvements."),
    expectedDownloadBytes: 4_096,
    actualDownloadBytes: 4_096,
    downloadURL: URL(
      string:
        "https://github.com/bennetthilberg/copylasso/releases/download/v0.2.0/CopyLasso-0.2.0.dmg"
    )!
  )
}

private enum SecureUpdateProofReleaseNotes: Equatable {
  case externalURL
  case inlineHTML
  case inlinePlainText(String)
  case missing
}

private enum SecureUpdateProofRejection: Equatable {
  case downgrade
  case invalidArchiveSignature
  case invalidDownloadLocation
  case invalidDownloadSize
  case invalidFeedSignature
  case invalidReleaseNotes
  case invalidVersion
  case replay
  case sizeMismatch
  case versionMismatch
}

private enum SecureUpdateProofDecision: Equatable {
  case installAllowed
  case noUpdate
  case rejected(SecureUpdateProofRejection)
}

private struct SecureUpdateProofPolicy {
  let maximumDownloadBytes: Int

  func decision(
    for candidate: SecureUpdateProofCandidate,
    installedBuild: String,
    highestAuthenticatedBuild: String?
  ) -> SecureUpdateProofDecision {
    let comparator = SUStandardVersionComparator.default

    guard isCanonicalBuild(candidate.feedBuild),
      isCanonicalBuild(candidate.archiveBuild),
      let resolvedHighWaterBuild = initialHighWaterBuild(
        installedBuild: installedBuild,
        persistedBuild: highestAuthenticatedBuild
      )
    else {
      return .rejected(.invalidVersion)
    }
    guard candidate.feedAuthenticated else { return .rejected(.invalidFeedSignature) }
    guard candidate.archiveAuthenticated else { return .rejected(.invalidArchiveSignature) }
    guard candidate.feedBuild == candidate.archiveBuild,
      candidate.displayVersion == candidate.archiveDisplayVersion
    else {
      return .rejected(.versionMismatch)
    }
    guard case .inlinePlainText(let releaseNotes) = candidate.releaseNotes,
      !releaseNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      return .rejected(.invalidReleaseNotes)
    }
    guard candidate.expectedDownloadBytes > 0,
      candidate.expectedDownloadBytes <= maximumDownloadBytes
    else {
      return .rejected(.invalidDownloadSize)
    }
    guard candidate.expectedDownloadBytes == candidate.actualDownloadBytes else {
      return .rejected(.sizeMismatch)
    }
    guard
      isApprovedDownloadLocation(
        candidate.downloadURL,
        displayVersion: candidate.displayVersion
      )
    else {
      return .rejected(.invalidDownloadLocation)
    }

    let installedComparison = comparator.compareVersion(
      candidate.feedBuild,
      toVersion: installedBuild
    )
    if installedComparison == .orderedAscending { return .rejected(.downgrade) }
    if comparator.compareVersion(candidate.feedBuild, toVersion: resolvedHighWaterBuild)
      == .orderedAscending
    {
      return .rejected(.replay)
    }
    if installedComparison == .orderedSame { return .noUpdate }
    return .installAllowed
  }

  func initialHighWaterBuild(installedBuild: String, persistedBuild: String?) -> String? {
    guard isCanonicalBuild(installedBuild) else { return nil }
    guard let persistedBuild else { return installedBuild }
    guard isCanonicalBuild(persistedBuild) else { return nil }
    return persistedBuild
  }

  private func isCanonicalBuild(_ version: String) -> Bool {
    guard (1...18).contains(version.utf8.count),
      version.utf8.first.map({ (49...57).contains($0) }) == true
    else {
      return false
    }
    return version.utf8.allSatisfy { (48...57).contains($0) }
  }

  private func isApprovedDownloadLocation(_ url: URL, displayVersion: String) -> Bool {
    let expectedPath =
      "/bennetthilberg/copylasso/releases/download/v\(displayVersion)/CopyLasso-\(displayVersion).dmg"
    let expectedComponents = [
      "/",
      "bennetthilberg",
      "copylasso",
      "releases",
      "download",
      "v\(displayVersion)",
      "CopyLasso-\(displayVersion).dmg",
    ]
    guard url.scheme == "https",
      url.host == "github.com",
      url.user == nil,
      url.password == nil,
      url.port == nil,
      url.query == nil,
      url.fragment == nil,
      url.path(percentEncoded: true) == expectedPath,
      url.pathComponents == expectedComponents
    else {
      return false
    }
    return true
  }

}

private struct SecureUpdateProofDownloadBudget {
  let signedExpectedBytes: UInt64
  let maximumBytes: UInt64

  private(set) var cancelled = false
  private(set) var receivedBytes: UInt64 = 0
  private var cancellation: (() -> Void)?

  init(signedExpectedBytes: UInt64, maximumBytes: UInt64) {
    self.signedExpectedBytes = signedExpectedBytes
    self.maximumBytes = maximumBytes
  }

  mutating func begin(cancellation: @escaping () -> Void) {
    self.cancellation = cancellation
  }

  mutating func receiveExpectedContentLength(_ length: UInt64) {
    guard length == signedExpectedBytes, length <= maximumBytes else {
      cancel()
      return
    }
  }

  mutating func receiveData(length: UInt64) {
    guard !cancelled else { return }
    let (nextReceivedBytes, overflowed) = receivedBytes.addingReportingOverflow(length)
    guard !overflowed,
      nextReceivedBytes <= signedExpectedBytes,
      nextReceivedBytes <= maximumBytes
    else {
      cancel()
      return
    }
    receivedBytes = nextReceivedBytes
  }

  private mutating func cancel() {
    guard !cancelled else { return }
    cancelled = true
    let cancellation = self.cancellation
    self.cancellation = nil
    cancellation?()
  }
}

private enum SecureUpdateProofFailure: CaseIterable, Equatable {
  case cancelled
  case diskExhausted
  case interrupted
  case malformedFeed
  case offline
  case signatureRejected
  case timedOut
}

private enum SecureUpdateProofTransactionState: Equatable {
  case checking
  case deferred(candidateBuild: String)
  case downloading(candidateBuild: String)
  case failed(SecureUpdateProofFailure)
  case idle
  case staged(candidateBuild: String)
}

private struct SecureUpdateProofTransaction {
  private(set) var installedBuild: String
  private(set) var stagedBuild: String?
  private(set) var state = SecureUpdateProofTransactionState.idle

  mutating func beginCheck() {
    state = .checking
  }

  mutating func deferUpdate(candidateBuild: String) {
    stagedBuild = nil
    state = .deferred(candidateBuild: candidateBuild)
  }

  mutating func beginDownload(candidateBuild: String) {
    stagedBuild = candidateBuild
    state = .downloading(candidateBuild: candidateBuild)
  }

  mutating func finishDownload() {
    guard let stagedBuild else { return }
    state = .staged(candidateBuild: stagedBuild)
  }

  mutating func commitInstallAfterConfirmation() {
    guard case .staged(let candidateBuild) = state else { return }
    installedBuild = candidateBuild
    stagedBuild = nil
    state = .idle
  }

  mutating func fail(_ failure: SecureUpdateProofFailure) {
    stagedBuild = nil
    state = .failed(failure)
  }
}
