import CryptoKit
import Foundation
import Security

enum CaptureHistoryStoreError: Error, Equatable, Sendable {
  case missingKey
  case invalidKey
  case invalidArchive
  case unsupportedVersion
  case authenticationFailed
  case contentTooLarge
  case readFailed
  case writeFailed
  case deletionFailed
  case keychainFailed
}

protocol CaptureHistoryKeyStoring: Sendable {
  func loadKey() throws -> Data?
  func createKey() throws -> Data
  func deleteKey() throws
}

protocol CaptureHistoryFileStoring: Sendable {
  func read() throws -> Data?
  func replace(with data: Data, permissions: Int, excludeFromBackup: Bool) throws
  func delete() throws
}

protocol CaptureHistoryStoring: Sendable {
  func prepare() async throws
  func load(now: Date) async throws -> [CaptureHistoryEntry]
  func append(
    content: String,
    kind: CaptureHistoryContentKind,
    at date: Date
  ) async throws -> CaptureHistoryEntry
  func delete(id: UUID, now: Date) async throws
  func deleteAll() async throws
}

actor EncryptedCaptureHistoryStore: CaptureHistoryStoring {
  private struct Archive: Codable {
    let schemaVersion: Int
    let entries: [CaptureHistoryEntry]
  }

  private static let archiveHeader = Data("CLH1".utf8)
  private static let schemaVersion = 1
  private static let encryptionKeyByteCount = 32
  private static let minimumSealedBoxByteCount = 28

  private let keyStore: any CaptureHistoryKeyStoring
  private let fileStore: any CaptureHistoryFileStoring

  init(
    keyStore: any CaptureHistoryKeyStoring,
    fileStore: any CaptureHistoryFileStoring
  ) {
    self.keyStore = keyStore
    self.fileStore = fileStore
  }

  func prepare() throws {
    if let existing = try keyStore.loadKey() {
      guard existing.count == Self.encryptionKeyByteCount else {
        throw CaptureHistoryStoreError.invalidKey
      }
      return
    }
    let created = try keyStore.createKey()
    guard created.count == Self.encryptionKeyByteCount else {
      throw CaptureHistoryStoreError.invalidKey
    }
  }

  func load(now: Date) throws -> [CaptureHistoryEntry] {
    let archive = try readArchive()
    let retained = CaptureHistoryPolicy.retainedEntries(archive.entries, now: now)
    if retained != archive.entries {
      try write(entries: retained)
    }
    return retained
  }

  func append(
    content: String,
    kind: CaptureHistoryContentKind,
    at date: Date
  ) throws -> CaptureHistoryEntry {
    guard CaptureHistoryPolicy.canStore(content: content) else {
      throw CaptureHistoryStoreError.contentTooLarge
    }

    let existing = try readArchive().entries
    try prepare()
    let entry = CaptureHistoryEntry(
      id: UUID(),
      capturedAt: date,
      kind: kind,
      content: content
    )
    let retained = CaptureHistoryPolicy.retainedEntries([entry] + existing, now: date)
    try write(entries: retained)
    return entry
  }

  func delete(id: UUID, now: Date) throws {
    let retained = CaptureHistoryPolicy.retainedEntries(
      try readArchive().entries.filter { $0.id != id },
      now: now
    )
    try write(entries: retained)
  }

  func deleteAll() throws {
    var failed = false
    do {
      try fileStore.delete()
    } catch {
      failed = true
    }
    do {
      try keyStore.deleteKey()
    } catch {
      failed = true
    }
    if failed {
      throw CaptureHistoryStoreError.deletionFailed
    }
  }

  private func readArchive() throws -> Archive {
    let encoded: Data
    do {
      guard let stored = try fileStore.read() else {
        return Archive(schemaVersion: Self.schemaVersion, entries: [])
      }
      encoded = stored
    } catch let error as CaptureHistoryStoreError {
      throw error
    } catch {
      throw CaptureHistoryStoreError.readFailed
    }

    guard
      encoded.count
        >= Self.archiveHeader.count + Self.minimumSealedBoxByteCount
    else {
      throw CaptureHistoryStoreError.invalidArchive
    }
    guard encoded.prefix(Self.archiveHeader.count) == Self.archiveHeader else {
      throw CaptureHistoryStoreError.unsupportedVersion
    }
    guard let keyData = try keyStore.loadKey() else {
      throw CaptureHistoryStoreError.missingKey
    }
    guard keyData.count == Self.encryptionKeyByteCount else {
      throw CaptureHistoryStoreError.invalidKey
    }

    let combined = encoded.dropFirst(Self.archiveHeader.count)
    do {
      let sealedBox = try AES.GCM.SealedBox(combined: combined)
      let cleartext = try AES.GCM.open(
        sealedBox,
        using: SymmetricKey(data: keyData),
        authenticating: Self.archiveHeader
      )
      let archive = try PropertyListDecoder().decode(Archive.self, from: cleartext)
      guard archive.schemaVersion == Self.schemaVersion else {
        throw CaptureHistoryStoreError.unsupportedVersion
      }
      guard archive.entries.allSatisfy({ CaptureHistoryPolicy.canStore(content: $0.content) })
      else {
        throw CaptureHistoryStoreError.invalidArchive
      }
      return archive
    } catch let error as CaptureHistoryStoreError {
      throw error
    } catch is CryptoKitError {
      throw CaptureHistoryStoreError.authenticationFailed
    } catch {
      throw CaptureHistoryStoreError.invalidArchive
    }
  }

  private func write(entries: [CaptureHistoryEntry]) throws {
    guard !entries.isEmpty else {
      do {
        try fileStore.delete()
        return
      } catch {
        throw CaptureHistoryStoreError.deletionFailed
      }
    }
    guard let keyData = try keyStore.loadKey() else {
      throw CaptureHistoryStoreError.missingKey
    }
    guard keyData.count == Self.encryptionKeyByteCount else {
      throw CaptureHistoryStoreError.invalidKey
    }

    do {
      let archive = Archive(schemaVersion: Self.schemaVersion, entries: entries)
      let cleartext = try PropertyListEncoder().encode(archive)
      let box = try AES.GCM.seal(
        cleartext,
        using: SymmetricKey(data: keyData),
        authenticating: Self.archiveHeader
      )
      guard let combined = box.combined else {
        throw CaptureHistoryStoreError.writeFailed
      }
      try fileStore.replace(
        with: Self.archiveHeader + combined,
        permissions: 0o600,
        excludeFromBackup: true
      )
    } catch let error as CaptureHistoryStoreError {
      throw error
    } catch {
      throw CaptureHistoryStoreError.writeFailed
    }
  }
}

final class SystemCaptureHistoryKeyStore: CaptureHistoryKeyStoring, @unchecked Sendable {
  private let service: String
  private let account = "archive-key-v1"

  init(bundleIdentifier: String) {
    service = "\(bundleIdentifier).capture-history"
  }

  func loadKey() throws -> Data? {
    var query = baseQuery
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound {
      return nil
    }
    guard status == errSecSuccess, let data = result as? Data else {
      throw CaptureHistoryStoreError.keychainFailed
    }
    return data
  }

  func createKey() throws -> Data {
    var bytes = [UInt8](repeating: 0, count: 32)
    guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
      throw CaptureHistoryStoreError.keychainFailed
    }
    let key = Data(bytes)
    var query = baseQuery
    query[kSecValueData as String] = key
    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    query[kSecAttrSynchronizable as String] = false
    query[kSecAttrLabel as String] = "CopyLasso Capture History Encryption Key"
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
      throw CaptureHistoryStoreError.keychainFailed
    }
    return key
  }

  func deleteKey() throws {
    let status = SecItemDelete(baseQuery as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw CaptureHistoryStoreError.keychainFailed
    }
  }

  private var baseQuery: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecAttrSynchronizable as String: false,
    ]
  }
}

final class SystemCaptureHistoryFileStore: CaptureHistoryFileStoring, @unchecked Sendable {
  static let maximumArchiveByteCount = 32 * 1_024 * 1_024

  private let fileManager: FileManager
  private let archiveURL: URL

  init(
    bundleIdentifier: String,
    fileManager: FileManager = .default,
    applicationSupportURL: URL? = nil
  ) {
    self.fileManager = fileManager
    let support =
      applicationSupportURL
      ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    archiveURL =
      support
      .appendingPathComponent(bundleIdentifier, isDirectory: true)
      .appendingPathComponent("CaptureHistory.clh", isDirectory: false)
  }

  func read() throws -> Data? {
    guard fileManager.fileExists(atPath: archiveURL.path) else {
      return nil
    }
    do {
      let values = try archiveURL.resourceValues(forKeys: [.fileSizeKey])
      guard let size = values.fileSize, size <= Self.maximumArchiveByteCount else {
        throw CaptureHistoryStoreError.invalidArchive
      }
      return try Data(contentsOf: archiveURL, options: [.mappedIfSafe])
    } catch let error as CaptureHistoryStoreError {
      throw error
    } catch {
      throw CaptureHistoryStoreError.readFailed
    }
  }

  func replace(with data: Data, permissions: Int, excludeFromBackup: Bool) throws {
    guard data.count <= Self.maximumArchiveByteCount else {
      throw CaptureHistoryStoreError.writeFailed
    }
    let directory = archiveURL.deletingLastPathComponent()
    let temporaryURL = directory.appendingPathComponent(".CaptureHistory-\(UUID().uuidString)")
    do {
      try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
      try data.write(to: temporaryURL, options: [.withoutOverwriting])
      try fileManager.setAttributes(
        [.posixPermissions: permissions],
        ofItemAtPath: temporaryURL.path
      )
      if excludeFromBackup {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = temporaryURL
        try mutableURL.setResourceValues(values)
      }
      if fileManager.fileExists(atPath: archiveURL.path) {
        _ = try fileManager.replaceItemAt(
          archiveURL,
          withItemAt: temporaryURL,
          backupItemName: nil,
          options: [.usingNewMetadataOnly]
        )
      } else {
        try fileManager.moveItem(at: temporaryURL, to: archiveURL)
      }
    } catch {
      try? fileManager.removeItem(at: temporaryURL)
      throw CaptureHistoryStoreError.writeFailed
    }
  }

  func delete() throws {
    guard fileManager.fileExists(atPath: archiveURL.path) else {
      return
    }
    do {
      try fileManager.removeItem(at: archiveURL)
    } catch {
      throw CaptureHistoryStoreError.deletionFailed
    }
  }
}
