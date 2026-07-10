import Foundation

struct AboutMetadata: Equatable, Sendable {
  let version: String
  let build: String

  var versionDescription: String {
    "Version \(version) (\(build))"
  }

  init(infoDictionary: [String: Any]) {
    version = infoDictionary["CFBundleShortVersionString"] as? String ?? "Unknown"
    build = infoDictionary["CFBundleVersion"] as? String ?? "Unknown"
  }

  init(bundle: Bundle) {
    self.init(infoDictionary: bundle.infoDictionary ?? [:])
  }
}
