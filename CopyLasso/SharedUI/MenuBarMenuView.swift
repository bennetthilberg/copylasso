import KeyboardShortcuts
import SwiftUI

struct MenuBarMenuView: View {
  @Environment(\.openSettings) private var openSettings
  @Environment(\.openWindow) private var openWindow

  let commandHandler: MenuBarCommandHandler
  let updateController: UpdateController

  var body: some View {
    Button("Capture Text") {
      commandHandler.captureText()
    }
    .disabled(!commandHandler.isCaptureEnabled)
    .globalKeyboardShortcut(.captureText)
    .accessibilityIdentifier("copylasso.menu.capture")

    Button("Capture Code") {
      commandHandler.captureCode()
    }
    .disabled(!commandHandler.isCaptureEnabled)
    .globalKeyboardShortcut(.captureCode)
    .accessibilityIdentifier("copylasso.menu.capture-code")

    Divider()

    Button("Check for Updates…") {
      updateController.checkForUpdates()
    }
    .disabled(!updateController.canCheckForUpdates)
    .accessibilityHint(AccessibilityAuditCopy.checkForUpdatesHelp)
    .accessibilityIdentifier("copylasso.menu.check-for-updates")

    Button("Settings…") {
      commandHandler.openSettings {
        openSettings()
      }
    }
    .keyboardShortcut(",", modifiers: .command)
    .accessibilityIdentifier("copylasso.menu.settings")

    Button("About CopyLasso") {
      openWindow(id: "about")
    }
    .accessibilityIdentifier("copylasso.menu.about")

    Divider()

    Button("Quit CopyLasso") {
      commandHandler.quit()
    }
    .keyboardShortcut("q", modifiers: .command)
    .accessibilityIdentifier("copylasso.menu.quit")
  }
}
