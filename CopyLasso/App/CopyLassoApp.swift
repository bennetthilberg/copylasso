import SwiftUI

@main
@MainActor
struct CopyLassoApp: App {
  private let commandHandler: MenuBarCommandHandler

  init() {
    let coordinator = CaptureCoordinator()
    commandHandler = MenuBarCommandHandler(
      captureCommand: CaptureCommand(coordinator: coordinator),
      applicationTerminator: SystemApplicationTerminator()
    )
  }

  var body: some Scene {
    MenuBarExtra {
      MenuBarMenuView(commandHandler: commandHandler)
    } label: {
      Image(systemName: "viewfinder")
        .accessibilityLabel("CopyLasso")
    }
    .menuBarExtraStyle(.menu)

    Settings {
      SettingsPlaceholderView()
    }
    .defaultSize(width: 420, height: 160)

    Window("About CopyLasso", id: "about") {
      AboutView(metadata: AboutMetadata(bundle: .main))
    }
    .windowResizability(.contentSize)
  }
}
