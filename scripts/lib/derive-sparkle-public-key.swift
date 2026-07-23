import CryptoKit
import Foundation

let seed = FileHandle.standardInput.readDataToEndOfFile()
guard seed.count == 32 else {
  exit(64)
}

do {
  let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
  let publicKey = privateKey.publicKey.rawRepresentation.base64EncodedString()
  FileHandle.standardOutput.write(Data(publicKey.utf8))
} catch {
  exit(1)
}
