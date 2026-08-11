import AppKit
import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
  @Environment(\.openWindow) private var openWindow

  let settingsController: SettingsController
  let updateController: UpdateController
  @ObservedObject var historyController: CaptureHistoryController
  let metadata: AboutMetadata

  @State private var isShowingOCRLanguageEditor = false

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

      Section("Shortcuts") {
        KeyboardShortcuts.Recorder(
          "Capture",
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
      }

      Section("Recognition") {
        LabeledContent("Text Languages") {
          Button(settingsController.ocrLanguageSummary) {
            isShowingOCRLanguageEditor = true
          }
          .disabled(!settingsController.isOCRLanguageCatalogAvailable)
          .accessibilityLabel("Text languages, \(settingsController.ocrLanguageSummary)")
          .accessibilityHint(AccessibilityAuditCopy.textLanguagesHelp)
          .accessibilityIdentifier("copylasso.settings.text-languages")
        }
        Text(
          settingsController.ocrRecognitionPreferences.automaticallyDetectsLanguage
            ? "Language detection is automatic. Fewer choices generally improve speed and accuracy."
            : "Add languages only when you need them; fewer choices generally improve speed and accuracy."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

        if !settingsController.isOCRLanguageCatalogAvailable {
          Text("Language choices are temporarily unavailable. English remains selected.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("copylasso.settings.text-languages-unavailable")
        }
      }

      Section("General") {
        Toggle(
          "Launch CopyLasso at Login",
          isOn: Binding(
            get: { settingsController.isLaunchAtLoginEnabled },
            set: { settingsController.setLaunchAtLoginEnabled($0) }
          )
        )
        .accessibilityLabel(AccessibilityAuditCopy.launchAtLoginLabel)
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

      Section("Feedback") {
        Toggle(
          "Play Sound After Copying",
          isOn: Binding(
            get: { settingsController.isSuccessSoundEnabled },
            set: { settingsController.setSuccessSoundEnabled($0) }
          )
        )
        .accessibilityHint(AccessibilityAuditCopy.successSoundHelp)
        .accessibilityIdentifier("copylasso.settings.success-sound")
      }

      Section("Updates") {
        Toggle(
          "Automatically Check for Updates",
          isOn: Binding(
            get: { updateController.automaticallyChecksForUpdates },
            set: { updateController.setAutomaticallyChecksForUpdates($0) }
          )
        )
        .accessibilityHint(AccessibilityAuditCopy.automaticUpdatesHelp)
        .accessibilityIdentifier("copylasso.settings.automatic-updates")

        Button("Check for Updates") {
          updateController.checkForUpdates()
        }
        .disabled(!updateController.canCheckForUpdates)
        .accessibilityHint(AccessibilityAuditCopy.checkForUpdatesHelp)
        .accessibilityIdentifier("copylasso.settings.check-for-updates")

        if let availabilityMessage = updateController.availabilityMessage {
          Text(availabilityMessage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("copylasso.settings.update-unavailable")
        }
      }

      Section("Privacy") {
        Toggle(
          "Save Capture History",
          isOn: Binding(
            get: { historyController.isEnabled },
            set: { enabled in
              Task {
                if enabled {
                  _ = await historyController.enable()
                } else {
                  _ = await historyController.requestDisable()
                }
              }
            }
          )
        )
        .accessibilityHint(
          "Saves only successful text and code output encrypted on this Mac for seven days."
        )
        .accessibilityIdentifier("copylasso.settings.capture-history")

        Text("Only successful text and code output is encrypted locally for seven days.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        Button("View History…") {
          openWindow(id: "history")
        }
        .accessibilityIdentifier("copylasso.settings.view-history")

        Text(
          "Screenshots are never saved. Recognition stays local and is never sent to a cloud service."
        )
        .fixedSize(horizontal: false, vertical: true)
      }

      Section("CopyLasso") {
        LabeledContent("Version", value: metadata.versionDescription)
        Link("Project Repository", destination: metadata.repositoryURL)
        Link("Privacy Policy", destination: metadata.privacyURL)
        Link(metadata.licenseName, destination: metadata.licenseURL)
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
    .frame(minWidth: 520, idealWidth: 520, minHeight: 680, idealHeight: 680)
    .accessibilityIdentifier("copylasso.settings.form")
    .sheet(isPresented: $isShowingOCRLanguageEditor) {
      OCRLanguageEditorView(
        options: settingsController.availableOCRLanguages,
        selectedLanguageIdentifiers: settingsController.ocrRecognitionPreferences
          .languageIdentifiers
      ) { identifiers in
        settingsController.setOCRLanguageIdentifiers(identifiers)
      }
    }
    .onAppear {
      settingsController.refreshLaunchAtLoginStatus()
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    {
      _ in
      settingsController.refreshLaunchAtLoginStatus()
    }
    .alert(
      "Turn Off Capture History?",
      isPresented: Binding(
        get: { historyController.requiresDisableConfirmation },
        set: { presented in
          if !presented { historyController.cancelDisable() }
        }
      )
    ) {
      Button("Cancel", role: .cancel) {
        historyController.cancelDisable()
      }
      Button("Delete History and Turn Off", role: .destructive) {
        Task { _ = await historyController.confirmDisable() }
      }
    } message: {
      Text(
        "This removes CopyLasso's active encrypted archive and encryption key. APFS snapshots or external backups may retain prior bytes."
      )
    }
    #if DEBUG
      .alert("Reset Local Development State?", isPresented: $isShowingResetConfirmation) {
        Button("Cancel", role: .cancel) {}
        Button("Reset", role: .destructive) {
          Task {
            if settingsController.resetLocalDevelopmentState() {
              await historyController.resetLocalDevelopmentState()
              openWindow(id: "onboarding")
            }
          }
        }
      } message: {
        Text(
          "This unregisters Launch at Login and clears CopyLasso preferences, shortcut data, and capture history."
        )
      }
    #endif
  }

}
