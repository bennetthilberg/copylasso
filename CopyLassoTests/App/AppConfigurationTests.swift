import Foundation
import XCTest

final class AppConfigurationTests: XCTestCase {
  func testAppDeclaresWhyScreenCaptureAccessIsRequired() {
    XCTAssertEqual(
      Bundle.main.object(forInfoDictionaryKey: "NSScreenCaptureUsageDescription") as? String,
      "CopyLasso captures the screen region you select to recognize text locally."
    )
  }
}
