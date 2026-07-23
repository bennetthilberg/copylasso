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
    let originalCodeShortcut = KeyboardShortcuts.getShortcut(for: .captureCode)
    defer {
      KeyboardShortcuts.setShortcut(originalShortcut, for: .captureText)
      KeyboardShortcuts.setShortcut(originalCodeShortcut, for: .captureCode)
    }
    let suggested = KeyboardShortcuts.Shortcut(
      .two,
      modifiers: [.shift, .command]
    )
    let code = KeyboardShortcuts.Shortcut(
      .eight,
      modifiers: [.option, .command]
    )

    var store = KeyboardShortcutsStore()
    store.captureShortcut = suggested
    store.captureCodeShortcut = code
    store = KeyboardShortcutsStore()
    XCTAssertEqual(store.captureShortcut, suggested)
    XCTAssertEqual(store.captureCodeShortcut, code)

    store.reset()
    XCTAssertNil(store.captureShortcut)
    XCTAssertNil(store.captureCodeShortcut)
  }
}
