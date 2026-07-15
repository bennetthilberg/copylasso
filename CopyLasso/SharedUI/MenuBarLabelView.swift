import AppKit
import SwiftUI

struct MenuBarLabelView: View {
  @Environment(\.openWindow) private var openWindow

  let settingsController: SettingsController
  let feedbackModel: FeedbackPresentationModel

  var body: some View {
    Group {
      if let content = feedbackModel.content {
        Image(systemName: content.symbolName)
      } else {
        Image("MenuBarLasso")
          .renderingMode(.template)
      }
    }
    .accessibilityLabel(
      feedbackModel.content?.menuBarAccessibilityLabel ?? "CopyLasso"
    )
    .accessibilityHint(AccessibilityAuditCopy.menuBarHelp)
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
