import Foundation

enum CaptureHistoryContentKind: String, Codable, CaseIterable, Sendable {
  case text
  case code

  var displayName: String {
    switch self {
    case .text: "Text"
    case .code: "Code"
    }
  }
}

struct CaptureHistoryEntry: Codable, Equatable, Identifiable, Sendable {
  let id: UUID
  let capturedAt: Date
  let kind: CaptureHistoryContentKind
  let content: String
}

enum CaptureHistoryPolicy {
  static let retentionInterval: TimeInterval = 7 * 24 * 60 * 60
  static let maximumEntryCount = 100
  static let maximumContentByteCount = 256 * 1_024

  static func canStore(content: String) -> Bool {
    !content.isEmpty && content.utf8.count <= maximumContentByteCount
  }

  static func retainedEntries(
    _ entries: [CaptureHistoryEntry],
    now: Date
  ) -> [CaptureHistoryEntry] {
    let cutoff = now.addingTimeInterval(-retentionInterval)
    return Array(
      entries
        .filter { $0.capturedAt > cutoff && canStore(content: $0.content) }
        .sorted {
          if $0.capturedAt != $1.capturedAt {
            return $0.capturedAt > $1.capturedAt
          }
          return $0.id.uuidString < $1.id.uuidString
        }
        .prefix(maximumEntryCount)
    )
  }

  static func nextExpiration(for entries: [CaptureHistoryEntry]) -> Date? {
    entries.map(\.capturedAt).min()?.addingTimeInterval(retentionInterval)
  }
}
