import AppKit
import SwiftUI

struct MenuBarLabelView: View {
  @Environment(\.openWindow) private var openWindow

  let settingsController: SettingsController

  var body: some View {
    Image(systemName: "viewfinder")
      .accessibilityLabel("CopyLasso")
      .task {
        await Task.yield()
        guard settingsController.takeInitialOnboardingPresentationRequest() else {
          return
        }
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "onboarding")
      }
  }
}
