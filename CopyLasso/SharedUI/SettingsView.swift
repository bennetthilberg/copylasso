import AppKit
import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
  @Environment(\.openWindow) private var openWindow

  let settingsController: SettingsController
  let metadata: AboutMetadata

  #if DEBUG
    @State private var isShowingResetConfirmation = false
  #endif

  var body: some View {
    Form {
      Text("CopyLasso Settings")
        .font(.title2.weight(.semibold))
        .accessibilityIdentifier("copylasso.settings.title")

      if settingsController.needsOnboarding {
        Section("Setup") {
          LabeledContent("First-run setup") {
            Button("Finish Setup…") {
              if settingsController.requestOnboardingFromSettings() {
                openWindow(id: "onboarding")
              }
            }
            .accessibilityIdentifier("copylasso.settings.finish-setup")
          }
          Text("Setup will also be offered the next time CopyLasso launches.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Section("Shortcut") {
        KeyboardShortcuts.Recorder(
          "Capture Text",
          shortcut: Binding(
            get: { settingsController.captureShortcut },
            set: { settingsController.setCaptureShortcut($0) }
          )
        )
        .accessibilityLabel(AccessibilityAuditCopy.shortcutRecorderLabel)
        .accessibilityHint(AccessibilityAuditCopy.shortcutRecorderHelp)
        .accessibilityIdentifier("copylasso.settings.shortcut")
        LabeledContent {
          Button("Use Suggested Shortcut") {
            settingsController.useSuggestedCaptureShortcut()
          }
          .accessibilityHint(AccessibilityAuditCopy.suggestedShortcutHelp)
          .accessibilityIdentifier("copylasso.settings.use-suggested-shortcut")
        } label: {
          Text("Default")
        }
        Text("Clear the shortcut to keep Capture Text available only from the menu bar.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section("General") {
        Toggle(
          "Launch CopyLasso at Login",
          isOn: Binding(
            get: { settingsController.isLaunchAtLoginEnabled },
            set: { settingsController.setLaunchAtLoginEnabled($0) }
          )
        )
        .accessibilityHint(AccessibilityAuditCopy.launchAtLoginHelp)
        .accessibilityIdentifier("copylasso.settings.launch-at-login")
        LaunchAtLoginStatusView(
          status: settingsController.launchAtLoginStatus,
          issue: settingsController.launchAtLoginIssue,
          openSystemSettings: settingsController.openLoginItemsSettings
        )
        if settingsController.launchAtLoginStatus == .requiresApproval {
          Button("Remove Pending Login Item", role: .destructive) {
            settingsController.setLaunchAtLoginEnabled(false)
          }
          .accessibilityIdentifier("copylasso.settings.remove-pending-login-item")
        }
      }

      Section("Privacy") {
        Text(
          "Screen captures and recognized text stay local, remain in memory only as long as needed, "
            + "and are never retained as history or sent to a cloud service."
        )
        .fixedSize(horizontal: false, vertical: true)
      }

      Section("CopyLasso") {
        LabeledContent("Version", value: metadata.versionDescription)
        Link("Project Repository", destination: Self.repositoryURL)
        Link("Privacy Policy", destination: Self.privacyURL)
        Link("MIT License", destination: Self.licenseURL)
      }

      #if DEBUG
        Section("Development") {
          Button("Reset Local Development State…", role: .destructive) {
            isShowingResetConfirmation = true
          }
          .accessibilityIdentifier("copylasso.settings.reset-development-state")
          Text("This does not reset Screen Recording permission.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      #endif
    }
    .formStyle(.grouped)
    .padding(16)
    .frame(minWidth: 520, idealWidth: 520, minHeight: 560, idealHeight: 560)
    .accessibilityIdentifier("copylasso.settings.form")
    .onAppear {
      settingsController.refreshLaunchAtLoginStatus()
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    {
      _ in
      settingsController.refreshLaunchAtLoginStatus()
    }
    #if DEBUG
      .alert("Reset Local Development State?", isPresented: $isShowingResetConfirmation) {
        Button("Cancel", role: .cancel) {}
        Button("Reset", role: .destructive) {
          if settingsController.resetLocalDevelopmentState() {
            openWindow(id: "onboarding")
          }
        }
      } message: {
        Text("This unregisters Launch at Login and clears CopyLasso preferences and shortcut data.")
      }
    #endif
  }

  private static let repositoryURL = URL(string: "https://github.com/bennetthilberg/copylasso")!
  private static let privacyURL = URL(
    string: "https://github.com/bennetthilberg/copylasso/blob/main/PRIVACY.md"
  )!
  private static let licenseURL = URL(
    string: "https://github.com/bennetthilberg/copylasso/blob/main/LICENSE"
  )!
}
