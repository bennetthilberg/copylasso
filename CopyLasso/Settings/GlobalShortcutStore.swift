import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
  static let captureText = Self("captureText")
}

enum CaptureShortcutDefaults {
  static let suggested = KeyboardShortcuts.Shortcut(
    .two,
    modifiers: [.shift, .command]
  )
  static let suggestedDescription =
    "Suggested: Shift–Command–2."
}

@MainActor
protocol GlobalShortcutStoring: AnyObject {
  var captureShortcut: KeyboardShortcuts.Shortcut? { get set }
  func reset()
}

@MainActor
final class KeyboardShortcutsStore: GlobalShortcutStoring {
  private let legacyCodeShortcutName = KeyboardShortcuts.Name("captureCode")

  init() {
    KeyboardShortcuts.setShortcut(nil, for: legacyCodeShortcutName)
  }

  var captureShortcut: KeyboardShortcuts.Shortcut? {
    get {
      KeyboardShortcuts.getShortcut(for: .captureText)
    }
    set {
      KeyboardShortcuts.setShortcut(newValue, for: .captureText)
    }
  }

  func reset() {
    KeyboardShortcuts.setShortcut(nil, for: .captureText)
    KeyboardShortcuts.setShortcut(nil, for: legacyCodeShortcutName)
  }
}
