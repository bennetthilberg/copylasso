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
  func testScreenCaptureSpikeHarnessLaunchesWithoutPrompting() {
    let app = XCUIApplication()
    app.launchArguments = ["--g06-capture-spike"]
    app.launch()

    XCTAssertTrue(app.staticTexts["copylasso.capture-spike.title"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["copylasso.capture-spike.request"].exists)
    XCTAssertTrue(app.buttons["copylasso.capture-spike.capture-again"].exists)
    XCTAssertTrue(app.buttons["copylasso.capture-spike.clear"].exists)
    XCTAssertTrue(app.buttons["copylasso.capture-spike.reset-history"].exists)
  }

  @MainActor
  func testSelectionOverlaySpikeHarnessLaunchesWithoutPresentingOverlay() {
    let app = XCUIApplication()
    app.launchArguments = ["--g07-selection-spike"]
    app.launch()

    XCTAssertTrue(app.staticTexts["copylasso.selection-spike.title"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["copylasso.selection-spike.begin-now"].exists)
    XCTAssertTrue(app.buttons["copylasso.selection-spike.begin-delayed"].exists)
    XCTAssertTrue(app.staticTexts["copylasso.selection-spike.no-outcome"].exists)
  }
}
