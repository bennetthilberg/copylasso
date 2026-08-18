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
        message: "Verifying update information",
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
    let view = SecureUpdateOfferView(
      offer: offer,
      download: {
        NSApp.stopModal(withCode: .OK)
      },
      chooseLater: {
        NSApp.stopModal(withCode: .cancel)
      }
    )
    let hostingController = NSHostingController(rootView: view)
    let panel = NSPanel(contentViewController: hostingController)
    panel.title = "CopyLasso \(offer.displayVersion) Is Available"
    panel.styleMask = [.titled]
    panel.isReleasedWhenClosed = false
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.setAccessibilityIdentifier("copylasso.update.offer")
    let contentSize = NSSize(
      width: SecureUpdateOfferLayout.width,
      height: SecureUpdateOfferLayout.height
    )
    panel.contentMinSize = contentSize
    panel.contentMaxSize = contentSize
    panel.setContentSize(contentSize)
    panel.center()
    activateForUpdateUI()
    panel.makeKeyAndOrderFront(nil)
    let response = NSApp.runModal(for: panel)
    panel.orderOut(nil)
    reply(response == .OK ? .proceed : .later)
  }

  func showNoUpdate(acknowledgement: @escaping () -> Void) {
    showAcknowledgement(
      title: "CopyLasso Is Up to Date",
      message: "You have the latest version of CopyLasso."
    )
    acknowledgement()
  }

  func showError(acknowledgement: @escaping () -> Void) {
    showAcknowledgement(
      title: "Unable to Check for Updates",
      message: "CopyLasso couldn't verify the update. Try again later."
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
        message: "Downloading and verifying the update",
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
        message: "Preparing CopyLasso for installation",
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
      "CopyLasso will quit, install the update, and reopen. "
      + "Choose Later to keep using this version."
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
          ? "Installing the update"
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
        message: "The update is installed. Open CopyLasso to continue."
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

private struct SecureUpdateOfferView: View {
  let offer: SecureUpdateOffer
  let download: () -> Void
  let chooseLater: () -> Void

  private var releaseNotes: SecureUpdateReleaseNotesPresentation {
    SecureUpdateReleaseNotesPresentation(markdown: offer.releaseNotes)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 16) {
        Image(nsImage: NSApp.applicationIconImage)
          .resizable()
          .frame(width: 64, height: 64)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 6) {
          Text("CopyLasso \(offer.displayVersion) Is Available")
            .font(.title2.bold())
            .accessibilityAddTraits(.isHeader)
          Text("Verified source: \(offer.authenticatedSource)")
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("copylasso.update.authenticated-source")
          Text("Download size: \(offer.formattedDownloadSize)")
        }
      }

      Divider()

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 12) {
          ForEach(Array(releaseNotes.blocks.enumerated()), id: \.offset) { _, block in
            SecureUpdateReleaseNotesBlockView(block: block)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 8)
      }
      .frame(height: SecureUpdateOfferLayout.releaseNotesHeight)
      .accessibilityLabel("Release Notes")
      .accessibilityIdentifier("copylasso.update.release-notes")

      Text(
        "CopyLasso will download and verify the update. You'll confirm again before installation."
      )
      .font(.callout)
      .fixedSize(horizontal: false, vertical: true)

      Divider()

      HStack {
        Spacer()
        Button("Later", action: chooseLater)
          .keyboardShortcut(.cancelAction)
          .accessibilityIdentifier("copylasso.update.later")
        Button("Download", action: download)
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier("copylasso.update.download")
      }
    }
    .padding(22)
    .frame(
      width: SecureUpdateOfferLayout.width,
      height: SecureUpdateOfferLayout.height,
      alignment: .top
    )
  }
}

private struct SecureUpdateReleaseNotesBlockView: View {
  let block: SecureUpdateReleaseNotesPresentation.Block

  var body: some View {
    switch block.kind {
    case .heading(let level):
      Text(block.content)
        .font(level == 1 ? .title3.bold() : .headline)
        .accessibilityAddTraits(.isHeader)
    case .paragraph:
      Text(block.content)
        .fixedSize(horizontal: false, vertical: true)
    case .listItem:
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text("•")
          .accessibilityHidden(true)
        Text(block.content)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}
