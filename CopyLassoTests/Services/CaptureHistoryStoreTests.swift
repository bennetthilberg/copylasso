import Darwin
import Foundation
import XCTest

@testable import CopyLasso

final class CaptureHistoryStoreTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 2_000_000)

  func testPrepareCreatesAKeyButNoArchive() async throws {
    let context = makeContext()

    try await context.store.prepare()

    XCTAssertNotNil(context.keyStore.key)
    XCTAssertNil(context.fileStore.data)
    XCTAssertEqual(context.keyStore.createCallCount, 1)
  }

  func testAppendEncryptsAllEntryFieldsAndRoundTripsExactly() async throws {
    let context = makeContext()
    try await context.store.prepare()

    let entry = try await context.store.append(
      content: "private captured words\nsecond line",
      kind: .code,
      at: now
    )
    let bytes = try XCTUnwrap(context.fileStore.data)
    let diskText = String(decoding: bytes, as: UTF8.self)

    XCTAssertFalse(diskText.contains("private captured words"))
    XCTAssertFalse(diskText.contains(entry.id.uuidString))
    XCTAssertFalse(diskText.contains("code"))
    let loaded = try await context.store.load(now: now)
    XCTAssertEqual(loaded, [entry])
    XCTAssertTrue(context.fileStore.didRequestBackupExclusion)
    XCTAssertEqual(context.fileStore.requestedPermissions, 0o600)
  }

  func testWrongKeyTamperTruncationAndUnknownVersionFailClosed() async throws {
    let context = makeContext()
    try await context.store.prepare()
    _ = try await context.store.append(content: "secret", kind: .text, at: now)
    let original = try XCTUnwrap(context.fileStore.data)

    context.keyStore.key = Data(repeating: 9, count: 32)
    await assertThrowsCaptureHistoryError(.authenticationFailed) {
      _ = try await context.store.load(now: self.now)
    }
    context.keyStore.key = Data(repeating: 7, count: 32)

    var tampered = original
    tampered[tampered.index(before: tampered.endIndex)] ^= 0xff
    context.fileStore.data = tampered
    await assertThrowsCaptureHistoryError(.authenticationFailed) {
      _ = try await context.store.load(now: self.now)
    }

    context.fileStore.data = Data(original.prefix(5))
    await assertThrowsCaptureHistoryError(.invalidArchive) {
      _ = try await context.store.load(now: self.now)
    }

    var unknown = original
    unknown.replaceSubrange(0..<4, with: Data("CLH9".utf8))
    context.fileStore.data = unknown
    await assertThrowsCaptureHistoryError(.unsupportedVersion) {
      _ = try await context.store.load(now: self.now)
    }
  }

  func testMissingKeyDoesNotOverwriteExistingArchive() async throws {
    let context = makeContext()
    try await context.store.prepare()
    _ = try await context.store.append(content: "secret", kind: .text, at: now)
    let original = context.fileStore.data
    context.keyStore.key = nil

    await assertThrowsCaptureHistoryError(.missingKey) {
      _ = try await context.store.append(content: "replacement", kind: .text, at: self.now)
    }

    XCTAssertEqual(context.fileStore.data, original)
  }

  func testLoadPrunesExpiredEntriesAndAppendEnforcesCountAndDuplicates() async throws {
    let context = makeContext()
    try await context.store.prepare()
    for offset in (0..<102).reversed() {
      _ = try await context.store.append(
        content: "duplicate",
        kind: .text,
        at: now.addingTimeInterval(TimeInterval(-offset))
      )
    }

    let capped = try await context.store.load(now: now)
    XCTAssertEqual(capped.count, 100)

    _ = try await context.store.append(
      content: "expired",
      kind: .text,
      at: now.addingTimeInterval(-CaptureHistoryPolicy.retentionInterval)
    )
    let pruned = try await context.store.load(now: now)
    XCTAssertFalse(pruned.contains { $0.content == "expired" })
  }

  func testOversizedEntryIsRejectedBeforeArchiveMutation() async throws {
    let context = makeContext()
    try await context.store.prepare()
    _ = try await context.store.append(content: "baseline", kind: .text, at: now)
    let original = context.fileStore.data

    await assertThrowsCaptureHistoryError(.contentTooLarge) {
      _ = try await context.store.append(
        content: String(repeating: "a", count: CaptureHistoryPolicy.maximumContentByteCount + 1),
        kind: .text,
        at: self.now
      )
    }

    XCTAssertEqual(context.fileStore.data, original)
  }

  func testDeleteRewritesRemainingEntriesAndDeleteAllRemovesArchiveAndKey() async throws {
    let context = makeContext()
    try await context.store.prepare()
    let first = try await context.store.append(content: "first", kind: .text, at: now)
    let second = try await context.store.append(
      content: "second",
      kind: .code,
      at: now.addingTimeInterval(1)
    )

    try await context.store.delete(id: first.id, now: now.addingTimeInterval(1))
    let remaining = try await context.store.load(now: now.addingTimeInterval(1))
    XCTAssertEqual(remaining, [second])

    try await context.store.deleteAll()
    XCTAssertNil(context.fileStore.data)
    XCTAssertNil(context.keyStore.key)
  }

  func testFailedAtomicReplacementPreservesPriorArchive() async throws {
    let context = makeContext()
    try await context.store.prepare()
    _ = try await context.store.append(content: "first", kind: .text, at: now)
    let original = context.fileStore.data
    context.fileStore.replaceError = TestCaptureHistoryStorageError.injected

    await assertThrowsCaptureHistoryError(.writeFailed) {
      _ = try await context.store.append(
        content: "second",
        kind: .text,
        at: self.now.addingTimeInterval(1)
      )
    }

    XCTAssertEqual(context.fileStore.data, original)
  }

  func testSystemFileStoreAtomicallyReplacesWithRestrictivePermissionsAndBackupExclusion()
    throws
  {
    let fileManager = FileManager.default
    let supportURL = try XCTUnwrap(
      fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    )
    .appendingPathComponent("CopyLassoHistoryTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? fileManager.removeItem(at: supportURL) }
    let bundleIdentifier = "io.github.bennetthilberg.copylasso.tests"
    let store = SystemCaptureHistoryFileStore(
      bundleIdentifier: bundleIdentifier,
      applicationSupportURL: supportURL
    )

    try store.replace(with: Data("first".utf8), permissions: 0o600, excludeFromBackup: true)
    try store.replace(with: Data("second".utf8), permissions: 0o600, excludeFromBackup: true)

    XCTAssertEqual(try store.read(), Data("second".utf8))
    let archiveURL =
      supportURL
      .appendingPathComponent(bundleIdentifier, isDirectory: true)
      .appendingPathComponent("CaptureHistory.clh")
    let attributes = try fileManager.attributesOfItem(atPath: archiveURL.path)
    let permissions = try XCTUnwrap(attributes[.posixPermissions] as? NSNumber).intValue
    XCTAssertEqual(permissions & 0o777, 0o600)
    let backupExclusionAttribute = "com.apple.metadata:com_apple_backup_excludeItem"
    let backupExclusionByteCount = archiveURL.path.withCString { path in
      backupExclusionAttribute.withCString { attribute in
        getxattr(path, attribute, nil, 0, 0, 0)
      }
    }
    XCTAssertGreaterThan(backupExclusionByteCount, 0)
    let siblingNames = try fileManager.contentsOfDirectory(
      at: archiveURL.deletingLastPathComponent(),
      includingPropertiesForKeys: nil
    ).map(\.lastPathComponent)
    XCTAssertEqual(siblingNames, ["CaptureHistory.clh"])
  }

  func testSystemFileStoreRemovesAbandonedTemporaryArchivesOnReadWriteAndDelete() throws {
    let fileManager = FileManager.default
    let supportURL = try XCTUnwrap(
      fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    )
    .appendingPathComponent("CopyLassoHistoryCleanupTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? fileManager.removeItem(at: supportURL) }
    let bundleIdentifier = "io.github.bennetthilberg.copylasso.cleanup-tests"
    let store = SystemCaptureHistoryFileStore(
      bundleIdentifier: bundleIdentifier,
      applicationSupportURL: supportURL
    )
    let directory = supportURL.appendingPathComponent(bundleIdentifier, isDirectory: true)
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

    let readOrphan = directory.appendingPathComponent(".CaptureHistory-read")
    try Data("read orphan".utf8).write(to: readOrphan)
    XCTAssertNil(try store.read())
    XCTAssertFalse(fileManager.fileExists(atPath: readOrphan.path))

    let writeOrphan = directory.appendingPathComponent(".CaptureHistory-write")
    try Data("write orphan".utf8).write(to: writeOrphan)
    try store.replace(with: Data("archive".utf8), permissions: 0o600, excludeFromBackup: true)
    XCTAssertFalse(fileManager.fileExists(atPath: writeOrphan.path))

    let deleteOrphan = directory.appendingPathComponent(".CaptureHistory-delete")
    try Data("delete orphan".utf8).write(to: deleteOrphan)
    try store.delete()
    XCTAssertFalse(fileManager.fileExists(atPath: deleteOrphan.path))
  }

  private func makeContext() -> (
    store: EncryptedCaptureHistoryStore,
    keyStore: StubCaptureHistoryKeyStore,
    fileStore: StubCaptureHistoryFileStore
  ) {
    let keyStore = StubCaptureHistoryKeyStore(key: nil)
    let fileStore = StubCaptureHistoryFileStore()
    return (
      EncryptedCaptureHistoryStore(keyStore: keyStore, fileStore: fileStore),
      keyStore,
      fileStore
    )
  }
}

private enum TestCaptureHistoryStorageError: Error {
  case injected
}

private final class StubCaptureHistoryKeyStore: CaptureHistoryKeyStoring, @unchecked Sendable {
  var key: Data?
  private(set) var createCallCount = 0

  init(key: Data?) {
    self.key = key
  }

  func loadKey() throws -> Data? {
    key
  }

  func createKey() throws -> Data {
    createCallCount += 1
    let created = Data(repeating: 7, count: 32)
    key = created
    return created
  }

  func deleteKey() throws {
    key = nil
  }
}

private final class StubCaptureHistoryFileStore: CaptureHistoryFileStoring,
  @unchecked Sendable
{
  var data: Data?
  var replaceError: Error?
  private(set) var didRequestBackupExclusion = false
  private(set) var requestedPermissions: Int?

  func read() throws -> Data? {
    data
  }

  func replace(with data: Data, permissions: Int, excludeFromBackup: Bool) throws {
    if let replaceError {
      throw replaceError
    }
    self.data = data
    requestedPermissions = permissions
    didRequestBackupExclusion = excludeFromBackup
  }

  func delete() throws {
    data = nil
  }
}

private func assertThrowsCaptureHistoryError<T>(
  _ expected: CaptureHistoryStoreError,
  operation: () async throws -> T,
  file: StaticString = #filePath,
  line: UInt = #line
) async {
  do {
    _ = try await operation()
    XCTFail("Expected \(expected)", file: file, line: line)
  } catch let error as CaptureHistoryStoreError {
    XCTAssertEqual(error, expected, file: file, line: line)
  } catch {
    XCTFail("Unexpected error: \(error)", file: file, line: line)
  }
}
