import Foundation

struct SecureUpdateOffer: Equatable, Sendable {
  let displayVersion: String
  let build: String
  let releaseNotes: String
  let contentLength: UInt64

  var authenticatedSource: String {
    "GitHub Releases (github.com/bennetthilberg/copylasso)"
  }

  var formattedDownloadSize: String {
    ByteCountFormatter.string(fromByteCount: Int64(contentLength), countStyle: .file)
  }
}

enum SecureUpdateConsentChoice: Equatable, Sendable {
  case proceed
  case later
}

@MainActor
protocol SecureUpdatePresenting: AnyObject {
  func showChecking(cancellation: @escaping () -> Void)
  func showUpdateAvailable(
    _ offer: SecureUpdateOffer,
    reply: @escaping (SecureUpdateConsentChoice) -> Void
  )
  func showNoUpdate(acknowledgement: @escaping () -> Void)
  func showError(acknowledgement: @escaping () -> Void)
  func showDownloading(
    receivedBytes: UInt64,
    totalBytes: UInt64,
    cancellation: @escaping () -> Void
  )
  func showExtracting(progress: Double)
  func showReadyToInstall(reply: @escaping (SecureUpdateConsentChoice) -> Void)
  func showInstalling(applicationTerminated: Bool, retry: @escaping () -> Void)
  func showInstalled(relaunched: Bool, acknowledgement: @escaping () -> Void)
  func dismiss()
  func focus()
}
