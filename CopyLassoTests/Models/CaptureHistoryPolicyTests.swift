import Foundation
import XCTest

@testable import CopyLasso

final class CaptureHistoryPolicyTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 2_000_000)

  func testPolicyUsesTheApprovedBounds() {
    XCTAssertEqual(CaptureHistoryPolicy.retentionInterval, 7 * 24 * 60 * 60)
    XCTAssertEqual(CaptureHistoryPolicy.maximumEntryCount, 100)
    XCTAssertEqual(CaptureHistoryPolicy.maximumContentByteCount, 256 * 1_024)
  }

  func testKindsHaveStableUserFacingNamesAndEmptyContentIsRejected() {
    XCTAssertEqual(CaptureHistoryContentKind.text.displayName, "Text")
    XCTAssertEqual(CaptureHistoryContentKind.code.displayName, "Code")
    XCTAssertFalse(CaptureHistoryPolicy.canStore(content: ""))
  }

  func testRetainedEntriesAreNewestFirstAndExpireAtTheExactBoundary() {
    let inside = entry(secondsAgo: CaptureHistoryPolicy.retentionInterval - 1)
    let boundary = entry(secondsAgo: CaptureHistoryPolicy.retentionInterval)
    let newest = entry(secondsAgo: 1)

    XCTAssertEqual(
      CaptureHistoryPolicy.retainedEntries([inside, boundary, newest], now: now),
      [newest, inside]
    )
  }

  func testRetentionKeepsAtMostOneHundredEntriesAndPreservesDuplicates() {
    let entries = (0..<105).map { offset in
      CaptureHistoryEntry(
        id: UUID(),
        capturedAt: now.addingTimeInterval(TimeInterval(-offset)),
        kind: .text,
        content: "same content"
      )
    }

    let retained = CaptureHistoryPolicy.retainedEntries(entries, now: now)

    XCTAssertEqual(retained.count, 100)
    XCTAssertEqual(Set(retained.map(\.id)).count, 100)
    XCTAssertTrue(retained.allSatisfy { $0.content == "same content" })
    XCTAssertEqual(retained.first?.capturedAt, now)
    XCTAssertEqual(retained.last?.capturedAt, now.addingTimeInterval(-99))
  }

  func testEntryContentAcceptsTheLimitAndRejectsTheNextByte() {
    XCTAssertTrue(
      CaptureHistoryPolicy.canStore(content: String(repeating: "a", count: 256 * 1_024))
    )
    XCTAssertFalse(
      CaptureHistoryPolicy.canStore(content: String(repeating: "a", count: 256 * 1_024 + 1))
    )
    XCTAssertTrue(
      CaptureHistoryPolicy.canStore(content: String(repeating: "é", count: 128 * 1_024))
    )
    XCTAssertFalse(
      CaptureHistoryPolicy.canStore(content: String(repeating: "é", count: 128 * 1_024 + 1))
    )
  }

  func testNextExpirationUsesTheOldestRetainedEntry() {
    let older = entry(secondsAgo: 100)
    let newer = entry(secondsAgo: 10)

    XCTAssertEqual(
      CaptureHistoryPolicy.nextExpiration(for: [newer, older]),
      older.capturedAt.addingTimeInterval(CaptureHistoryPolicy.retentionInterval)
    )
    XCTAssertNil(CaptureHistoryPolicy.nextExpiration(for: []))
  }

  func testPruningUsesTheSuppliedClockAndRejectsFutureDatedEntries() {
    let captured = entry(secondsAgo: 60)
    let forward = now.addingTimeInterval(CaptureHistoryPolicy.retentionInterval)
    let backward = now.addingTimeInterval(-CaptureHistoryPolicy.retentionInterval)

    XCTAssertEqual(CaptureHistoryPolicy.retainedEntries([captured], now: forward), [])
    XCTAssertEqual(CaptureHistoryPolicy.retainedEntries([captured], now: backward), [])
  }

  private func entry(secondsAgo: TimeInterval) -> CaptureHistoryEntry {
    CaptureHistoryEntry(
      id: UUID(),
      capturedAt: now.addingTimeInterval(-secondsAgo),
      kind: .text,
      content: "content"
    )
  }
}
