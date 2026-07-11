import AppKit
import XCTest

@testable import CopyLasso

@MainActor
final class AccessibilityAppearanceTests: XCTestCase {
  func testStandardSelectionStyleRetainsSubtleDimAndTwoToneBorder() {
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
        outerBorderWidth: 3,
        innerBorderWidth: 1
      )
    )
  }

  func testIncreasedContrastStrengthensDimAndBothBorderStrokes() {
    let appearance = AccessibilityAppearance(
      increaseContrast: true,
      differentiateWithoutColor: true,
      reduceTransparency: true,
      reduceMotion: true
    )

    XCTAssertEqual(
      appearance.selectionOverlayStyle,
      SelectionOverlayStyle(
        dimOpacity: 0.28,
        outerBorderWidth: 5,
        innerBorderWidth: 2
      )
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
