import AppKit

struct SelectionOverlayStyle: Equatable, Sendable {
  let dimOpacity: CGFloat
  let outerBorderWidth: CGFloat
  let innerBorderWidth: CGFloat
}

enum FeedbackHUDBackgroundStyle: Equatable, Sendable {
  case regularMaterial
  case opaqueWindowBackground
}

struct AccessibilityAppearance: Equatable, Sendable {
  let increaseContrast: Bool
  let differentiateWithoutColor: Bool
  let reduceTransparency: Bool
  let reduceMotion: Bool

  var selectionOverlayStyle: SelectionOverlayStyle {
    if increaseContrast {
      SelectionOverlayStyle(
        dimOpacity: 0.28,
        outerBorderWidth: 5,
        innerBorderWidth: 2
      )
    } else {
      SelectionOverlayStyle(
        dimOpacity: 0.18,
        outerBorderWidth: 3,
        innerBorderWidth: 1
      )
    }
  }

  var feedbackHUDBackgroundStyle: FeedbackHUDBackgroundStyle {
    reduceTransparency ? .opaqueWindowBackground : .regularMaterial
  }
}

@MainActor
protocol AccessibilityAppearanceProviding: AnyObject {
  var currentAppearance: AccessibilityAppearance { get }
}

@MainActor
final class SystemAccessibilityAppearanceProvider: AccessibilityAppearanceProviding {
  private let workspace: NSWorkspace

  init(workspace: NSWorkspace = .shared) {
    self.workspace = workspace
  }

  var currentAppearance: AccessibilityAppearance {
    AccessibilityAppearance(
      increaseContrast: workspace.accessibilityDisplayShouldIncreaseContrast,
      differentiateWithoutColor: workspace.accessibilityDisplayShouldDifferentiateWithoutColor,
      reduceTransparency: workspace.accessibilityDisplayShouldReduceTransparency,
      reduceMotion: workspace.accessibilityDisplayShouldReduceMotion
    )
  }
}

enum FeedbackPanelLayout {
  static let width: CGFloat = 440
  static let minimumHeight: CGFloat = 104

  static func contentHeight(fittingHeight: CGFloat) -> CGFloat {
    max(minimumHeight, fittingHeight.rounded(.up))
  }
}

enum AccessibilityAuditCopy {
  static let menuBarHelp =
    "Open the CopyLasso menu to capture screen text or change settings."
  static let shortcutRecorderLabel = "Capture Text keyboard shortcut"
  static let shortcutRecorderHelp =
    "Record a global keyboard shortcut, or clear it to use only the menu command."
  static let launchAtLoginHelp =
    "Choose whether CopyLasso starts automatically when you log in."
  static let suggestedShortcutHelp =
    "Restore the suggested Shift-Command-2 shortcut."
  static let openScreenRecordingSettingsHelp =
    "Open the Screen Recording privacy pane in System Settings."
  static let retryPermissionHelp =
    "CopyLasso checks again for Screen Recording access only after you choose this button."
  static let cancelPermissionHelp =
    "Close this guidance without changing Screen Recording access."
}
