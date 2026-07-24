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
      "Suggested: Shift–Command–2."
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

  func testStoreRemovesTheUnreleasedLegacyCodeShortcut() {
    let legacyCodeName = KeyboardShortcuts.Name("captureCode")
    let originalShortcut = KeyboardShortcuts.getShortcut(for: legacyCodeName)
    defer {
      KeyboardShortcuts.setShortcut(originalShortcut, for: legacyCodeName)
    }
    KeyboardShortcuts.setShortcut(
      KeyboardShortcuts.Shortcut(.eight, modifiers: [.option, .command]),
      for: legacyCodeName
    )

    _ = KeyboardShortcutsStore()

    XCTAssertNil(KeyboardShortcuts.getShortcut(for: legacyCodeName))
  }
}
