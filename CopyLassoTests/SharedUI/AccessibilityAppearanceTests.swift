import AppKit
import XCTest

@testable import CopyLasso

@MainActor
final class AccessibilityAppearanceTests: XCTestCase {
  func testStandardSelectionStyleUsesSubtleDimAndThinAnimatedGrayDashes() {
    let appearance = AccessibilityAppearance(
      increaseContrast: false,
      differentiateWithoutColor: false,
      reduceTransparency: false,
      reduceMotion: false
    )

    XCTAssertEqual(
      appearance.selectionOverlayStyle,
      SelectionOverlayStyle(
        dimOpacity: 0.18,
        outline: SelectionOutlineStyle(
          lineWidth: 1,
          grayWhiteComponent: 0.68,
          dashLength: 6,
          gapLength: 4,
          cornerRadius: 2,
          phaseDuration: 0.6,
          animates: true
        )
      )
    )
  }

  func testIncreasedContrastStrengthensDimAndSingleOutlineWithoutChangingPattern() {
    let appearance = AccessibilityAppearance(
      increaseContrast: true,
      differentiateWithoutColor: true,
      reduceTransparency: true,
      reduceMotion: false
    )

    XCTAssertEqual(
      appearance.selectionOverlayStyle,
      SelectionOverlayStyle(
        dimOpacity: 0.28,
        outline: SelectionOutlineStyle(
          lineWidth: 1.5,
          grayWhiteComponent: 0.68,
          dashLength: 6,
          gapLength: 4,
          cornerRadius: 2,
          phaseDuration: 0.6,
          animates: true
        )
      )
    )
  }

  func testReduceMotionKeepsTheDashedSelectionOutlineStatic() {
    let appearance = AccessibilityAppearance(
      increaseContrast: false,
      differentiateWithoutColor: false,
      reduceTransparency: false,
      reduceMotion: true
    )

    XCTAssertFalse(appearance.selectionOverlayStyle.outline.animates)
    XCTAssertEqual(appearance.selectionOverlayStyle.outline.dashLength, 6)
    XCTAssertEqual(appearance.selectionOverlayStyle.outline.gapLength, 4)
  }

  func testFeedbackHUDUsesMaterialUnlessReduceTransparencyRequiresOpaqueBackground() {
    let standard = AccessibilityAppearance(
      increaseContrast: false,
      differentiateWithoutColor: false,
      reduceTransparency: false,
      reduceMotion: false
    )
    let reducedTransparency = AccessibilityAppearance(
      increaseContrast: false,
      differentiateWithoutColor: false,
      reduceTransparency: true,
      reduceMotion: false
    )

    XCTAssertEqual(standard.feedbackHUDBackgroundStyle, .regularMaterial)
    XCTAssertEqual(
      reducedTransparency.feedbackHUDBackgroundStyle,
      .opaqueWindowBackground
    )
  }

  func testFeedbackLayoutUsesItsMinimumAndExpandsToFittingHeight() {
    XCTAssertEqual(FeedbackPanelLayout.contentHeight(fittingHeight: 40), 104)
    XCTAssertEqual(FeedbackPanelLayout.contentHeight(fittingHeight: 104), 104)
    XCTAssertEqual(FeedbackPanelLayout.contentHeight(fittingHeight: 196), 196)
  }

  func testCompoundControlAccessibilityCopyIsSpecificAndActionable() {
    XCTAssertEqual(
      AccessibilityAuditCopy.menuBarHelp,
      "Open the CopyLasso menu to capture screen text or change settings."
    )
    XCTAssertEqual(
      AccessibilityAuditCopy.shortcutRecorderLabel,
      "Capture Text keyboard shortcut"
    )
    XCTAssertTrue(AccessibilityAuditCopy.shortcutRecorderHelp.contains("clear"))
    XCTAssertEqual(
      AccessibilityAuditCopy.suggestedShortcutHelp,
      "Restore the suggested Shift-Command-2 shortcut."
    )
    XCTAssertTrue(AccessibilityAuditCopy.launchAtLoginHelp.contains("starts automatically"))
    XCTAssertTrue(
      AccessibilityAuditCopy.openScreenRecordingSettingsHelp.contains("System Settings")
    )
    XCTAssertTrue(AccessibilityAuditCopy.retryPermissionHelp.contains("checks again"))
  }

  func testSystemProviderReadsEverySupportedWorkspaceAccessibilityFlag() {
    let appearance = SystemAccessibilityAppearanceProvider().currentAppearance
    let workspace = NSWorkspace.shared

    XCTAssertEqual(
      appearance.increaseContrast,
      workspace.accessibilityDisplayShouldIncreaseContrast
    )
    XCTAssertEqual(
      appearance.differentiateWithoutColor,
      workspace.accessibilityDisplayShouldDifferentiateWithoutColor
    )
    XCTAssertEqual(
      appearance.reduceTransparency,
      workspace.accessibilityDisplayShouldReduceTransparency
    )
    XCTAssertEqual(appearance.reduceMotion, workspace.accessibilityDisplayShouldReduceMotion)
  }
}
