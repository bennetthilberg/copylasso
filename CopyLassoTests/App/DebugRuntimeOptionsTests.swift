import XCTest

@testable import CopyLasso

final class DebugRuntimeOptionsTests: XCTestCase {
  func testCaptureServiceSelectionKeepsControlledRunsInMemoryUnlessLiveCaptureIsExplicit() {
    let cases: [([String], Bool)] = [
      ([], false),
      (["--ui-testing"], true),
      (["--live-selection"], true),
      (["--live-capture"], false),
      (["--ui-testing", "--live-capture"], false),
      (["--live-selection", "--live-capture"], false),
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
