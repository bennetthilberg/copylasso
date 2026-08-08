import Foundation
import ScreenCaptureKit
import XCTest

@testable import CopyLasso

final class SystemScreenCapturePermissionClientTests: XCTestCase {
  func testOnlyUserDeclinedIsClassifiedAsDenied() {
    XCTAssertEqual(
      SystemScreenCapturePermissionProbe.classify(
        NSError(
          domain: SCStreamErrorDomain,
          code: SCStreamError.Code.userDeclined.rawValue
        )
      ),
      .denied
    )
  }

  func testDisplayAndFrameworkFailuresRemainUnavailable() {
    let errors = [
      NSError(
        domain: SCStreamErrorDomain,
        code: SCStreamError.Code.noDisplayList.rawValue
      ),
      NSError(
        domain: SCStreamErrorDomain,
        code: SCStreamError.Code.noCaptureSource.rawValue
      ),
      NSError(domain: "CopyLassoTests", code: 91),
    ]

    for error in errors {
      XCTAssertEqual(
        SystemScreenCapturePermissionProbe.classify(error),
        .unavailable
      )
    }
  }
}
