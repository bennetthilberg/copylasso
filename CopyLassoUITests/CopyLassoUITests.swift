import XCTest

final class CopyLassoUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testPlaceholderLaunches() {
    let app = XCUIApplication()
    app.launch()

    let title = app.staticTexts["copylasso.placeholder.title"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
  }
}
