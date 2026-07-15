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
  let copyright = "Copyright © 2026 Bennett Hilberg"
  let licenseName = "MIT License"
  let summary = "Free and open source. Private, offline, and local."
  let repositoryURL = URL(string: "https://github.com/bennetthilberg/copylasso")!
  let privacyURL = URL(
    string: "https://github.com/bennetthilberg/copylasso/blob/main/PRIVACY.md"
  )!
  let licenseURL = URL(
    string: "https://github.com/bennetthilberg/copylasso/blob/main/LICENSE"
  )!
  let acknowledgement = AboutAcknowledgement(
    title: "KeyboardShortcuts 3.0.1",
    author: "Sindre Sorhus",
    license: "MIT",
    notice: Self.keyboardShortcutsNotice
  )

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
