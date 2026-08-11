import Foundation

struct OCRRecognitionPreferences: Equatable, Sendable {
  static let englishUSIdentifier = "en-US"
  static let englishUS = OCRRecognitionPreferences(
    languageIdentifiers: [englishUSIdentifier]
  )

  let languageIdentifiers: [String]

  var automaticallyDetectsLanguage: Bool {
    languageIdentifiers.count > 1
  }

  init(languageIdentifiers: [String]) {
    let identifiers = Self.uniqueNonempty(languageIdentifiers)
    self.languageIdentifiers = identifiers.isEmpty ? [Self.englishUSIdentifier] : identifiers
  }

  static func validated(
    requestedLanguageIdentifiers: [String],
    supportedLanguageIdentifiers: [String]
  ) -> OCRRecognitionPreferences {
    let supportedIdentifiers = uniqueNonempty(supportedLanguageIdentifiers)
    guard !supportedIdentifiers.isEmpty else {
      return .englishUS
    }

    let supported = Set(supportedIdentifiers)
    let requested = uniqueNonempty(requestedLanguageIdentifiers).filter(supported.contains)
    if !requested.isEmpty {
      return OCRRecognitionPreferences(languageIdentifiers: requested)
    }
    if supported.contains(englishUSIdentifier) {
      return .englishUS
    }
    return OCRRecognitionPreferences(languageIdentifiers: [supportedIdentifiers[0]])
  }

  private static func uniqueNonempty(_ identifiers: [String]) -> [String] {
    var seen = Set<String>()
    return identifiers.filter { identifier in
      !identifier.isEmpty && seen.insert(identifier).inserted
    }
  }
}

struct OCRLanguageOption: Identifiable, Equatable, Hashable, Sendable {
  let identifier: String
  let displayName: String

  var id: String { identifier }
}
