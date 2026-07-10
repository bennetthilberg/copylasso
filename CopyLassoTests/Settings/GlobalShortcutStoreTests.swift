import AppKit
import KeyboardShortcuts
import XCTest

@testable import CopyLasso

@MainActor
final class GlobalShortcutStoreTests: XCTestCase {
  func testShortcutPersistsAcrossStoreReconstructionAndCanBeCleared() {
    let originalShortcut = KeyboardShortcuts.getShortcut(for: .captureText)
    defer {
      KeyboardShortcuts.setShortcut(originalShortcut, for: .captureText)
    }
    let suggested = KeyboardShortcuts.Shortcut(
      .two,
      modifiers: [.control, .shift, .command]
    )

    var store = KeyboardShortcutsStore()
    store.captureShortcut = suggested
    store = KeyboardShortcutsStore()
    XCTAssertEqual(store.captureShortcut, suggested)

    store.reset()
    XCTAssertNil(store.captureShortcut)
  }
}
