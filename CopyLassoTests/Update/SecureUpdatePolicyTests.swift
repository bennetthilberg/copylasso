import Foundation
import XCTest

@testable import CopyLasso

final class SecureUpdatePolicyTests: XCTestCase {
  private let policy = SecureUpdatePolicy(maximumDownloadBytes: 256 * 1_024 * 1_024)

  func testAcceptsAuthenticatedStrictlyNewerApprovedCandidate() {
    XCTAssertEqual(
      policy.decision(
        for: .valid,
        installedBuild: "2",
        highestAuthenticatedBuild: "2"
      ),
      .offer
    )
  }

  func testRejectsUnauthenticatedNonInstallableAndMetadataInvalidCandidates() {
    assertRejected(\.feedAuthenticated, false, as: .invalidFeedSignature)
    assertRejected(\.informationOnly, true, as: .invalidCandidate)
    assertRejected(\.build, "03", as: .invalidVersion)
    assertRejected(\.displayVersion, "", as: .invalidVersion)
    assertRejected(\.displayVersion, "0.02.0", as: .invalidVersion)
    assertRejected(\.displayVersion, "1.2.3.4.5", as: .invalidVersion)
    assertRejected(
      \.displayVersion,
      String(repeating: "9", count: 65),
      as: .invalidVersion
    )
    assertRejected(\.contentLength, 0, as: .invalidDownloadSize)
    assertRejected(
      \.contentLength,
      256 * 1_024 * 1_024 + 1,
      as: .invalidDownloadSize
    )
  }

  func testRejectsEveryNonPlainInlineReleaseNotesSource() {
    for notes in [
      SecureUpdateReleaseNotes.missing,
      .external,
      .inlineHTML("<p>Changes</p>"),
      .inlinePlainText(" \n\t "),
    ] {
      assertRejected(\.releaseNotes, notes, as: .invalidReleaseNotes)
    }
  }

  func testRejectsUnapprovedDownloadLocations() {
    let invalidURLs = [
      "http://github.com/bennetthilberg/copylasso/releases/download/v0.2.0/CopyLasso-0.2.0.dmg",
      "https://example.com/bennetthilberg/copylasso/releases/download/v0.2.0/CopyLasso-0.2.0.dmg",
      "https://github.com/bennetthilberg/copylasso/releases/download/v0.2.0/CopyLasso-0.2.1.dmg",
      "https://github.com/bennetthilberg/copylasso/releases/download/v0.2.0%2f../v0.2.0/CopyLasso-0.2.0.dmg",
      "https://github.com:443/bennetthilberg/copylasso/releases/download/v0.2.0/CopyLasso-0.2.0.dmg",
      "https://github.com/bennetthilberg/copylasso/releases/download/v0.2.0/CopyLasso-0.2.0.dmg?download=1",
    ]

    for rawURL in invalidURLs {
      var candidate = SecureUpdateCandidate.valid
      candidate.downloadURL = try! XCTUnwrap(URL(string: rawURL))
      XCTAssertEqual(
        policy.decision(
          for: candidate,
          installedBuild: "2",
          highestAuthenticatedBuild: "2"
        ),
        .reject(.invalidDownloadLocation),
        rawURL
      )
    }
  }

  func testRejectsDowngradeReplayAndMalformedHighWaterState() {
    var downgrade = SecureUpdateCandidate.valid
    downgrade.build = "1"
    XCTAssertEqual(
      policy.decision(for: downgrade, installedBuild: "2", highestAuthenticatedBuild: "2"),
      .reject(.downgrade)
    )

    var replay = SecureUpdateCandidate.valid
    replay.build = "3"
    XCTAssertEqual(
      policy.decision(for: replay, installedBuild: "2", highestAuthenticatedBuild: "4"),
      .reject(.replay)
    )

    XCTAssertEqual(
      policy.decision(
        for: .valid,
        installedBuild: "2",
        highestAuthenticatedBuild: "corrupt"
      ),
      .reject(.invalidVersion)
    )
  }

  func testCurrentBuildIsNoUpdateAndMissingHighWaterSeedsInstalledBuild() {
    var current = SecureUpdateCandidate.valid
    current.build = "2"
    current.displayVersion = "0.1.1"
    current.downloadURL = URL(
      string:
        "https://github.com/bennetthilberg/copylasso/releases/download/v0.1.1/CopyLasso-0.1.1.dmg"
    )!

    XCTAssertEqual(
      policy.decision(for: current, installedBuild: "2", highestAuthenticatedBuild: nil),
      .noUpdate(seedHighWaterBuild: "2")
    )
    XCTAssertEqual(policy.initialHighWater(installedBuild: "2", persistedBuild: nil), "2")
    XCTAssertNil(policy.initialHighWater(installedBuild: "02", persistedBuild: nil))
    XCTAssertNil(policy.initialHighWater(installedBuild: "2", persistedBuild: "bad"))
  }

  func testCurrentBuildBelowAuthenticatedHighWaterIsRejectedAsReplay() {
    var current = SecureUpdateCandidate.valid
    current.build = "2"
    current.displayVersion = "0.1.1"
    current.downloadURL = URL(
      string:
        "https://github.com/bennetthilberg/copylasso/releases/download/v0.1.1/CopyLasso-0.1.1.dmg"
    )!

    XCTAssertEqual(
      policy.decision(for: current, installedBuild: "2", highestAuthenticatedBuild: "3"),
      .reject(.replay)
    )
  }

  private func assertRejected<Value>(
    _ keyPath: WritableKeyPath<SecureUpdateCandidate, Value>,
    _ value: Value,
    as reason: SecureUpdateRejection,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    var candidate = SecureUpdateCandidate.valid
    candidate[keyPath: keyPath] = value
    XCTAssertEqual(
      policy.decision(
        for: candidate,
        installedBuild: "2",
        highestAuthenticatedBuild: "2"
      ),
      .reject(reason),
      file: file,
      line: line
    )
  }
}

extension SecureUpdateCandidate {
  fileprivate static let valid = SecureUpdateCandidate(
    feedAuthenticated: true,
    informationOnly: false,
    build: "3",
    displayVersion: "0.2.0",
    releaseNotes: .inlinePlainText("Security and reliability improvements."),
    contentLength: 4_096,
    downloadURL: URL(
      string:
        "https://github.com/bennetthilberg/copylasso/releases/download/v0.2.0/CopyLasso-0.2.0.dmg"
    )!
  )
}
