import SwiftUI

struct MenuBarMenuView: View {
  @Environment(\.openWindow) private var openWindow

  let commandHandler: MenuBarCommandHandler

  var body: some View {
    Button("Capture Text") {
      commandHandler.captureText()
    }
    .disabled(!commandHandler.isCaptureEnabled)
    .accessibilityIdentifier("copylasso.menu.capture")

    Divider()

    SettingsLink {
      Text("Settings…")
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
