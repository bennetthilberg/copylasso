import Foundation
import XCTest

@testable import CopyLasso

@MainActor
final class SecureUpdateReleaseNotesPresentationTests: XCTestCase {
  func testLongReleaseNotesBecomeSemanticBlocksWithoutMarkdownMarkers() throws {
    let presentation = SecureUpdateReleaseNotesPresentation(
      markdown: try Self.releaseNotesFixture()
    )

    XCTAssertEqual(presentation.blocks.first?.kind, .heading(level: 1))
    XCTAssertTrue(presentation.blocks.contains { $0.kind == .heading(level: 2) })
    XCTAssertTrue(presentation.blocks.contains { $0.kind == .listItem })

    let renderedText = presentation.blocks.map(\.plainText).joined(separator: "\n")
    XCTAssertTrue(renderedText.contains("CopyLasso 0.3.0"))
    XCTAssertTrue(renderedText.contains("OCR language settings."))
    XCTAssertTrue(renderedText.contains("macOS 14 or later"))
    XCTAssertFalse(renderedText.contains("# CopyLasso"))
    XCTAssertFalse(renderedText.contains("## What Is New"))
    XCTAssertFalse(renderedText.contains("**"))
  }

  func testInlineEmphasisIsRetainedAndLinksAreInert() throws {
    let presentation = SecureUpdateReleaseNotesPresentation(
      markdown: "- **Friendly copy feedback.** Read the [repository](https://example.invalid)."
    )

    let block = try XCTUnwrap(presentation.blocks.first)
    XCTAssertEqual(block.kind, .listItem)
    XCTAssertEqual(block.plainText, "Friendly copy feedback. Read the repository.")
    XCTAssertTrue(block.hasEmphasis)
    XCTAssertFalse(block.hasLink)
  }

  func testWrappedParagraphsAndListItemsAreJoinedWithoutLosingWords() throws {
    let presentation = SecureUpdateReleaseNotesPresentation(
      markdown: """
        A paragraph wraps
        onto another line.

        - A list item wraps
          onto another line.
        """
    )

    XCTAssertEqual(presentation.blocks.count, 2)
    XCTAssertEqual(presentation.blocks[0].kind, .paragraph)
    XCTAssertEqual(presentation.blocks[0].plainText, "A paragraph wraps onto another line.")
    XCTAssertEqual(presentation.blocks[1].kind, .listItem)
    XCTAssertEqual(presentation.blocks[1].plainText, "A list item wraps onto another line.")
  }

  func testOfferLayoutIsBoundedAndLeavesAStableScrollableViewport() {
    XCTAssertLessThanOrEqual(SecureUpdateOfferLayout.width, 600)
    XCTAssertLessThanOrEqual(SecureUpdateOfferLayout.height, 520)
    XCTAssertGreaterThanOrEqual(SecureUpdateOfferLayout.releaseNotesHeight, 200)
    XCTAssertLessThan(
      SecureUpdateOfferLayout.releaseNotesHeight,
      SecureUpdateOfferLayout.height
    )
  }

  private static func releaseNotesFixture() throws -> String {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let data = try Data(
      contentsOf: repositoryRoot.appendingPathComponent(
        "CopyLassoTests/Fixtures/update-release-notes.md"
      )
    )
    return String(decoding: data, as: UTF8.self)
  }
}
