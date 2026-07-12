import AppKit
import KeyboardShortcuts
import XCTest

@testable import CopyLasso

@MainActor
final class GlobalShortcutStoreTests: XCTestCase {
  func testSuggestedShortcutIsShiftCommandTwo() {
    XCTAssertEqual(
      CaptureShortcutDefaults.suggested,
      KeyboardShortcuts.Shortcut(.two, modifiers: [.shift, .command])
    )
    XCTAssertEqual(
      CaptureShortcutDefaults.suggestedDescription,
      "Suggested: Shift–Command–2. Clear the recorder to use only the menu command."
    )
  }

  func testShortcutPersistsAcrossStoreReconstructionAndCanBeCleared() {
    let originalShortcut = KeyboardShortcuts.getShortcut(for: .captureText)
    defer {
      KeyboardShortcuts.setShortcut(originalShortcut, for: .captureText)
    }
    let suggested = KeyboardShortcuts.Shortcut(
      .two,
      modifiers: [.shift, .command]
    )

    var store = KeyboardShortcutsStore()
    store.captureShortcut = suggested
    store = KeyboardShortcutsStore()
    XCTAssertEqual(store.captureShortcut, suggested)

    store.reset()
    XCTAssertNil(store.captureShortcut)
  }
}
