import CryptoKit
import Foundation

private func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("\(message)\n".utf8))
  exit(1)
}

guard CommandLine.arguments.count == 5 else {
  exit(64)
}

let publicKeyBase64 = CommandLine.arguments[1]
let appcastURL = URL(fileURLWithPath: CommandLine.arguments[2])
let archiveURL = URL(fileURLWithPath: CommandLine.arguments[3])
let enclosureSignatureBase64 = CommandLine.arguments[4]

guard
  let publicKeyData = Data(base64Encoded: publicKeyBase64),
  publicKeyData.count == 32,
  let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
else {
  fail("The shipped Sparkle public key is invalid.")
}

let appcastData: Data
let archiveData: Data
do {
  appcastData = try Data(contentsOf: appcastURL, options: .mappedIfSafe)
  archiveData = try Data(contentsOf: archiveURL, options: .mappedIfSafe)
} catch {
  fail("The signed Sparkle input could not be read.")
}

let signingPrefix = Data("<!-- sparkle-signatures:\n".utf8)
let signingSuffix = Data("-->".utf8)
guard
  let prefixRange = appcastData.range(of: signingPrefix, options: .backwards),
  let suffixRange = appcastData.range(
    of: signingSuffix,
    in: prefixRange.upperBound..<appcastData.endIndex
  )
else {
  fail("The Sparkle appcast signing block is missing.")
}

let signedAppcastContent = Data(appcastData[..<prefixRange.lowerBound])
let signingBlockData = Data(appcastData[prefixRange.upperBound..<suffixRange.lowerBound])
guard let signingBlock = String(data: signingBlockData, encoding: .utf8) else {
  fail("The Sparkle appcast signing block is invalid.")
}

var feedSignatureBase64: String?
var signedLength: Int?
for line in signingBlock.split(whereSeparator: \.isNewline) {
  if line.hasPrefix("edSignature:") {
    guard feedSignatureBase64 == nil else {
      fail("The Sparkle appcast signing block is ambiguous.")
    }
    feedSignatureBase64 = line.dropFirst("edSignature:".count)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  } else if line.hasPrefix("length:") {
    guard signedLength == nil else {
      fail("The Sparkle appcast signing block is ambiguous.")
    }
    signedLength = Int(
      line.dropFirst("length:".count)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    )
  }
}

guard
  let feedSignatureBase64,
  let feedSignature = Data(base64Encoded: feedSignatureBase64),
  feedSignature.count == 64,
  signedLength == signedAppcastContent.count,
  let enclosureSignature = Data(base64Encoded: enclosureSignatureBase64),
  enclosureSignature.count == 64
else {
  fail("The Sparkle signatures or signed length are invalid.")
}

guard
  publicKey.isValidSignature(feedSignature, for: signedAppcastContent),
  publicKey.isValidSignature(enclosureSignature, for: archiveData)
else {
  fail("Sparkle signature verification failed.")
}
