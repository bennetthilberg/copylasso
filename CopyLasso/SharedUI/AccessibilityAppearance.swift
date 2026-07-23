import AppKit

struct SelectionOutlineStyle: Equatable, Sendable {
  let lineWidth: CGFloat
  let grayWhiteComponent: CGFloat
  let dashLength: CGFloat
  let gapLength: CGFloat
  let cornerRadius: CGFloat
  let phaseDuration: TimeInterval
  let animates: Bool
}

struct SelectionOverlayStyle: Equatable, Sendable {
  let dimOpacity: CGFloat
  let outline: SelectionOutlineStyle
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
    SelectionOverlayStyle(
      dimOpacity: increaseContrast ? 0.28 : 0.18,
      outline: SelectionOutlineStyle(
        lineWidth: increaseContrast ? 1.5 : 1,
        grayWhiteComponent: 0.68,
        dashLength: 6,
        gapLength: 4,
        cornerRadius: 2,
        phaseDuration: 0.6,
        animates: !reduceMotion
      )
    )
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
  static let automaticUpdatesHelp =
    "Choose whether CopyLasso checks its signed update feed about once per day."
  static let checkForUpdatesHelp =
    "Check the signed CopyLasso update feed now."
  static let openScreenRecordingSettingsHelp =
    "Open the Screen Recording privacy pane in System Settings."
  static let retryPermissionHelp =
    "CopyLasso checks again for Screen Recording access only after you choose this button."
  static let cancelPermissionHelp =
    "Close this guidance without changing Screen Recording access."
}
