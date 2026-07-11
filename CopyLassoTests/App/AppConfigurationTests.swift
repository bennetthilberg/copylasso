import Foundation
import XCTest

final class AppConfigurationTests: XCTestCase {
  func testAppDeclaresWhyScreenCaptureAccessIsRequired() throws {
    let testBundleURL = Bundle(for: Self.self).bundleURL
    let appBundleURL =
      testBundleURL
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let appBundle = try XCTUnwrap(Bundle(url: appBundleURL))

    XCTAssertEqual(appBundleURL.lastPathComponent, "CopyLasso.app")
    XCTAssertEqual(
      appBundle.object(forInfoDictionaryKey: "NSScreenCaptureUsageDescription") as? String,
      "CopyLasso captures the screen region you select to recognize text locally."
    )
  }
}
