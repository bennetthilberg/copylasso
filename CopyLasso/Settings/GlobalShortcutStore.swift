import KeyboardShortcuts

extension KeyboardShortcuts.Name {
  static let captureText = Self("captureText")
}

@MainActor
protocol GlobalShortcutStoring: AnyObject {
  var captureShortcut: KeyboardShortcuts.Shortcut? { get set }
  func reset()
}

@MainActor
final class KeyboardShortcutsStore: GlobalShortcutStoring {
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
  }
}
