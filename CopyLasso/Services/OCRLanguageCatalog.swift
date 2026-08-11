import Foundation
import Vision

enum OCRLanguageCatalogError: Error, Equatable, Sendable {
  case unavailable
}

protocol OCRLanguageCataloging: Sendable {
  func supportedLanguageIdentifiers() throws -> [String]
}

struct VisionOCRLanguageCatalog: OCRLanguageCataloging {
  typealias Loader = @Sendable () throws -> [String]

  private let loader: Loader

  init() {
    loader = {
      let request = VNRecognizeTextRequest()
      request.revision = VNRecognizeTextRequestRevision3
      request.recognitionLevel = .accurate
      return try request.supportedRecognitionLanguages()
    }
  }

  init(loader: @escaping Loader) {
    self.loader = loader
  }

  func supportedLanguageIdentifiers() throws -> [String] {
    do {
      var seen = Set<String>()
      return try loader().filter { identifier in
        !identifier.isEmpty && seen.insert(identifier).inserted
      }
    } catch {
      throw OCRLanguageCatalogError.unavailable
    }
  }
}
