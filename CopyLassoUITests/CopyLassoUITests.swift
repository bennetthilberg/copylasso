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

  @MainActor
  func testRetiredScreenCaptureArgumentStillShowsOnlyThePlaceholder() {
    let app = XCUIApplication()
    app.launchArguments = ["--g06-capture-spike"]
    app.launch()

    XCTAssertTrue(app.staticTexts["copylasso.placeholder.title"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["copylasso.capture-spike.title"].exists)
  }

  @MainActor
  func testRetiredSelectionArgumentStillShowsOnlyThePlaceholder() {
    let app = XCUIApplication()
    app.launchArguments = ["--g07-selection-spike"]
    app.launch()

    XCTAssertTrue(app.staticTexts["copylasso.placeholder.title"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["copylasso.selection-spike.title"].exists)
  }
}
