import Foundation

struct OCRLanguageSelectionDraft: Equatable, Sendable {
  let options: [OCRLanguageOption]
  private(set) var selectedLanguageIdentifiers: [String]
  var searchText = ""

  var selectedOptions: [OCRLanguageOption] {
    selectedLanguageIdentifiers.compactMap(option(for:))
  }

  var availableOptions: [OCRLanguageOption] {
    let selected = Set(selectedLanguageIdentifiers)
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    return options.filter { option in
      !selected.contains(option.identifier)
        && (query.isEmpty
          || option.displayName.localizedStandardContains(query)
          || option.identifier.localizedStandardContains(query))
    }
  }

  init(
    options: [OCRLanguageOption],
    selectedLanguageIdentifiers: [String]
  ) {
    self.options = options
    let supported = Set(options.map(\.identifier))
    var seen = Set<String>()
    let selected = selectedLanguageIdentifiers.filter { identifier in
      supported.contains(identifier) && seen.insert(identifier).inserted
    }
    self.selectedLanguageIdentifiers =
      selected.isEmpty
      ? Self.defaultSelection(from: options)
      : selected
  }

  @discardableResult
  mutating func add(_ identifier: String) -> Bool {
    guard option(for: identifier) != nil, !selectedLanguageIdentifiers.contains(identifier) else {
      return false
    }
    selectedLanguageIdentifiers.append(identifier)
    return true
  }

  @discardableResult
  mutating func remove(_ identifier: String) -> Bool {
    guard
      selectedLanguageIdentifiers.count > 1,
      let index = selectedLanguageIdentifiers.firstIndex(of: identifier)
    else {
      return false
    }
    selectedLanguageIdentifiers.remove(at: index)
    return true
  }

  @discardableResult
  mutating func move(_ identifier: String, by offset: Int) -> Bool {
    guard
      let source = selectedLanguageIdentifiers.firstIndex(of: identifier),
      selectedLanguageIdentifiers.indices.contains(source + offset)
    else {
      return false
    }
    selectedLanguageIdentifiers.swapAt(source, source + offset)
    return true
  }

  mutating func resetToEnglish() {
    selectedLanguageIdentifiers = Self.defaultSelection(from: options)
    searchText = ""
  }

  private func option(for identifier: String) -> OCRLanguageOption? {
    options.first(where: { $0.identifier == identifier })
  }

  private static func defaultSelection(from options: [OCRLanguageOption]) -> [String] {
    if options.contains(where: { $0.identifier == OCRRecognitionPreferences.englishUSIdentifier }) {
      return [OCRRecognitionPreferences.englishUSIdentifier]
    }
    return options.first.map { [$0.identifier] } ?? [OCRRecognitionPreferences.englishUSIdentifier]
  }
}
