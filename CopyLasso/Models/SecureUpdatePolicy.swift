import Foundation

enum SecureUpdateReleaseNotes: Equatable, Sendable {
  case external
  case inlineHTML(String)
  case inlinePlainText(String)
  case missing
}

struct SecureUpdateCandidate: Equatable, Sendable {
  var feedAuthenticated: Bool
  var informationOnly: Bool
  var build: String
  var displayVersion: String
  var releaseNotes: SecureUpdateReleaseNotes
  var contentLength: UInt64
  var downloadURL: URL
}

enum SecureUpdateRejection: Equatable, Sendable {
  case downgrade
  case invalidCandidate
  case invalidDownloadLocation
  case invalidDownloadSize
  case invalidFeedSignature
  case invalidReleaseNotes
  case invalidVersion
  case replay
}

enum SecureUpdateDecision: Equatable, Sendable {
  case noUpdate(seedHighWaterBuild: String?)
  case offer
  case reject(SecureUpdateRejection)
}

struct SecureUpdatePolicy: Sendable {
  let maximumDownloadBytes: UInt64

  func decision(
    for candidate: SecureUpdateCandidate,
    installedBuild: String,
    highestAuthenticatedBuild: String?
  ) -> SecureUpdateDecision {
    guard isCanonicalBuild(candidate.build),
      isDisplayVersion(candidate.displayVersion),
      let highWater = initialHighWater(
        installedBuild: installedBuild,
        persistedBuild: highestAuthenticatedBuild
      )
    else {
      return .reject(.invalidVersion)
    }
    guard candidate.feedAuthenticated else {
      return .reject(.invalidFeedSignature)
    }
    guard !candidate.informationOnly else {
      return .reject(.invalidCandidate)
    }
    guard case .inlinePlainText(let notes) = candidate.releaseNotes,
      !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      return .reject(.invalidReleaseNotes)
    }
    guard candidate.contentLength > 0,
      candidate.contentLength <= maximumDownloadBytes
    else {
      return .reject(.invalidDownloadSize)
    }
    guard
      isApprovedDownloadLocation(
        candidate.downloadURL,
        displayVersion: candidate.displayVersion
      )
    else {
      return .reject(.invalidDownloadLocation)
    }

    switch compareCanonicalBuild(candidate.build, installedBuild) {
    case .orderedAscending:
      return .reject(.downgrade)
    case .orderedSame:
      break
    case .orderedDescending:
      break
    }

    if compareCanonicalBuild(candidate.build, highWater) == .orderedAscending {
      return .reject(.replay)
    }
    if candidate.build == installedBuild {
      return .noUpdate(
        seedHighWaterBuild: highestAuthenticatedBuild == nil ? installedBuild : nil
      )
    }
    return .offer
  }

  func initialHighWater(installedBuild: String, persistedBuild: String?) -> String? {
    guard isCanonicalBuild(installedBuild) else {
      return nil
    }
    guard let persistedBuild else {
      return installedBuild
    }
    guard isCanonicalBuild(persistedBuild) else {
      return nil
    }
    return persistedBuild
  }

  private func isCanonicalBuild(_ build: String) -> Bool {
    guard (1...18).contains(build.utf8.count),
      build.utf8.first.map({ (49...57).contains($0) }) == true
    else {
      return false
    }
    return build.utf8.allSatisfy { (48...57).contains($0) }
  }

  private func isDisplayVersion(_ version: String) -> Bool {
    guard (1...64).contains(version.utf8.count) else {
      return false
    }
    let components = version.split(separator: ".", omittingEmptySubsequences: false)
    guard !components.isEmpty, components.count <= 4 else {
      return false
    }
    return components.allSatisfy { component in
      guard (1...18).contains(component.utf8.count),
        let first = component.utf8.first,
        component.utf8.allSatisfy({ (48...57).contains($0) })
      else {
        return false
      }
      return component.utf8.count == 1 || first != 48
    }
  }

  private func compareCanonicalBuild(_ lhs: String, _ rhs: String) -> ComparisonResult {
    if lhs.utf8.count != rhs.utf8.count {
      return lhs.utf8.count < rhs.utf8.count ? .orderedAscending : .orderedDescending
    }
    if lhs == rhs {
      return .orderedSame
    }
    return lhs < rhs ? .orderedAscending : .orderedDescending
  }

  private func isApprovedDownloadLocation(_ url: URL, displayVersion: String) -> Bool {
    #if COPYLASSO_PRIVATE_UPDATE_FIXTURE
      if isApprovedPrivateFixtureDownloadLocation(url, displayVersion: displayVersion) {
        return true
      }
    #endif

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
    return url.scheme == "https"
      && url.host == "github.com"
      && url.user == nil
      && url.password == nil
      && url.port == nil
      && url.query == nil
      && url.fragment == nil
      && url.path(percentEncoded: true) == expectedPath
      && url.pathComponents == expectedComponents
  }

  #if COPYLASSO_PRIVATE_UPDATE_FIXTURE
    private func isApprovedPrivateFixtureDownloadLocation(
      _ url: URL,
      displayVersion: String
    ) -> Bool {
      let expectedPath = "/CopyLasso-\(displayVersion).zip"
      return url.scheme == "http"
        && url.host == "127.0.0.1"
        && url.user == nil
        && url.password == nil
        && url.port.map({ (1_024...65_535).contains($0) }) == true
        && url.query == nil
        && url.fragment == nil
        && url.path(percentEncoded: true) == expectedPath
        && url.pathComponents == ["/", "CopyLasso-\(displayVersion).zip"]
    }
  #endif
}

struct SecureUpdateDownloadBudget {
  let signedBytes: UInt64
  let maximumBytes: UInt64

  private(set) var isCancelled = false
  private(set) var receivedBytes: UInt64 = 0
  private var cancellation: (() -> Void)?

  init(signedBytes: UInt64, maximumBytes: UInt64) {
    self.signedBytes = signedBytes
    self.maximumBytes = maximumBytes
  }

  var isComplete: Bool {
    !isCancelled
      && signedBytes > 0
      && signedBytes <= maximumBytes
      && receivedBytes == signedBytes
  }

  mutating func begin(cancellation: @escaping () -> Void) {
    self.cancellation = cancellation
    if signedBytes == 0 || signedBytes > maximumBytes {
      cancel()
    }
  }

  mutating func receiveExpectedContentLength(_ length: UInt64) {
    guard length == signedBytes, length <= maximumBytes else {
      cancel()
      return
    }
  }

  mutating func receiveData(length: UInt64) {
    guard !isCancelled else {
      return
    }
    let (nextBytes, overflowed) = receivedBytes.addingReportingOverflow(length)
    guard !overflowed,
      nextBytes <= signedBytes,
      nextBytes <= maximumBytes
    else {
      cancel()
      return
    }
    receivedBytes = nextBytes
  }

  mutating func cancel() {
    guard !isCancelled else {
      return
    }
    isCancelled = true
    let callback = cancellation
    cancellation = nil
    callback?()
  }
}
