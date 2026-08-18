#if DEBUG
  import Foundation

  actor DebugCaptureHistoryStore: CaptureHistoryStoring {
    private var entries: [CaptureHistoryEntry]
    private let isUnreadable: Bool

    init(arguments: [String], now: Date = Date()) {
      isUnreadable = arguments.contains("--capture-history-unreadable")
      if arguments.contains("--capture-history-populated") {
        entries = [
          CaptureHistoryEntry(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            capturedAt: now.addingTimeInterval(-60),
            kind: .code,
            content: "https://copylasso.com/history-fixture"
          ),
          CaptureHistoryEntry(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            capturedAt: now.addingTimeInterval(-120),
            kind: .text,
            content: "CopyLasso history keeps exact successful output encrypted on this Mac."
          ),
        ]
      } else {
        entries = []
      }
    }

    func prepare() throws {
      if isUnreadable { throw CaptureHistoryStoreError.writeFailed }
    }

    func load(now: Date) throws -> [CaptureHistoryEntry] {
      if isUnreadable { throw CaptureHistoryStoreError.authenticationFailed }
      entries = CaptureHistoryPolicy.retainedEntries(entries, now: now)
      return entries
    }

    func append(
      content: String,
      kind: CaptureHistoryContentKind,
      at date: Date
    ) throws -> CaptureHistoryEntry {
      if isUnreadable { throw CaptureHistoryStoreError.writeFailed }
      let entry = CaptureHistoryEntry(id: UUID(), capturedAt: date, kind: kind, content: content)
      entries = CaptureHistoryPolicy.retainedEntries([entry] + entries, now: date)
      return entry
    }

    func delete(id: UUID, now: Date) throws {
      if isUnreadable { throw CaptureHistoryStoreError.deletionFailed }
      entries = CaptureHistoryPolicy.retainedEntries(
        entries.filter { $0.id != id },
        now: now
      )
    }

    func deleteAll() throws {
      entries = []
    }
  }
#endif
