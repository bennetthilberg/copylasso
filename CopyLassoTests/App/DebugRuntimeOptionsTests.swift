import XCTest

@testable import CopyLasso

final class DebugRuntimeOptionsTests: XCTestCase {
  func testCaptureServiceSelectionKeepsControlledRunsInMemoryUnlessLiveCaptureIsExplicit() {
    let cases: [([String], Bool)] = [
      ([], false),
      (["--g10-g11-ui-testing"], true),
      (["--g13-live-selection"], true),
      (["--g14-live-capture"], false),
      (["--g10-g11-ui-testing", "--g14-live-capture"], false),
      (["--g13-live-selection", "--g14-live-capture"], false),
    ]

    for (arguments, expected) in cases {
      XCTAssertEqual(
        DebugRuntimeOptions(arguments: arguments).usesDebugCaptureService,
        expected,
        "Unexpected capture service selection for \(arguments)"
      )
    }
  }
}
