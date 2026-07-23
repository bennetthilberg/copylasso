import AppKit
import SwiftUI

@MainActor
final class SystemSecureUpdatePresenter: NSObject, SecureUpdatePresenting, NSWindowDelegate {
  private var progressPanel: NSPanel?
  private var hostingController: NSHostingController<SecureUpdateProgressView>?
  private var progressState: SecureUpdateProgressState?
  private var cancellation: (() -> Void)?
  private var progressAction: (() -> Void)?
  private var isDismissingProgrammatically = false

  func showChecking(cancellation: @escaping () -> Void) {
    showProgress(
      SecureUpdateProgressState(
        title: "Checking for Updates",
        message: "Looking for a signed CopyLasso update…",
        fraction: nil,
        canCancel: true,
        actionTitle: nil
      ),
      cancellation: cancellation
    )
  }

  func showUpdateAvailable(
    _ offer: SecureUpdateOffer,
    reply: @escaping (SecureUpdateConsentChoice) -> Void
  ) {
    dismiss()
    let alert = NSAlert()
    alert.messageText = "CopyLasso \(offer.displayVersion) Is Available"
    alert.informativeText =
      "Authenticated source: \(offer.authenticatedSource)\n"
      + "Download size: \(offer.formattedDownloadSize)\n\n"
      + offer.releaseNotes
      + "\n\nCopyLasso will download and verify the update. Installation and relaunch "
      + "require a second confirmation."
    alert.alertStyle = .informational
    let downloadButton = alert.addButton(withTitle: "Download")
    downloadButton.setAccessibilityIdentifier("copylasso.update.download")
    let laterButton = alert.addButton(withTitle: "Later")
    laterButton.keyEquivalent = "\u{1b}"
    laterButton.setAccessibilityIdentifier("copylasso.update.later")
    activateForUpdateUI()
    reply(alert.runModal() == .alertFirstButtonReturn ? .proceed : .later)
  }

  func showNoUpdate(acknowledgement: @escaping () -> Void) {
    showAcknowledgement(
      title: "CopyLasso Is Up to Date",
      message: "You already have the newest authenticated version available."
    )
    acknowledgement()
  }

  func showError(acknowledgement: @escaping () -> Void) {
    showAcknowledgement(
      title: "Unable to Check for Updates",
      message:
        "CopyLasso could not verify an update. The installed app was not changed. Try again later."
    )
    acknowledgement()
  }

  func showDownloading(
    receivedBytes: UInt64,
    totalBytes: UInt64,
    cancellation: @escaping () -> Void
  ) {
    let fraction = totalBytes == 0 ? nil : Double(receivedBytes) / Double(totalBytes)
    showProgress(
      SecureUpdateProgressState(
        title: "Downloading Update",
        message: "Downloading and verifying signed update data…",
        fraction: fraction,
        canCancel: true,
        actionTitle: nil
      ),
      cancellation: cancellation
    )
  }

  func showExtracting(progress: Double) {
    showProgress(
      SecureUpdateProgressState(
        title: "Preparing Update",
        message: "Verifying and preparing CopyLasso for installation…",
        fraction: min(max(progress, 0), 1),
        canCancel: false,
        actionTitle: nil
      ),
      cancellation: nil
    )
  }

  func showReadyToInstall(reply: @escaping (SecureUpdateConsentChoice) -> Void) {
    dismiss()
    let alert = NSAlert()
    alert.messageText = "Ready to Install CopyLasso"
    alert.informativeText =
      "CopyLasso will quit, install the verified update, and relaunch. "
      + "Choose Later to keep using the current version."
    alert.alertStyle = .informational
    let installButton = alert.addButton(withTitle: "Install and Relaunch")
    installButton.setAccessibilityIdentifier("copylasso.update.install-relaunch")
    let laterButton = alert.addButton(withTitle: "Later")
    laterButton.keyEquivalent = "\u{1b}"
    laterButton.setAccessibilityIdentifier("copylasso.update.install-later")
    activateForUpdateUI()
    reply(alert.runModal() == .alertFirstButtonReturn ? .proceed : .later)
  }

  func showInstalling(applicationTerminated: Bool, retry: @escaping () -> Void) {
    showProgress(
      SecureUpdateProgressState(
        title: "Installing Update",
        message: applicationTerminated
          ? "Installing the verified CopyLasso update…"
          : "CopyLasso did not quit. Close any blocking dialog, then try again.",
        fraction: nil,
        canCancel: false,
        actionTitle: applicationTerminated ? nil : "Retry"
      ),
      cancellation: nil,
      action: applicationTerminated ? nil : retry
    )
  }

  func showInstalled(relaunched: Bool, acknowledgement: @escaping () -> Void) {
    dismiss()
    if !relaunched {
      showAcknowledgement(
        title: "Update Installed",
        message: "The verified update was installed. Open CopyLasso again to continue."
      )
    }
    acknowledgement()
  }

  func dismiss() {
    guard let progressPanel else {
      return
    }
    isDismissingProgrammatically = true
    progressPanel.close()
    isDismissingProgrammatically = false
    self.progressPanel = nil
    hostingController = nil
    progressState = nil
    cancellation = nil
    progressAction = nil
  }

  func focus() {
    guard let progressPanel else {
      return
    }
    activateForUpdateUI()
    progressPanel.makeKeyAndOrderFront(nil)
  }

  func windowWillClose(_ notification: Notification) {
    guard !isDismissingProgrammatically else {
      return
    }
    let cancellation = self.cancellation
    progressPanel = nil
    hostingController = nil
    progressState = nil
    self.cancellation = nil
    progressAction = nil
    cancellation?()
  }

  private func showProgress(
    _ state: SecureUpdateProgressState,
    cancellation: (() -> Void)?,
    action: (() -> Void)? = nil
  ) {
    progressState = state
    self.cancellation = cancellation
    progressAction = action
    let view = SecureUpdateProgressView(
      state: state,
      cancel: { [weak self] in
        guard let self else { return }
        let cancellation = self.cancellation
        self.dismiss()
        cancellation?()
      },
      performAction: { [weak self] in
        self?.progressAction?()
      }
    )

    if let hostingController, progressPanel != nil {
      hostingController.rootView = view
      focus()
      return
    }

    let hostingController = NSHostingController(rootView: view)
    let panel = NSPanel(contentViewController: hostingController)
    panel.title = state.title
    panel.styleMask = [.titled, .closable]
    panel.isReleasedWhenClosed = false
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.delegate = self
    panel.setContentSize(NSSize(width: 420, height: 150))
    panel.center()
    self.hostingController = hostingController
    progressPanel = panel
    activateForUpdateUI()
    panel.makeKeyAndOrderFront(nil)
  }

  private func showAcknowledgement(title: String, message: String) {
    dismiss()
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .informational
    alert.addButton(withTitle: "OK")
      .setAccessibilityIdentifier("copylasso.update.acknowledge")
    activateForUpdateUI()
    alert.runModal()
  }

  private func activateForUpdateUI() {
    NSApp.activate(ignoringOtherApps: true)
  }
}

private struct SecureUpdateProgressState {
  let title: String
  let message: String
  let fraction: Double?
  let canCancel: Bool
  let actionTitle: String?
}

private struct SecureUpdateProgressView: View {
  let state: SecureUpdateProgressState
  let cancel: () -> Void
  let performAction: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(state.title)
        .font(.headline)
        .accessibilityIdentifier("copylasso.update.progress-title")
      Text(state.message)
        .fixedSize(horizontal: false, vertical: true)
      if let fraction = state.fraction {
        ProgressView(value: fraction)
          .accessibilityLabel("Update progress")
      } else {
        ProgressView()
          .accessibilityLabel("Update progress")
      }
      if state.canCancel || state.actionTitle != nil {
        HStack {
          Spacer()
          if state.canCancel {
            Button("Cancel", action: cancel)
              .keyboardShortcut(.cancelAction)
              .accessibilityIdentifier("copylasso.update.cancel")
          }
          if let actionTitle = state.actionTitle {
            Button(actionTitle, action: performAction)
              .keyboardShortcut(.defaultAction)
              .accessibilityIdentifier("copylasso.update.retry")
          }
        }
      }
    }
    .padding(20)
    .frame(width: 420)
  }
}
