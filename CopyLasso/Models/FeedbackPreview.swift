struct FeedbackPreview: Equatable, Sendable {
  static let maximumCharacterCount = 80

  let text: String

  init(text: String) {
    let normalized = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    guard normalized.count > Self.maximumCharacterCount else {
      self.text = normalized
      return
    }

    self.text = String(normalized.prefix(Self.maximumCharacterCount - 1)) + "…"
  }
}
