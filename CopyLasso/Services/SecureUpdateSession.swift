import Foundation

enum SecureUpdateSessionDisposition: Equatable, Sendable {
  case dismiss
  case install
}

enum SecureUpdateResumeStage: Equatable, Sendable {
  case notDownloaded
  case downloaded
  case installing
}

@MainActor
final class SecureUpdateSessionCoordinator {
  private let installedBuild: String
  private let stateStore: any SecureUpdateStateStoring
  private let policy: SecureUpdatePolicy
  private let presenter: any SecureUpdatePresenting

  private var activeCandidate: SecureUpdateCandidate?
  private var downloadBudget: SecureUpdateDownloadBudget?
  private var isResumingDownloadedUpdate = false

  init(
    installedBuild: String,
    stateStore: any SecureUpdateStateStoring,
    policy: SecureUpdatePolicy,
    presenter: any SecureUpdatePresenting
  ) {
    self.installedBuild = installedBuild
    self.stateStore = stateStore
    self.policy = policy
    self.presenter = presenter
  }

  func present(
    _ candidate: SecureUpdateCandidate,
    stage: SecureUpdateResumeStage = .notDownloaded,
    reply: @escaping (SecureUpdateSessionDisposition) -> Void
  ) {
    switch policy.decision(
      for: candidate,
      installedBuild: installedBuild,
      highestAuthenticatedBuild: stateStore.highestAuthenticatedBuild
    ) {
    case .offer:
      stateStore.highestAuthenticatedBuild = candidate.build
      activeCandidate = candidate
      switch stage {
      case .notDownloaded:
        showUpdateAvailable(candidate, reply: reply)
      case .downloaded:
        isResumingDownloadedUpdate = true
        stateStore.deferredBuild = nil
        reply(.install)
      case .installing:
        isResumingDownloadedUpdate = true
        presenter.showReadyToInstall { [weak self] choice in
          guard let self else {
            reply(.dismiss)
            return
          }
          if choice == .proceed {
            self.stateStore.deferredBuild = nil
            reply(.install)
          } else {
            self.stateStore.deferredBuild = candidate.build
            self.activeCandidate = nil
            self.isResumingDownloadedUpdate = false
            reply(.dismiss)
          }
        }
      }
    case .noUpdate(let seedHighWaterBuild):
      if let seedHighWaterBuild {
        stateStore.highestAuthenticatedBuild = seedHighWaterBuild
      }
      presenter.showNoUpdate {
        reply(.dismiss)
      }
    case .reject:
      presenter.showError {
        reply(.dismiss)
      }
    }
  }

  func beginDownload(cancellation: @escaping () -> Void) {
    guard let activeCandidate else {
      cancellation()
      presenter.showError {}
      return
    }
    var budget = SecureUpdateDownloadBudget(
      signedBytes: activeCandidate.contentLength,
      maximumBytes: policy.maximumDownloadBytes
    )
    budget.begin(cancellation: cancellation)
    downloadBudget = budget
    showDownloadProgress()
  }

  func receiveExpectedContentLength(_ expectedContentLength: UInt64) {
    guard var budget = downloadBudget else {
      return
    }
    budget.receiveExpectedContentLength(expectedContentLength)
    downloadBudget = budget
    handleDownloadProgress()
  }

  func receiveData(ofLength length: UInt64) {
    guard var budget = downloadBudget else {
      return
    }
    budget.receiveData(length: length)
    downloadBudget = budget
    handleDownloadProgress()
  }

  func beginExtraction() {
    guard downloadBudget?.isComplete == true || isResumingDownloadedUpdate else {
      downloadBudget?.cancel()
      failActiveTransaction()
      return
    }
    presenter.showExtracting(progress: 0)
  }

  func showExtractionProgress(_ progress: Double) {
    presenter.showExtracting(progress: progress)
  }

  func readyToInstall(reply: @escaping (SecureUpdateSessionDisposition) -> Void) {
    guard downloadBudget?.isComplete == true || isResumingDownloadedUpdate else {
      presenter.showError {
        reply(.dismiss)
      }
      return
    }
    presenter.showReadyToInstall { choice in
      reply(choice == .proceed ? .install : .dismiss)
    }
  }

  func showInstalling(applicationTerminated: Bool, retry: @escaping () -> Void) {
    presenter.showInstalling(
      applicationTerminated: applicationTerminated,
      retry: retry
    )
  }

  func finishInstalled(relaunched: Bool, acknowledgement: @escaping () -> Void) {
    activeCandidate = nil
    downloadBudget = nil
    isResumingDownloadedUpdate = false
    presenter.showInstalled(relaunched: relaunched, acknowledgement: acknowledgement)
  }

  func fail(acknowledgement: @escaping () -> Void) {
    activeCandidate = nil
    downloadBudget = nil
    isResumingDownloadedUpdate = false
    presenter.showError(acknowledgement: acknowledgement)
  }

  func dismiss() {
    activeCandidate = nil
    downloadBudget = nil
    isResumingDownloadedUpdate = false
    presenter.dismiss()
  }

  func focus() {
    presenter.focus()
  }

  private func handleDownloadProgress() {
    guard downloadBudget?.isCancelled == false else {
      failActiveTransaction()
      return
    }
    showDownloadProgress()
  }

  private func showDownloadProgress() {
    guard let activeCandidate, let downloadBudget else {
      return
    }
    presenter.showDownloading(
      receivedBytes: downloadBudget.receivedBytes,
      totalBytes: activeCandidate.contentLength
    ) { [weak self] in
      self?.downloadBudget?.cancel()
      self?.activeCandidate = nil
      self?.downloadBudget = nil
    }
  }

  private func failActiveTransaction() {
    activeCandidate = nil
    downloadBudget = nil
    isResumingDownloadedUpdate = false
    presenter.showError {}
  }

  private func showUpdateAvailable(
    _ candidate: SecureUpdateCandidate,
    reply: @escaping (SecureUpdateSessionDisposition) -> Void
  ) {
    presenter.showUpdateAvailable(
      SecureUpdateOffer(
        displayVersion: candidate.displayVersion,
        build: candidate.build,
        releaseNotes: candidate.releaseNotes.plainText ?? "",
        contentLength: candidate.contentLength
      )
    ) { [weak self] choice in
      guard let self else {
        reply(.dismiss)
        return
      }
      switch choice {
      case .proceed:
        self.stateStore.deferredBuild = nil
        reply(.install)
      case .later:
        self.stateStore.deferredBuild = candidate.build
        self.activeCandidate = nil
        reply(.dismiss)
      }
    }
  }
}

extension SecureUpdateReleaseNotes {
  var plainText: String? {
    guard case .inlinePlainText(let text) = self else {
      return nil
    }
    return text
  }
}
