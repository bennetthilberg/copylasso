import Foundation

struct AboutAcknowledgement: Equatable, Sendable {
  let title: String
  let author: String
  let license: String
  let notice: String
}

struct AboutMetadata: Equatable, Sendable {
  let applicationName = "CopyLasso"
  let version: String
  let build: String
  let creatorDescription = "Created by Bennett Hilberg"
  let licenseName = "MIT License"
  let summary = "Free and open source. Private, offline, and local."
  let repositoryURL = URL(string: "https://github.com/bennetthilberg/copylasso")!
  let privacyURL = URL(
    string: "https://github.com/bennetthilberg/copylasso/blob/main/PRIVACY.md"
  )!
  let licenseURL = URL(
    string: "https://github.com/bennetthilberg/copylasso/blob/main/LICENSE"
  )!
  let acknowledgements: [AboutAcknowledgement]

  var versionDescription: String {
    "Version \(version) (\(build))"
  }

  init(infoDictionary: [String: Any]) {
    version = infoDictionary["CFBundleShortVersionString"] as? String ?? "Unknown"
    build = infoDictionary["CFBundleVersion"] as? String ?? "Unknown"
    acknowledgements = Self.makeAcknowledgements(sparkleNotice: nil)
  }

  init(bundle: Bundle) {
    version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    let sparkleNotice = bundle.url(
      forResource: "Sparkle-2.9.4-LICENSE",
      withExtension: "txt"
    ).flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    acknowledgements = Self.makeAcknowledgements(sparkleNotice: sparkleNotice)
  }

  private static func makeAcknowledgements(sparkleNotice: String?) -> [AboutAcknowledgement] {
    [
      AboutAcknowledgement(
        title: "KeyboardShortcuts 3.0.1",
        author: "Sindre Sorhus",
        license: "MIT",
        notice: keyboardShortcutsNotice
      ),
      AboutAcknowledgement(
        title: "Sparkle 2.9.4",
        author: "Sparkle Project contributors",
        license: "BSD-style and bundled third-party licenses",
        notice: sparkleNotice ?? "The complete Sparkle license notice is unavailable."
      ),
    ]
  }

  private static let keyboardShortcutsNotice = """
    MIT License

    Copyright (c) Sindre Sorhus <sindresorhus@gmail.com> (https://sindresorhus.com)

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
    """
}
