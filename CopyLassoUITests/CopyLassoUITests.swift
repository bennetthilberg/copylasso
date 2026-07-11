import AppKit
import XCTest

final class CopyLassoUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testDocklessShellLaunchesWithOneStatusItemAndNoWindow() {
    let app = completedApp()
    app.launch()
    defer { app.terminate() }

    XCTAssertTrue(statusItem(in: app).waitForExistence(timeout: 5))
    XCTAssertEqual(app.windows.count, 0)
  }

  @MainActor
  func testMenuExposesCommandsInTheRequiredOrder() {
    let app = completedApp()
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
    let app = completedApp()
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
    let app = completedApp()
    app.launch()
    defer { app.terminate() }

    let pasteboardChangeCount = NSPasteboard.general.changeCount

    openMenu(in: app)
    menuItem("Capture Text", in: app).click()

    XCTAssertEqual(NSPasteboard.general.changeCount, pasteboardChangeCount)
  }

  @MainActor
  func testSettingsAndAboutReopenAfterClosing() {
    var app = completedApp()
    app.launch()

    for _ in 0..<3 {
      openMenu(in: app)
      menuItem("Settings…", in: app).click()
      let settingsTitle = app.staticTexts["copylasso.settings.title"]
      XCTAssertTrue(settingsTitle.waitForExistence(timeout: 5))
      app.typeKey("w", modifierFlags: .command)
    }
    app.terminate()

    app = completedApp()
    app.launch()
    defer { app.terminate() }
    for _ in 0..<3 {
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
    let app = completedApp()
    app.launch()

    openMenu(in: app)
    menuItem("Quit CopyLasso", in: app).click()

    XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
  }

  @MainActor
  func testStatusItemAndMenuRemainAvailableInLightAndDarkAppearances() {
    for appearance in ["Light", "Dark"] {
      let app = completedApp()
      app.launchArguments += ["-AppleInterfaceStyle", appearance]
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
    let app = completedApp()
    app.launch()
    defer { app.terminate() }

    openMenu(in: app)
    let item = statusItem(in: app)
    item.typeKey(",", modifierFlags: .command)

    XCTAssertTrue(item.exists)
    XCTAssertTrue(
      app.descendants(matching: .any)["copylasso.settings.form"].waitForExistence(timeout: 5)
    )
  }

  @MainActor
  func testFreshLaunchShowsOnboardingWithoutProtectedPermissionUI() {
    let app = freshApp()
    app.launch()
    defer { app.terminate() }

    XCTAssertTrue(app.staticTexts["copylasso.onboarding.title"].waitForExistence(timeout: 5))
    XCTAssertTrue(statusItem(in: app).exists)
    XCTAssertFalse(app.dialogs["Screen Recording"].exists)
    retainScreenshot(named: "CopyLasso first-run onboarding")
  }

  @MainActor
  func testClosingIncompleteOnboardingLeavesMenuUsableAndReturnsNextLaunch() {
    var app = freshApp()
    app.launch()
    XCTAssertTrue(app.staticTexts["copylasso.onboarding.title"].waitForExistence(timeout: 5))

    app.typeKey("w", modifierFlags: .command)
    XCTAssertTrue(
      app.staticTexts["copylasso.onboarding.title"].waitForNonExistence(timeout: 5)
    )
    openMenu(in: app)
    XCTAssertTrue(menuItem("Capture Text", in: app).exists)
    app.terminate()

    app = unfinishedAppWithoutReset()
    app.launch()
    defer { app.terminate() }
    XCTAssertTrue(app.staticTexts["copylasso.onboarding.title"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testCompletedOnboardingDoesNotReturnOnRelaunch() {
    var app = freshApp()
    app.launch()
    XCTAssertTrue(app.staticTexts["copylasso.onboarding.title"].waitForExistence(timeout: 5))
    app.buttons["copylasso.onboarding.continue"].click()
    XCTAssertTrue(
      app.staticTexts["copylasso.onboarding.title"].waitForNonExistence(timeout: 5)
    )

    app.terminate()

    app = unfinishedAppWithoutReset()
    app.launch()
    defer { app.terminate() }
    XCTAssertFalse(app.staticTexts["copylasso.onboarding.title"].waitForExistence(timeout: 2))
    XCTAssertEqual(app.windows.count, 0)
  }

  @MainActor
  func testSettingsCanReopenIncompleteOnboarding() {
    let app = freshApp()
    app.launch()
    defer { app.terminate() }
    XCTAssertTrue(app.staticTexts["copylasso.onboarding.title"].waitForExistence(timeout: 5))
    app.typeKey("w", modifierFlags: .command)

    openMenu(in: app)
    menuItem("Settings…", in: app).click()
    let finishSetup = app.buttons["copylasso.settings.finish-setup"]
    XCTAssertTrue(finishSetup.waitForExistence(timeout: 5))
    finishSetup.click()

    XCTAssertTrue(app.staticTexts["copylasso.onboarding.title"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testSettingsExposeShortcutLoginPrivacyVersionAndLinks() {
    let app = completedApp()
    app.launch()
    defer { app.terminate() }

    openMenu(in: app)
    menuItem("Settings…", in: app).click()

    XCTAssertTrue(
      app.descendants(matching: .any)["copylasso.settings.shortcut"]
        .waitForExistence(timeout: 5)
    )
    XCTAssertTrue(app.buttons["copylasso.settings.use-suggested-shortcut"].exists)
    let launchAtLogin = app.descendants(matching: .any)[
      "copylasso.settings.launch-at-login"
    ]
    XCTAssertTrue(launchAtLogin.exists)
    XCTAssertTrue(
      app.descendants(matching: .any)["copylasso.login.status"].exists
    )
    XCTAssertTrue(app.staticTexts["Privacy"].exists)
    XCTAssertTrue(app.staticTexts["Version"].exists)
    XCTAssertTrue(app.staticTexts["Version 0.1.0 (1)"].exists)
    XCTAssertTrue(app.links["Project Repository"].exists)
    XCTAssertTrue(app.links["Privacy Policy"].exists)
    XCTAssertTrue(app.links["MIT License"].exists)
    retainScreenshot(named: "CopyLasso Settings")

  }

  @MainActor
  func testApprovalRequiredStateOffersLoginItemsRecovery() {
    let app = freshApp(extraArguments: ["--g10-g11-login-status=requires-approval"])
    app.launch()
    defer { app.terminate() }

    XCTAssertTrue(
      app.descendants(matching: .any)["copylasso.login.issue"].waitForExistence(timeout: 5)
    )
    let launchAtLogin = app.descendants(matching: .any)[
      "copylasso.onboarding.launch-at-login"
    ]
    XCTAssertTrue(launchAtLogin.exists)
    XCTAssertFalse(switchIsOn(launchAtLogin))
    XCTAssertTrue(app.buttons["copylasso.onboarding.retry-login"].exists)
    XCTAssertTrue(app.buttons["copylasso.login.open-settings"].exists)
    XCTAssertTrue(app.buttons["copylasso.onboarding.continue-without-login"].exists)
  }

  @MainActor
  func testSettingsCanRemoveAnApprovalRequiredLoginItem() {
    let app = completedApp(extraArguments: ["--g10-g11-login-status=requires-approval"])
    app.launch()
    defer { app.terminate() }

    openMenu(in: app)
    menuItem("Settings…", in: app).click()

    let removePending = app.buttons["copylasso.settings.remove-pending-login-item"]
    XCTAssertTrue(removePending.waitForExistence(timeout: 5))
    removePending.click()
    XCTAssertTrue(
      app.staticTexts["Launch at Login is disabled."].waitForExistence(timeout: 5)
    )
  }

  @MainActor
  func testPermissionRecoveryExplainsPriorRequestWithoutTouchingTCC() {
    let app = completedApp(extraArguments: ["--g12-permission=after-request"])
    app.launch()
    defer { app.terminate() }
    let pasteboardChangeCount = NSPasteboard.general.changeCount

    openMenu(in: app)
    menuItem("Capture Text", in: app).click()

    XCTAssertTrue(
      app.staticTexts["copylasso.permission-recovery.title"]
        .waitForExistence(timeout: 5)
    )
    XCTAssertTrue(app.staticTexts["copylasso.permission-recovery.status"].exists)
    XCTAssertTrue(app.buttons["copylasso.permission-recovery.open-settings"].exists)
    XCTAssertTrue(app.buttons["copylasso.permission-recovery.try-again"].exists)
    XCTAssertTrue(app.buttons["copylasso.permission-recovery.cancel"].exists)
    XCTAssertEqual(NSPasteboard.general.changeCount, pasteboardChangeCount)
  }

  @MainActor
  func testLikelyRevokedRecoveryRemainsSingletonAcrossRepeatedAttempts() {
    let app = completedApp(extraArguments: ["--g12-permission=previously-granted"])
    app.launch()
    defer { app.terminate() }

    for _ in 0..<3 {
      openMenu(in: app)
      menuItem("Capture Text", in: app).click()
      XCTAssertTrue(
        app.staticTexts["copylasso.permission-recovery.title"]
          .waitForExistence(timeout: 5)
      )
    }

    XCTAssertEqual(
      app.staticTexts.matching(identifier: "copylasso.permission-recovery.title").count,
      1
    )
    XCTAssertTrue(app.staticTexts["copylasso.permission-recovery.status"].exists)

    app.buttons["copylasso.permission-recovery.try-again"].click()
    XCTAssertTrue(
      app.staticTexts["copylasso.permission-recovery.retry-status"]
        .waitForExistence(timeout: 5)
    )
  }

  @MainActor
  func testPermissionRecoverySettingsFailureRetryAndCancel() {
    let app = completedApp(
      extraArguments: [
        "--g12-permission-sequence=after-request,granted,after-request",
        "--g12-settings-open=failure",
      ]
    )
    app.launch()
    defer { app.terminate() }

    openMenu(in: app)
    menuItem("Capture Text", in: app).click()
    XCTAssertTrue(
      app.staticTexts["copylasso.permission-recovery.title"]
        .waitForExistence(timeout: 5)
    )

    app.buttons["copylasso.permission-recovery.open-settings"].click()
    XCTAssertTrue(
      app.staticTexts["copylasso.permission-recovery.settings-failure"]
        .waitForExistence(timeout: 5)
    )

    app.buttons["copylasso.permission-recovery.try-again"].click()
    XCTAssertTrue(
      app.staticTexts["copylasso.permission-recovery.title"]
        .waitForNonExistence(timeout: 5)
    )

    openMenu(in: app)
    menuItem("Capture Text", in: app).click()
    XCTAssertTrue(
      app.staticTexts["copylasso.permission-recovery.title"]
        .waitForExistence(timeout: 5)
    )
    app.buttons["copylasso.permission-recovery.cancel"].click()
    XCTAssertTrue(
      app.staticTexts["copylasso.permission-recovery.title"]
        .waitForNonExistence(timeout: 5)
    )

    openMenu(in: app)
    menuItem("Capture Text", in: app).click()
    XCTAssertTrue(
      app.staticTexts["copylasso.permission-recovery.title"]
        .waitForExistence(timeout: 5)
    )
    XCTAssertEqual(
      app.staticTexts.matching(identifier: "copylasso.permission-recovery.title").count,
      1
    )
  }

  @MainActor
  func testPermissionRecoverySupportsKeyboardCancelAndAccessibleButtonLabels() {
    let app = completedApp(extraArguments: ["--g12-permission=after-request"])
    app.launch()
    defer { app.terminate() }

    openMenu(in: app)
    menuItem("Capture Text", in: app).click()
    XCTAssertTrue(
      app.staticTexts["copylasso.permission-recovery.title"]
        .waitForExistence(timeout: 5)
    )

    XCTAssertEqual(
      app.buttons["copylasso.permission-recovery.open-settings"].label,
      "Open System Settings"
    )
    XCTAssertEqual(
      app.buttons["copylasso.permission-recovery.try-again"].label,
      "Try Again"
    )
    XCTAssertEqual(
      app.buttons["copylasso.permission-recovery.cancel"].label,
      "Cancel"
    )

    app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
    XCTAssertTrue(
      app.staticTexts["copylasso.permission-recovery.title"]
        .waitForNonExistence(timeout: 5)
    )
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

  @MainActor
  private func retainScreenshot(named name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  @MainActor
  private func switchIsOn(_ element: XCUIElement) -> Bool {
    if let number = element.value as? NSNumber {
      return number.boolValue
    }
    return element.value as? String == "1"
  }

  @MainActor
  private func completedApp(extraArguments: [String] = []) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments =
      [
        "--g10-g11-ui-testing",
        "--g10-g11-reset-settings",
        "--g10-g11-complete-onboarding",
        "--g12-permission=granted",
      ] + extraArguments
    return app
  }

  @MainActor
  private func freshApp(extraArguments: [String] = []) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments =
      [
        "--g10-g11-ui-testing",
        "--g10-g11-reset-settings",
      ] + extraArguments
    return app
  }

  @MainActor
  private func unfinishedAppWithoutReset() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--g10-g11-ui-testing"]
    return app
  }

  private static let requiredMenuLabels = [
    "Capture Text",
    "Settings…",
    "About CopyLasso",
    "Quit CopyLasso",
  ]
}
