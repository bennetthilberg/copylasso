import XCTest

@testable import CopyLasso

final class OCRRecognitionPreferencesTests: XCTestCase {
  func testEnglishIsTheDefaultAndUsesOneLanguageWithoutAutomaticDetection() {
    let preferences = OCRRecognitionPreferences.englishUS

    XCTAssertEqual(preferences.languageIdentifiers, ["en-US"])
    XCTAssertFalse(preferences.automaticallyDetectsLanguage)
  }

  func testValidationRetainsSupportedIdentifiersInRequestedPriorityOrder() {
    let preferences = OCRRecognitionPreferences.validated(
      requestedLanguageIdentifiers: ["fr-FR", "bogus", "en-US", "fr-FR", "ja-JP"],
      supportedLanguageIdentifiers: ["en-US", "fr-FR", "ja-JP"]
    )

    XCTAssertEqual(preferences.languageIdentifiers, ["fr-FR", "en-US", "ja-JP"])
    XCTAssertTrue(preferences.automaticallyDetectsLanguage)
  }

  func testValidationFallsBackToEnglishThenTheFirstRuntimeLanguage() {
    XCTAssertEqual(
      OCRRecognitionPreferences.validated(
        requestedLanguageIdentifiers: [],
        supportedLanguageIdentifiers: ["fr-FR", "en-US"]
      ),
      .englishUS
    )
    XCTAssertEqual(
      OCRRecognitionPreferences.validated(
        requestedLanguageIdentifiers: ["unsupported"],
        supportedLanguageIdentifiers: ["fr-FR", "de-DE"]
      ).languageIdentifiers,
      ["fr-FR"]
    )
  }

  func testValidationFailsClosedToEnglishWhenTheCatalogIsEmpty() {
    XCTAssertEqual(
      OCRRecognitionPreferences.validated(
        requestedLanguageIdentifiers: ["fr-FR"],
        supportedLanguageIdentifiers: []
      ),
      .englishUS
    )
  }
}
