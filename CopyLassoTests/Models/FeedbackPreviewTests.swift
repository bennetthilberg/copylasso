import XCTest

@testable import CopyLasso

final class FeedbackPreviewTests: XCTestCase {
  func testNormalizesWhitespaceForCompactDisplay() {
    XCTAssertEqual(
      FeedbackPreview(text: "  First\n\tsecond   third  ").text,
      "First second third"
    )
  }

  func testKeepsTextAtTheMaximumCharacterCountWithoutEllipsis() {
    let source = String(repeating: "a", count: FeedbackPreview.maximumCharacterCount)

    XCTAssertEqual(FeedbackPreview(text: source).text, source)
  }

  func testTruncatesByExtendedGraphemeClusterWithoutAddingPunctuation() {
    let prefix = String(repeating: "🙂", count: FeedbackPreview.maximumCharacterCount)
    let preview = FeedbackPreview(text: prefix + "never exposed")

    XCTAssertEqual(preview.text, prefix)
    XCTAssertFalse(preview.text.contains("never exposed"))
  }

  func testEmptyAndWhitespaceOnlyTextRemainEmpty() {
    XCTAssertEqual(FeedbackPreview(text: "").text, "")
    XCTAssertEqual(FeedbackPreview(text: " \n\t ").text, "")
  }
}
