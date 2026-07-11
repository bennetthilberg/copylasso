import AppKit

enum ClipboardWriteError: Error, Equatable {
  case emptyText
  case writeFailed
}

@MainActor
protocol PasteboardAccessing: AnyObject {
  func replaceWithPlainText(_ text: String) -> Bool
}

@MainActor
protocol ClipboardService: AnyObject {
  func writePlainText(_ text: String) throws
}

@MainActor
final class SystemClipboardService: ClipboardService {
  private let backend: any PasteboardAccessing

  convenience init(pasteboard: NSPasteboard = .general) {
    self.init(backend: AppKitPasteboardBackend(pasteboard: pasteboard))
  }

  init(backend: any PasteboardAccessing) {
    self.backend = backend
  }

  func writePlainText(_ text: String) throws {
    guard !text.isEmpty else {
      throw ClipboardWriteError.emptyText
    }

    guard backend.replaceWithPlainText(text) else {
      throw ClipboardWriteError.writeFailed
    }
  }
}

@MainActor
final class AppKitPasteboardBackend: PasteboardAccessing {
  private let pasteboard: NSPasteboard

  init(pasteboard: NSPasteboard) {
    self.pasteboard = pasteboard
  }

  func replaceWithPlainText(_ text: String) -> Bool {
    let item = NSPasteboardItem()
    guard item.setString(text, forType: .string) else {
      return false
    }
    pasteboard.clearContents()
    return pasteboard.writeObjects([item])
  }
}
