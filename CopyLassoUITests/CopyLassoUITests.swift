import AppKit
import XCTest

final class CopyLassoUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testDocklessShellLaunchesWithOneStatusItemAndNoWindow() {
    let app = XCUIApplication()
    app.launch()
    defer { app.terminate() }

    XCTAssertTrue(statusItem(in: app).waitForExistence(timeout: 5))
    XCTAssertEqual(app.windows.count, 0)
  }

  @MainActor
  func testMenuExposesCommandsInTheRequiredOrder() {
    let app = XCUIApplication()
    app.launch()
    defer { app.terminate() }

    openMenu(in: app)
    let requiredItems = Self.requiredMenuLabels.map { menuItem($0, in: app) }
    for item in requiredItems {
      XCTAssertTrue(item.exists)
    }

    let verticalPositions = requiredItems.map { $0.frame.minY }
    XCTAssertEqual(verticalPositions, verticalPositions.sorted())
  }

  @MainActor
  func testCaptureCommandRemainsUsableForThreeInvocations() {
    let app = XCUIApplication()
    app.launch()
    defer { app.terminate() }

    for _ in 0..<3 {
      openMenu(in: app)
      let capture = menuItem("Capture Text", in: app)
      XCTAssertTrue(capture.isEnabled)
      capture.click()
    }
  }

  @MainActor
  func testCaptureDoesNotChangeTheClipboard() {
    let app = XCUIApplication()
    app.launch()
    defer { app.terminate() }

    let pasteboardChangeCount = NSPasteboard.general.changeCount

    openMenu(in: app)
    menuItem("Capture Text", in: app).click()

    XCTAssertEqual(NSPasteboard.general.changeCount, pasteboardChangeCount)
  }

  @MainActor
  func testSettingsAndAboutReopenAfterClosing() {
    let app = XCUIApplication()
    app.launch()
    defer { app.terminate() }

    for _ in 0..<3 {
      openMenu(in: app)
      menuItem("Settings…", in: app).click()
      let settingsTitle = app.staticTexts["copylasso.settings.title"]
      XCTAssertTrue(settingsTitle.waitForExistence(timeout: 5))
      app.typeKey("w", modifierFlags: .command)
      XCTAssertTrue(settingsTitle.waitForNonExistence(timeout: 5))

      openMenu(in: app)
      menuItem("About CopyLasso", in: app).click()
      let aboutTitle = app.staticTexts["copylasso.about.title"]
      XCTAssertTrue(aboutTitle.waitForExistence(timeout: 5))
      app.typeKey("w", modifierFlags: .command)
      XCTAssertTrue(aboutTitle.waitForNonExistence(timeout: 5))
    }
  }

  @MainActor
  func testQuitCommandTerminatesTheApplication() {
    let app = XCUIApplication()
    app.launch()

    openMenu(in: app)
    menuItem("Quit CopyLasso", in: app).click()

    XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
  }

  @MainActor
  func testStatusItemAndMenuRemainAvailableInLightAndDarkAppearances() {
    for appearance in ["Light", "Dark"] {
      let app = XCUIApplication()
      app.launchArguments = ["-AppleInterfaceStyle", appearance]
      app.launch()

      openMenu(in: app)
      XCTAssertTrue(menuItem("Capture Text", in: app).exists)

      let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      attachment.name = "CopyLasso menu — \(appearance)"
      attachment.lifetime = .keepAlways
      add(attachment)

      app.terminate()
    }
  }

  @MainActor
  func testMenuSupportsKeyboardNavigation() {
    let app = XCUIApplication()
    app.launch()
    defer { app.terminate() }

    openMenu(in: app)
    let item = statusItem(in: app)
    item.typeKey(",", modifierFlags: .command)

    XCTAssertTrue(item.exists)
    XCTAssertTrue(app.staticTexts["copylasso.settings.title"].waitForExistence(timeout: 5))
  }

  @MainActor
  private func statusItem(in app: XCUIApplication) -> XCUIElement {
    app.menuBars.statusItems["CopyLasso"]
  }

  @MainActor
  private func openMenu(in app: XCUIApplication) {
    let item = statusItem(in: app)
    XCTAssertTrue(item.waitForExistence(timeout: 5))
    item.click()
    XCTAssertTrue(menuItem("Capture Text", in: app).waitForExistence(timeout: 5))
  }

  @MainActor
  private func menuItem(_ label: String, in app: XCUIApplication) -> XCUIElement {
    statusItem(in: app).menuItems[label]
  }

  private static let requiredMenuLabels = [
    "Capture Text",
    "Settings…",
    "About CopyLasso",
    "Quit CopyLasso",
  ]
}
