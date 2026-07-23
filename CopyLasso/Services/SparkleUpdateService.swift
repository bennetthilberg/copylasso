import Foundation
import Sparkle

enum SparkleUpdateConfigurationError: LocalizedError {
  case invalidInstalledBuild
  case updaterRejectedConfiguration

  var errorDescription: String? {
    switch self {
    case .invalidInstalledBuild:
      "The installed CopyLasso build cannot initialize secure update state."
    case .updaterRejectedConfiguration:
      "CopyLasso's secure updater configuration is unavailable."
    }
  }
}

@MainActor
final class SparkleUpdateService: UpdateServicing {
  var stateDidChange: (() -> Void)?

  var automaticallyChecksForUpdates: Bool {
    get {
      updater.automaticallyChecksForUpdates
    }
    set {
      updater.automaticallyChecksForUpdates = newValue
      stateDidChange?()
    }
  }

  var canCheckForUpdates: Bool {
    updater.canCheckForUpdates
  }

  private let updater: SPUUpdater
  private let updaterDelegate: CopyLassoSparkleUpdaterDelegate
  private let userDriver: CopyLassoSparkleUserDriver
  private let stateStore: any SecureUpdateStateStoring
  private let policy: SecureUpdatePolicy
  private let installedBuild: String

  init(
    hostBundle: Bundle = .main,
    applicationBundle: Bundle = .main,
    stateStore: any SecureUpdateStateStoring = UserDefaultsSecureUpdateStateStore(),
    presenter: any SecureUpdatePresenting = SystemSecureUpdatePresenter(),
    maximumDownloadBytes: UInt64 = 256 * 1_024 * 1_024
  ) {
    let policy = SecureUpdatePolicy(maximumDownloadBytes: maximumDownloadBytes)
    let installedBuild = hostBundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    let userDriver = CopyLassoSparkleUserDriver(
      installedBuild: installedBuild,
      stateStore: stateStore,
      policy: policy,
      presenter: presenter
    )
    let updaterDelegate = CopyLassoSparkleUpdaterDelegate()
    updater = SPUUpdater(
      hostBundle: hostBundle,
      applicationBundle: applicationBundle,
      userDriver: userDriver,
      delegate: updaterDelegate
    )
    self.stateStore = stateStore
    self.policy = policy
    self.installedBuild = installedBuild
    self.userDriver = userDriver
    self.updaterDelegate = updaterDelegate
    updaterDelegate.stateDidChange = { [weak self] in
      self?.stateDidChange?()
    }
  }

  func start() throws {
    guard
      let initialHighWater = policy.initialHighWater(
        installedBuild: installedBuild,
        persistedBuild: stateStore.highestAuthenticatedBuild
      )
    else {
      throw SparkleUpdateConfigurationError.invalidInstalledBuild
    }
    if stateStore.highestAuthenticatedBuild == nil {
      stateStore.highestAuthenticatedBuild = initialHighWater
    }

    do {
      try updater.start()
    } catch {
      throw SparkleUpdateConfigurationError.updaterRejectedConfiguration
    }
    updater.clearFeedURLFromUserDefaults()
    stateDidChange?()
  }

  func checkForUpdates() {
    updater.checkForUpdates()
    stateDidChange?()
  }
}

@MainActor
private final class CopyLassoSparkleUpdaterDelegate: NSObject, SPUUpdaterDelegate {
  var stateDidChange: (() -> Void)?

  func updater(
    _ updater: SPUUpdater,
    shouldDownloadReleaseNotesForUpdate updateItem: SUAppcastItem
  ) -> Bool {
    false
  }

  func updater(
    _ updater: SPUUpdater,
    willDownloadUpdate item: SUAppcastItem,
    with request: NSMutableURLRequest
  ) {
    request.httpShouldHandleCookies = false
  }

  func updater(
    _ updater: SPUUpdater,
    didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
    error: (any Error)?
  ) {
    stateDidChange?()
  }
}

@MainActor
private final class CopyLassoSparkleUserDriver: NSObject, SPUUserDriver {
  private let presenter: any SecureUpdatePresenting
  private let session: SecureUpdateSessionCoordinator

  init(
    installedBuild: String,
    stateStore: any SecureUpdateStateStoring,
    policy: SecureUpdatePolicy,
    presenter: any SecureUpdatePresenting
  ) {
    self.presenter = presenter
    session = SecureUpdateSessionCoordinator(
      installedBuild: installedBuild,
      stateStore: stateStore,
      policy: policy,
      presenter: presenter
    )
  }

  func show(
    _ request: SPUUpdatePermissionRequest,
    reply: @escaping (SUUpdatePermissionResponse) -> Void
  ) {
    reply(
      SUUpdatePermissionResponse(
        automaticUpdateChecks: true,
        automaticUpdateDownloading: false,
        sendSystemProfile: false
      )
    )
  }

  func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
    presenter.showChecking(cancellation: cancellation)
  }

  func showUpdateFound(
    with appcastItem: SUAppcastItem,
    state: SPUUserUpdateState,
    reply: @escaping (SPUUserUpdateChoice) -> Void
  ) {
    guard let candidate = candidate(from: appcastItem) else {
      presenter.showError {
        reply(.dismiss)
      }
      return
    }

    session.present(candidate, stage: resumeStage(from: state)) { disposition in
      reply(disposition == .install ? .install : .dismiss)
    }
  }

  func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {
    presenter.showError {}
  }

  func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {
    presenter.showError {}
  }

  func showUpdateNotFoundWithError(
    _ error: any Error,
    acknowledgement: @escaping () -> Void
  ) {
    presenter.showNoUpdate(acknowledgement: acknowledgement)
  }

  func showUpdaterError(
    _ error: any Error,
    acknowledgement: @escaping () -> Void
  ) {
    session.fail(acknowledgement: acknowledgement)
  }

  func showDownloadInitiated(cancellation: @escaping () -> Void) {
    session.beginDownload(cancellation: cancellation)
  }

  func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
    session.receiveExpectedContentLength(expectedContentLength)
  }

  func showDownloadDidReceiveData(ofLength length: UInt64) {
    session.receiveData(ofLength: length)
  }

  func showDownloadDidStartExtractingUpdate() {
    session.beginExtraction()
  }

  func showExtractionReceivedProgress(_ progress: Double) {
    session.showExtractionProgress(progress)
  }

  func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
    session.readyToInstall { disposition in
      reply(disposition == .install ? .install : .dismiss)
    }
  }

  func showInstallingUpdate(
    withApplicationTerminated applicationTerminated: Bool,
    retryTerminatingApplication: @escaping () -> Void
  ) {
    session.showInstalling(
      applicationTerminated: applicationTerminated,
      retry: retryTerminatingApplication
    )
  }

  func showUpdateInstalledAndRelaunched(
    _ relaunched: Bool,
    acknowledgement: @escaping () -> Void
  ) {
    session.finishInstalled(relaunched: relaunched, acknowledgement: acknowledgement)
  }

  func dismissUpdateInstallation() {
    session.dismiss()
  }

  func showUpdateInFocus() {
    session.focus()
  }

  private func candidate(from item: SUAppcastItem) -> SecureUpdateCandidate? {
    guard let downloadURL = item.fileURL else {
      return nil
    }
    let releaseNotes: SecureUpdateReleaseNotes
    if item.releaseNotesURL != nil || item.fullReleaseNotesURL != nil {
      releaseNotes = .external
    } else if let description = item.itemDescription {
      releaseNotes =
        item.itemDescriptionFormat == "plain-text"
        ? .inlinePlainText(description)
        : .inlineHTML(description)
    } else {
      releaseNotes = .missing
    }

    return SecureUpdateCandidate(
      feedAuthenticated: item.signingValidationStatus == .succeeded,
      informationOnly: item.isInformationOnlyUpdate,
      build: item.versionString,
      displayVersion: item.displayVersionString,
      releaseNotes: releaseNotes,
      contentLength: item.contentLength,
      downloadURL: downloadURL
    )
  }

  private func resumeStage(from state: SPUUserUpdateState) -> SecureUpdateResumeStage {
    switch state.stage {
    case .notDownloaded:
      .notDownloaded
    case .downloaded:
      .downloaded
    case .installing:
      .installing
    @unknown default:
      .notDownloaded
    }
  }
}
