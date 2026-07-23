import XCTest

@testable import CopyLasso

final class SecureUpdateDownloadBudgetTests: XCTestCase {
  func testMatchingLengthAndCompleteDownloadPasses() {
    var budget = SecureUpdateDownloadBudget(signedBytes: 8, maximumBytes: 16)
    var cancellations = 0
    budget.begin { cancellations += 1 }

    budget.receiveExpectedContentLength(8)
    budget.receiveData(length: 3)
    budget.receiveData(length: 5)

    XCTAssertEqual(budget.receivedBytes, 8)
    XCTAssertFalse(budget.isCancelled)
    XCTAssertTrue(budget.isComplete)
    XCTAssertEqual(cancellations, 0)
  }

  func testExpectedLengthMismatchOrCeilingCancelsExactlyOnce() {
    for length in [UInt64(7), 17] {
      var budget = SecureUpdateDownloadBudget(signedBytes: 8, maximumBytes: 16)
      var cancellations = 0
      budget.begin { cancellations += 1 }

      budget.receiveExpectedContentLength(length)
      budget.receiveExpectedContentLength(length)
      budget.receiveData(length: 1)

      XCTAssertTrue(budget.isCancelled)
      XCTAssertEqual(cancellations, 1)
      XCTAssertEqual(budget.receivedBytes, 0)
    }
  }

  func testReceivedByteOverflowAndOverrunCancelExactlyOnce() {
    var overrun = SecureUpdateDownloadBudget(signedBytes: 8, maximumBytes: 16)
    var overrunCancellations = 0
    overrun.begin { overrunCancellations += 1 }
    overrun.receiveData(length: 9)
    overrun.receiveData(length: 1)
    XCTAssertTrue(overrun.isCancelled)
    XCTAssertEqual(overrunCancellations, 1)

    var overflow = SecureUpdateDownloadBudget(
      signedBytes: UInt64.max,
      maximumBytes: UInt64.max
    )
    var overflowCancellations = 0
    overflow.begin { overflowCancellations += 1 }
    overflow.receiveData(length: UInt64.max)
    overflow.receiveData(length: 1)
    XCTAssertTrue(overflow.isCancelled)
    XCTAssertEqual(overflowCancellations, 1)
  }

  func testIncompleteDownloadDoesNotAuthorizeExtraction() {
    var budget = SecureUpdateDownloadBudget(signedBytes: 8, maximumBytes: 16)
    budget.begin {}
    budget.receiveExpectedContentLength(8)
    budget.receiveData(length: 7)

    XCTAssertFalse(budget.isComplete)
  }
}
