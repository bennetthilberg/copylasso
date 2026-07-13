import AppKit
import Observation
import SwiftUI

struct PermissionRecoveryContent: Equatable {
  static let instructions =
    "Open System Settings > Privacy & Security > Screen & System Audio Recording and enable "
    + "CopyLasso. If macOS asks, choose Quit & Reopen. Otherwise return here and choose Try "
    + "Again."

  let title = "Screen Recording Access Needed"
  let status: String
  let instructions = Self.instructions

  init(observation: ScreenCaptureAuthorizationObservation) {
    switch observation {
    case .granted:
      status = "Screen Recording access is available."
    case .notGrantedNeverRequested:
      status = "Screen Recording access is not available yet."
    case .notGrantedAfterRequest:
      status =
        "macOS does not tell CopyLasso whether access was denied or is still awaiting approval."
    case .notGrantedAfterPreviouslyGranted:
      status = "Screen Recording access was available before and may have been turned off."
    }
  }
}

@MainActor
@Observable
final class PermissionRecoveryModel {
  private(set) var observation: ScreenCaptureAuthorizationObservation?
  private(set) var settingsOpenFailed = false
  private(set) var isPresented = false
  private(set) var retryStatus: String?
  private var isRetrying = false

  var content: PermissionRecoveryContent? {
    observation.map(PermissionRecoveryContent.init)
  }

  func present(_ observation: ScreenCaptureAuthorizationObservation) {
    self.observation = observation
    settingsOpenFailed = false
    if isRetrying {
      retryStatus =
        "Access is still unavailable. If you chose Later, quit and reopen CopyLasso, then "
        + "choose Try Again."
    } else {
      retryStatus = nil
    }
    isRetrying = false
    isPresented = true
  }

  func recordSettingsOpenResult(_ succeeded: Bool) {
    settingsOpenFailed = !succeeded
  }

  func beginRetry() {
    isRetrying = true
    retryStatus = "Checking Screen Recording access…"
  }

  func recordRetryRejection() {
    isRetrying = false
    retryStatus = "CopyLasso is already checking Screen Recording access."
  }

  func dismiss() {
    isRetrying = false
    retryStatus = nil
    isPresented = false
  }
}

@MainActor
struct PermissionRecoveryPanelActions {
  let openSystemSettings: () -> Void
  let tryAgain: () -> Void
  let cancel: () -> Void
}

@MainActor
protocol PermissionRecoveryPanelHosting: AnyObject {
  func show()
  func hide()
}

@MainActor
final class PermissionRecoveryPanelController: PermissionRecoveryPresenting {
  typealias PanelFactory =
    @MainActor (
      PermissionRecoveryModel,
      PermissionRecoveryPanelActions
    ) -> any PermissionRecoveryPanelHosting

  let model = PermissionRecoveryModel()
  weak var captureRequester: (any CaptureRequesting)?

  private let permissionService: any ScreenCapturePermissionService
  private let makePanel: PanelFactory
  private var panel: (any PermissionRecoveryPanelHosting)?

  init(
    permissionService: any ScreenCapturePermissionService,
    makePanel: @escaping PanelFactory = { model, actions in
      AppKitPermissionRecoveryPanelHost(model: model, actions: actions)
    }
  ) {
    self.permissionService = permissionService
    self.makePanel = makePanel
  }

  func present(_ observation: ScreenCaptureAuthorizationObservation) {
    model.present(observation)
    ensurePanel().show()
  }

  func dismiss() {
    model.dismiss()
    panel?.hide()
  }

  private func ensurePanel() -> any PermissionRecoveryPanelHosting {
    if let panel {
      return panel
    }

    let actions = PermissionRecoveryPanelActions(
      openSystemSettings: { [weak self] in
        guard let self else { return }
        model.recordSettingsOpenResult(permissionService.openSystemSettings())
      },
      tryAgain: { [weak self] in
        guard let self else { return }
        model.beginRetry()
        guard case .transitioned = captureRequester?.perform() else {
          model.recordRetryRejection()
          return
        }
        permissionService.beginUserInitiatedRetry()
      },
      cancel: { [weak self] in
        self?.dismiss()
      }
    )
    let panel = makePanel(model, actions)
    self.panel = panel
    return panel
  }
}

private struct PermissionRecoveryView: View {
  @Bindable var model: PermissionRecoveryModel
  let actions: PermissionRecoveryPanelActions

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      if let content = model.content {
        Text(content.title)
          .font(.title2.weight(.semibold))
          .accessibilityIdentifier("copylasso.permission-recovery.title")

        Text(content.status)
          .lineLimit(nil)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("copylasso.permission-recovery.status")

        Text(content.instructions)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("copylasso.permission-recovery.instructions")
      }

      if model.settingsOpenFailed {
        Text(
          "System Settings could not be opened automatically. Open it manually and go to "
            + "Privacy & Security > Screen & System Audio Recording."
        )
        .foregroundStyle(.red)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("copylasso.permission-recovery.settings-failure")
      }

      if let retryStatus = model.retryStatus {
        Text(retryStatus)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("copylasso.permission-recovery.retry-status")
      }

      HStack {
        Button("Open System Settings", action: actions.openSystemSettings)
          .keyboardShortcut(.defaultAction)
          .accessibilityHint(AccessibilityAuditCopy.openScreenRecordingSettingsHelp)
          .accessibilityIdentifier("copylasso.permission-recovery.open-settings")

        Button("Try Again", action: actions.tryAgain)
          .accessibilityHint(AccessibilityAuditCopy.retryPermissionHelp)
          .accessibilityIdentifier("copylasso.permission-recovery.try-again")

        Spacer()

        Button("Cancel", action: actions.cancel)
          .keyboardShortcut(.cancelAction)
          .accessibilityHint(AccessibilityAuditCopy.cancelPermissionHelp)
          .accessibilityIdentifier("copylasso.permission-recovery.cancel")
      }
    }
    .padding(24)
    .frame(minWidth: 520, idealWidth: 520)
  }
}

@MainActor
private final class AppKitPermissionRecoveryPanelHost: NSObject,
  PermissionRecoveryPanelHosting, NSWindowDelegate
{
  private let panel: NonactivatingPermissionRecoveryPanel
  private let cancel: () -> Void
  private var hasPositionedPanel = false

  init(
    model: PermissionRecoveryModel,
    actions: PermissionRecoveryPanelActions
  ) {
    cancel = actions.cancel
    panel = NonactivatingPermissionRecoveryPanel(
      contentRect: NSRect(x: 0, y: 0, width: 520, height: 280),
      styleMask: [.titled, .closable, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    super.init()

    panel.title = "Screen Recording Access Needed"
    panel.identifier = NSUserInterfaceItemIdentifier("copylasso.permission-recovery.panel")
    panel.becomesKeyOnlyIfNeeded = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    panel.hidesOnDeactivate = false
    panel.isFloatingPanel = true
    panel.isReleasedWhenClosed = false
    panel.level = .floating
    panel.animationBehavior = .none
    panel.contentViewController = NSHostingController(
      rootView: PermissionRecoveryView(model: model, actions: actions)
    )
    panel.delegate = self
  }

  func show() {
    if !hasPositionedPanel {
      panel.center()
      hasPositionedPanel = true
    }
    panel.orderFrontRegardless()
    panel.makeKey()
  }

  func hide() {
    panel.orderOut(nil)
  }

  func windowWillClose(_ notification: Notification) {
    cancel()
  }
}

private final class NonactivatingPermissionRecoveryPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}
