import XCTest

@testable import CopyLasso

final class OCRLanguageSelectionDraftTests: XCTestCase {
  private let options = [
    OCRLanguageOption(identifier: "en-US", displayName: "English (United States)"),
    OCRLanguageOption(identifier: "fr-FR", displayName: "French (France)"),
    OCRLanguageOption(identifier: "ja-JP", displayName: "Japanese (Japan)"),
  ]

  func testSearchFiltersAvailableLanguagesWithoutChangingSelectedPriority() {
    var draft = OCRLanguageSelectionDraft(
      options: options,
      selectedLanguageIdentifiers: ["ja-JP", "en-US"]
    )

    draft.searchText = "fren"

    XCTAssertEqual(draft.selectedOptions.map(\.identifier), ["ja-JP", "en-US"])
    XCTAssertEqual(draft.availableOptions.map(\.identifier), ["fr-FR"])
  }

  func testAddRemoveAndMovePreserveAnExplicitNonemptyPriority() {
    var draft = OCRLanguageSelectionDraft(
      options: options,
      selectedLanguageIdentifiers: ["en-US"]
    )

    XCTAssertTrue(draft.add("fr-FR"))
    XCTAssertTrue(draft.move("fr-FR", by: -1))
    XCTAssertEqual(draft.selectedLanguageIdentifiers, ["fr-FR", "en-US"])
    XCTAssertTrue(draft.remove("en-US"))
    XCTAssertFalse(draft.remove("fr-FR"))
    XCTAssertEqual(draft.selectedLanguageIdentifiers, ["fr-FR"])
  }

  func testUnknownAndDuplicateIdentifiersAreIgnored() {
    var draft = OCRLanguageSelectionDraft(
      options: options,
      selectedLanguageIdentifiers: ["bad", "en-US", "en-US"]
    )

    XCTAssertEqual(draft.selectedLanguageIdentifiers, ["en-US"])
    XCTAssertFalse(draft.add("bad"))
    XCTAssertFalse(draft.add("en-US"))
  }

  func testResetRestoresEnglishAndClearsSearch() {
    var draft = OCRLanguageSelectionDraft(
      options: options,
      selectedLanguageIdentifiers: ["ja-JP", "fr-FR"]
    )
    draft.searchText = "jap"

    draft.resetToEnglish()

    XCTAssertEqual(draft.selectedLanguageIdentifiers, ["en-US"])
    XCTAssertEqual(draft.searchText, "")
  }
}
