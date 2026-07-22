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

  func testUntrustedOrMismatchedCandidatesFailClosed() {
    assertRejected(\.feedAuthenticated, value: false, reason: .invalidFeedSignature)
    assertRejected(\.archiveAuthenticated, value: false, reason: .invalidArchiveSignature)
    assertRejected(\.archiveBuild, value: "4", reason: .versionMismatch)
    assertRejected(\.archiveDisplayVersion, value: "0.2.1", reason: .versionMismatch)
    assertRejected(\.actualDownloadBytes, value: 4_095, reason: .sizeMismatch)
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
    expectedDownloadBytes: 4_096,
    actualDownloadBytes: 4_096,
    downloadURL: URL(
      string:
        "https://github.com/bennetthilberg/copylasso/releases/download/v0.2.0/CopyLasso-0.2.0.dmg"
    )!
  )
}

private enum SecureUpdateProofRejection: Equatable {
  case downgrade
  case invalidArchiveSignature
  case invalidDownloadLocation
  case invalidDownloadSize
  case invalidFeedSignature
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
    highestAuthenticatedBuild: String
  ) -> SecureUpdateProofDecision {
    let comparator = SUStandardVersionComparator.default

    guard isCanonicalBuild(candidate.feedBuild),
      isCanonicalBuild(candidate.archiveBuild),
      isCanonicalBuild(installedBuild),
      isCanonicalBuild(highestAuthenticatedBuild)
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
    if installedComparison == .orderedSame { return .noUpdate }
    if comparator.compareVersion(candidate.feedBuild, toVersion: highestAuthenticatedBuild)
      == .orderedAscending
    {
      return .rejected(.replay)
    }
    return .installAllowed
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
