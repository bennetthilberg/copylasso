import AppKit
import SwiftUI

struct MenuBarLabelView: View {
  @Environment(\.openWindow) private var openWindow

  let settingsController: SettingsController
  let feedbackModel: FeedbackPresentationModel

  var body: some View {
    Image(systemName: feedbackModel.content?.symbolName ?? "viewfinder")
      .accessibilityLabel(
        feedbackModel.content?.menuBarAccessibilityLabel ?? "CopyLasso"
      )
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
