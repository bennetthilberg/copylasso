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
    .accessibilityIdentifier("copylasso.menu.capture")

    Button("Check for Updates…") {
      updateController.checkForUpdates()
    }
    .disabled(!updateController.canCheckForUpdates)
    .accessibilityHint(AccessibilityAuditCopy.checkForUpdatesHelp)
    .accessibilityIdentifier("copylasso.menu.check-for-updates")

    Divider()

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
