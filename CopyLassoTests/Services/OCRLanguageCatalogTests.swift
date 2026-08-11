import Vision
import XCTest

@testable import CopyLasso

final class OCRLanguageCatalogTests: XCTestCase {
  private enum TestError: Error {
    case injected
  }

  func testCatalogReturnsStableUniqueNonemptyIdentifiers() throws {
    let catalog = VisionOCRLanguageCatalog {
      ["fr-FR", "", "en-US", "fr-FR", "ja-JP"]
    }

    XCTAssertEqual(
      try catalog.supportedLanguageIdentifiers(),
      ["fr-FR", "en-US", "ja-JP"]
    )
  }

  func testCatalogMapsFrameworkFailureToAContentFreeError() {
    let catalog = VisionOCRLanguageCatalog { throw TestError.injected }

    XCTAssertThrowsError(try catalog.supportedLanguageIdentifiers()) { error in
      XCTAssertEqual(error as? OCRLanguageCatalogError, .unavailable)
    }
  }

  func testProductionCatalogUsesAccurateRevisionThreeAndIncludesEnglish() throws {
    let identifiers = try VisionOCRLanguageCatalog().supportedLanguageIdentifiers()

    XCTAssertFalse(identifiers.isEmpty)
    XCTAssertTrue(identifiers.contains("en-US"))

    let request = VNRecognizeTextRequest()
    request.revision = VNRecognizeTextRequestRevision3
    request.recognitionLevel = .accurate
    XCTAssertEqual(Set(identifiers), Set(try request.supportedRecognitionLanguages()))
  }
}
