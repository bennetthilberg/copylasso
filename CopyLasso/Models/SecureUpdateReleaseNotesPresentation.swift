import Foundation

struct SecureUpdateReleaseNotesPresentation {
  struct Block {
    enum Kind: Equatable {
      case heading(level: Int)
      case paragraph
      case listItem
    }

    let kind: Kind
    let content: AttributedString

    var plainText: String {
      String(content.characters)
    }

    var hasEmphasis: Bool {
      content.runs.contains { run in
        run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true
      }
    }

    var hasLink: Bool {
      content.runs.contains { $0.link != nil }
    }
  }

  let blocks: [Block]

  init(markdown: String) {
    blocks = Self.parse(markdown)
  }

  private static func parse(_ markdown: String) -> [Block] {
    var blocks: [Block] = []
    var pendingKind: Block.Kind?
    var pendingText = ""

    func flush() {
      guard let pendingKind, !pendingText.isEmpty else {
        return
      }
      blocks.append(
        Block(
          kind: pendingKind,
          content: inlineMarkdown(pendingText)
        )
      )
      pendingText = ""
    }

    for rawLine in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
      let line = rawLine.trimmingCharacters(in: .whitespaces)
      guard !line.isEmpty else {
        flush()
        pendingKind = nil
        continue
      }

      if let heading = heading(in: line) {
        flush()
        pendingKind = .heading(level: heading.level)
        pendingText = heading.text
        flush()
        pendingKind = nil
        continue
      }

      if let listItem = listItem(in: line) {
        flush()
        pendingKind = .listItem
        pendingText = listItem
        continue
      }

      if pendingKind == nil {
        pendingKind = .paragraph
      }
      pendingText += pendingText.isEmpty ? line : " \(line)"
    }

    flush()
    return blocks
  }

  private static func heading(in line: String) -> (level: Int, text: String)? {
    let markerCount = line.prefix { $0 == "#" }.count
    guard
      (1...6).contains(markerCount),
      line.dropFirst(markerCount).first == " "
    else {
      return nil
    }
    return (
      markerCount,
      line.dropFirst(markerCount + 1).trimmingCharacters(in: .whitespaces)
    )
  }

  private static func listItem(in line: String) -> String? {
    guard line.hasPrefix("- ") || line.hasPrefix("* ") else {
      return nil
    }
    return String(line.dropFirst(2))
  }

  private static func inlineMarkdown(_ markdown: String) -> AttributedString {
    let options = AttributedString.MarkdownParsingOptions(
      interpretedSyntax: .inlineOnlyPreservingWhitespace,
      failurePolicy: .returnPartiallyParsedIfPossible
    )
    var result =
      (try? AttributedString(markdown: markdown, options: options))
      ?? AttributedString(markdown)
    result.link = nil
    return result
  }
}

enum SecureUpdateOfferLayout {
  static let width: CGFloat = 560
  static let height: CGFloat = 480
  static let releaseNotesHeight: CGFloat = 250
}
