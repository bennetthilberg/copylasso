import AppKit
import KeyboardShortcuts
import SwiftUI

struct OnboardingView: View {
  @Environment(\.dismissWindow) private var dismissWindow

  let settingsController: SettingsController

  @State private var draftShortcut: KeyboardShortcuts.Shortcut? = CaptureShortcutDefaults.suggested
  @State private var launchAtLogin = true
  @State private var didComplete = false

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Welcome to CopyLasso")
          .font(.largeTitle.weight(.semibold))
          .accessibilityIdentifier("copylasso.onboarding.title")
        Text("Copy visible text from anywhere on your screen.")
          .font(.title3)
          .foregroundStyle(.secondary)
      }

      GroupBox {
        VStack(alignment: .leading, spacing: 10) {
          Label("OCR runs locally on this Mac.", systemImage: "lock.shield")
          Text(
            "CopyLasso keeps screen images in memory only while a capture is active. "
              + "Screen Recording access is requested later, only when you start your first capture."
          )
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      Form {
        Section("Capture shortcut") {
          KeyboardShortcuts.Recorder(
            "Capture Text",
            shortcut: $draftShortcut
          )
          .accessibilityLabel(AccessibilityAuditCopy.shortcutRecorderLabel)
          .accessibilityHint(AccessibilityAuditCopy.shortcutRecorderHelp)
          .accessibilityIdentifier("copylasso.onboarding.shortcut")
          Text(
            "Suggested: Control–Shift–Command–2. Clear the recorder to use only the menu command."
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }

        Section("Availability") {
          Toggle("Launch CopyLasso at Login", isOn: $launchAtLogin)
            .accessibilityHint(AccessibilityAuditCopy.launchAtLoginHelp)
            .accessibilityIdentifier("copylasso.onboarding.launch-at-login")
          Text("This choice is applied only after you continue.")
            .font(.caption)
            .foregroundStyle(.secondary)
          LaunchAtLoginStatusView(
            status: settingsController.launchAtLoginStatus,
            issue: settingsController.launchAtLoginIssue,
            openSystemSettings: settingsController.openLoginItemsSettings
          )
        }
      }
      .formStyle(.grouped)

      HStack {
        if settingsController.launchAtLoginIssue != nil {
          Button("Continue Without Launch at Login") {
            finishWithoutLaunchAtLogin()
          }
          .accessibilityIdentifier("copylasso.onboarding.continue-without-login")

          Spacer()

          Button("Retry") {
            retryLaunchAtLogin()
          }
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier("copylasso.onboarding.retry-login")
        } else {
          Spacer()

          Button("Continue") {
            finish()
          }
          .keyboardShortcut(.defaultAction)
          .accessibilityIdentifier("copylasso.onboarding.continue")
        }
      }
    }
    .padding(28)
    .frame(minWidth: 560, idealWidth: 560, minHeight: 620, idealHeight: 620)
    .onAppear {
      prepareForPresentation()
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    {
      _ in
      refreshRecoveryState()
    }
    .onDisappear {
      if !didComplete {
        draftShortcut = settingsController.onboardingShortcutDraft
        launchAtLogin = settingsController.onboardingLaunchAtLoginDraft
        settingsController.onboardingClosed()
      }
    }
  }

  private func finish() {
    attemptCompletion(launchAtLogin: launchAtLogin)
  }

  private func retryLaunchAtLogin() {
    attemptCompletion(launchAtLogin: true)
  }

  private func finishWithoutLaunchAtLogin() {
    guard
      settingsController.continueWithoutLaunchAtLogin(shortcut: draftShortcut) == .completed
    else {
      return
    }
    closeAfterCompletion()
  }

  private func closeAfterCompletion() {
    didComplete = true
    dismissWindow(id: "onboarding")
  }

  private func attemptCompletion(launchAtLogin: Bool) {
    guard
      settingsController.completeOnboarding(
        shortcut: draftShortcut,
        launchAtLogin: launchAtLogin
      ) == .completed
    else {
      self.launchAtLogin = settingsController.isLaunchAtLoginEnabled
      return
    }
    closeAfterCompletion()
  }

  private func refreshRecoveryState() {
    let wasRecovering = settingsController.launchAtLoginIssue != nil
    settingsController.refreshLaunchAtLoginStatus()
    if wasRecovering || settingsController.launchAtLoginIssue != nil {
      launchAtLogin = settingsController.isLaunchAtLoginEnabled
    }
  }

  private func prepareForPresentation() {
    didComplete = false
    settingsController.refreshLaunchAtLoginStatus()
    draftShortcut = settingsController.onboardingShortcutDraft
    launchAtLogin = settingsController.onboardingLaunchAtLoginDraft
    if settingsController.launchAtLoginIssue != nil {
      launchAtLogin = settingsController.isLaunchAtLoginEnabled
    }
  }
}

#Preview {
  OnboardingView(
    settingsController: SettingsController(
      settingsStore: UserDefaultsSettingsStore(),
      launchAtLoginService: SystemLaunchAtLoginService(),
      shortcutStore: KeyboardShortcutsStore()
    )
  )
}
