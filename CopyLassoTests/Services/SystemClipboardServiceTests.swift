import AppKit
import XCTest

@testable import CopyLasso

@MainActor
final class SystemClipboardServiceTests: XCTestCase {
  func testSuccessfulWriteReplacesContentsExactlyOnceWithPlainText() throws {
    let backend = StubPasteboardBackend(contents: "previous")
    let service = SystemClipboardService(backend: backend)

    try service.writePlainText("copied text")

    XCTAssertEqual(backend.replaceCalls, ["copied text"])
    XCTAssertEqual(backend.contents, "copied text")
  }

  func testRejectedPreparedWriteReportsFailureWithoutRecordingSuccess() {
    let backend = StubPasteboardBackend(contents: "previous")
    backend.replaceSucceeds = false
    let service = SystemClipboardService(backend: backend)

    XCTAssertThrowsError(try service.writePlainText("rejected")) { error in
      XCTAssertEqual(error as? ClipboardWriteError, .writeFailed)
    }
    XCTAssertEqual(backend.replaceCalls, ["rejected"])
    XCTAssertEqual(backend.contents, "previous")
  }

  func testEmptyTextIsRejectedBeforeTouchingThePasteboard() {
    let backend = StubPasteboardBackend(contents: "previous")
    let service = SystemClipboardService(backend: backend)

    XCTAssertThrowsError(try service.writePlainText("")) { error in
      XCTAssertEqual(error as? ClipboardWriteError, .emptyText)
    }
    XCTAssertEqual(backend.replaceCalls, [])
    XCTAssertEqual(backend.contents, "previous")
  }

  func testAppKitBackendWritesOnlyAStringRepresentationToAnIsolatedPasteboard() throws {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("copylasso.g17.\(UUID())"))
    pasteboard.clearContents()
    pasteboard.setString("previous", forType: .string)
    defer { pasteboard.clearContents() }
    let service = SystemClipboardService(pasteboard: pasteboard)
    let changeCount = pasteboard.changeCount

    try service.writePlainText("plain only")

    XCTAssertEqual(pasteboard.changeCount, changeCount + 1)
    XCTAssertEqual(pasteboard.string(forType: .string), "plain only")
    XCTAssertEqual(pasteboard.pasteboardItems?.count, 1)
    XCTAssertEqual(pasteboard.pasteboardItems?.first?.types, [.string])
  }
}

@MainActor
private final class StubPasteboardBackend: PasteboardAccessing {
  var contents: String
  var replaceSucceeds = true
  private(set) var replaceCalls: [String] = []

  init(contents: String) {
    self.contents = contents
  }

  func replaceWithPlainText(_ text: String) -> Bool {
    replaceCalls.append(text)
    if replaceSucceeds {
      contents = text
    }
    return replaceSucceeds
  }
}
