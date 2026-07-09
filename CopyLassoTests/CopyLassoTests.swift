import XCTest

@testable import CopyLasso

final class CopyLassoTests: XCTestCase {
  func testTargetExecutes() {
    XCTAssertTrue(true)
  }

  func testCIFailureProbeIsDisabled() {
    #if COPYLASSO_CI_FAILURE_PROBE
      XCTFail("Controlled CI failure probe is enabled")
    #else
      XCTAssertTrue(true)
    #endif
  }
}
