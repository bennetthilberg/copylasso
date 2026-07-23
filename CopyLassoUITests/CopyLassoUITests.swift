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

    let commandGaps = zip(requiredItems, requiredItems.dropFirst()).map {
      earlierItem, laterItem in
      laterItem.frame.minY - earlierItem.frame.maxY
    }
    XCTAssertGreaterThan(commandGaps[0], commandGaps[1])
    XCTAssertGreaterThan(commandGaps[3], commandGaps[2])
  }

  @MainActor
  func testMenuShowsTheSavedCaptureShortcut() {
    let app = completedApp()
    app.launch()
    defer { app.terminate() }

    openMenu(in: app)
    let clearedShortcutMenuWidth = menuItem("Capture Text", in: app).frame.width
    app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])

    openMenu(in: app)
    menuItem("Settings…", in: app).click()
    let useSuggestedShortcut = app.buttons["copylasso.settings.use-suggested-shortcut"]
    XCTAssertTrue(useSuggestedShortcut.waitForExistence(timeout: 5))
    useSuggestedShortcut.click()
    app.typeKey("w", modifierFlags: .command)

    openMenu(in: app)
    let savedShortcutMenuWidth = menuItem("Capture Text", in: app).frame.width
    XCTAssertGreaterThan(savedShortcutMenuWidth, clearedShortcutMenuWidth)
    retainScreenshot(named: "CopyLasso menu with saved Capture Text shortcut")
    app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])

    openMenu(in: app)
    menuItem("Settings…", in: app).click()
    let shortcutRecorder = app.descendants(matching: .any)["copylasso.settings.shortcut"]
    XCTAssertTrue(shortcutRecorder.waitForExistence(timeout: 5))
    shortcutRecorder.click()
    app.typeKey("k", modifierFlags: [.control, .option])
    app.typeKey("w", modifierFlags: .command)

    openMenu(in: app)
    let customShortcutMenuWidth = menuItem("Capture Text", in: app).frame.width
    XCTAssertGreaterThan(customShortcutMenuWidth, clearedShortcutMenuWidth)
    retainScreenshot(named: "CopyLasso menu with custom Capture Text shortcut")
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
  func testLiveSelectionOverlayIsAccessibleAndEscapeCleansItUp() {
    let app = completedApp(extraArguments: ["--g13-live-selection"])
    app.launch()
    defer { app.terminate() }

    openMenu(in: app)
    menuItem("Capture Text", in: app).click()

    let overlay = selectionOverlay(in: app)
    XCTAssertTrue(overlay.waitForExistence(timeout: 5))
    XCTAssertEqual(overlay.label, "CopyLasso text selection overlay")
    app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
    XCTAssertTrue(overlay.waitForNonExistence(timeout: 5))

    _ = openMenuAndWaitForCapture(in: app)
  }

  @MainActor
  func testLiveSelectionClickAndValidDragCleanUpWithoutClipboardMutation() {
    let app = completedApp(extraArguments: ["--g13-live-selection"])
    app.launch()
    defer { app.terminate() }
    let pasteboardChangeCount = NSPasteboard.general.changeCount

    openMenuAndWaitForCapture(in: app).click()
    var overlay = selectionOverlay(in: app)
    XCTAssertTrue(overlay.waitForExistence(timeout: 5))
    overlay.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
    XCTAssertTrue(overlay.waitForNonExistence(timeout: 5))

    openMenuAndWaitForCapture(in: app).click()
    overlay = selectionOverlay(in: app)
    XCTAssertTrue(overlay.waitForExistence(timeout: 5))
    let start = overlay.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.35))
    let end = overlay.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.50))
    start.press(forDuration: 0.1, thenDragTo: end)

    XCTAssertTrue(overlay.waitForNonExistence(timeout: 5))
    XCTAssertEqual(NSPasteboard.general.changeCount, pasteboardChangeCount)
    _ = openMenuAndWaitForCapture(in: app)
  }

  @MainActor
  func testLiveSelectionRemainsReusableAcrossTwentyMixedSessions() {
    let app = completedApp(extraArguments: ["--g13-live-selection"])
    app.launch()
    defer { app.terminate() }
    let pasteboardChangeCount = NSPasteboard.general.changeCount

    for index in 0..<20 {
      let capture = openMenuAndWaitForCapture(
        in: app,
        message: "Capture should be idle before session \(index + 1)"
      )
      capture.click()

      let overlay = selectionOverlay(in: app)
      XCTAssertTrue(overlay.waitForExistence(timeout: 5))

      switch index % 3 {
      case 0:
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
      case 1:
        overlay.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
      default:
        let start = overlay.coordinate(withNormalizedOffset: CGVector(dx: 0.40, dy: 0.40))
        let end = overlay.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.52))
        start.press(forDuration: 0.1, thenDragTo: end)
      }

      XCTAssertTrue(
        overlay.waitForNonExistence(timeout: 5),
        "Overlay should be absent after session \(index + 1)"
      )
    }

    XCTAssertEqual(NSPasteboard.general.changeCount, pasteboardChangeCount)
    _ = openMenuAndWaitForCapture(in: app)
  }

  @MainActor
  func testLiveSelectionCleansUpAfterCrossDisplayDrags() throws {
    let displayCount = NSScreen.screens.count
    guard displayCount > 1 else {
      throw XCTSkip("Cross-display UI verification requires an extended display")
    }

    let app = completedApp(extraArguments: ["--g13-live-selection"])
    app.launch()
    defer { app.terminate() }
    let pasteboardChangeCount = NSPasteboard.general.changeCount

    for indices in [(0, 1), (1, 0)] {
      openMenuAndWaitForCapture(in: app).click()

      let overlays = app.dialogs.matching(identifier: "copylasso.selection.overlay")
      XCTAssertTrue(overlays.firstMatch.waitForExistence(timeout: 5))
      XCTAssertEqual(overlays.count, displayCount)

      let start = overlays.element(boundBy: indices.0).coordinate(
        withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
      )
      let end = overlays.element(boundBy: indices.1).coordinate(
        withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
      )
      start.press(forDuration: 0.1, thenDragTo: end)

      XCTAssertTrue(overlays.firstMatch.waitForNonExistence(timeout: 5))
    }

    XCTAssertEqual(NSPasteboard.general.changeCount, pasteboardChangeCount)
    _ = openMenuAndWaitForCapture(in: app)
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
      XCTAssertTrue(app.images["copylasso.about.icon"].exists)
      assertAccessibleText(
        app.staticTexts["copylasso.about.version"], equals: "Version 0.1.1 (2)"
      )
      assertAccessibleText(
        app.staticTexts["copylasso.about.creator"],
        equals: "Created by Bennett Hilberg"
      )
      XCTAssertTrue(app.links["copylasso.about.repository"].exists)
      XCTAssertTrue(app.links["copylasso.about.license"].exists)
      XCTAssertTrue(app.buttons["copylasso.about.acknowledgements"].exists)
      app.buttons["copylasso.about.acknowledgements"].click()
      XCTAssertTrue(
        app.staticTexts["copylasso.about.acknowledgements.title"].waitForExistence(timeout: 5)
      )
      XCTAssertTrue(app.staticTexts["KeyboardShortcuts 3.0.1"].exists)
      XCTAssertTrue(app.staticTexts["Sparkle 2.9.4"].exists)
      app.buttons["copylasso.about.acknowledgements.done"].click()
      app.typeKey("w", modifierFlags: .command)
      XCTAssertTrue(aboutTitle.waitForNonExistence(timeout: 5))
    }
  }

  @MainActor
  func testSettingsOpenedFromMenuWhileFinderIsFrontmostAppearsImmediately() {
    let app = completedApp()
    app.launch()
    defer { app.terminate() }

    XCUIApplication(bundleIdentifier: "com.apple.finder").activate()
    openMenu(in: app)
    menuItem("Settings…", in: app).click()

    XCTAssertTrue(
      app.staticTexts["copylasso.settings.title"].waitForExistence(timeout: 5)
    )
  }

  @MainActor
  private func assertAccessibleText(
    _ element: XCUIElement,
    equals expected: String,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let exposedText = [element.label, element.value as? String].compactMap { $0 }
    XCTAssertTrue(
      exposedText.contains(expected),
      "Expected accessibility to expose \(expected.debugDescription); got \(exposedText)",
      file: file,
      line: line
    )
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
  func testOnboardingExposesCompoundControlNamesAndCompletesFromTheKeyboard() {
    let app = freshApp()
    app.launch()
    defer { app.terminate() }

    XCTAssertTrue(app.staticTexts["copylasso.onboarding.title"].waitForExistence(timeout: 5))
    let shortcut = app.descendants(matching: .any)["copylasso.onboarding.shortcut"]
    let launchAtLogin = app.descendants(matching: .any)[
      "copylasso.onboarding.launch-at-login"
    ]
    XCTAssertEqual(shortcut.label, "Capture Text keyboard shortcut")
    XCTAssertEqual(launchAtLogin.label, "Launch CopyLasso at Login")

    app.typeKey(XCUIKeyboardKey.return, modifierFlags: [])
    XCTAssertTrue(
      app.staticTexts["copylasso.onboarding.title"].waitForNonExistence(timeout: 5)
    )
  }

  @MainActor
  func testSettingsExposesNamedControlStatesAndClosesFromTheKeyboard() {
    let app = completedApp()
    app.launch()
    defer { app.terminate() }

    openMenu(in: app)
    statusItem(in: app).typeKey(",", modifierFlags: .command)
    let shortcut = app.descendants(matching: .any)["copylasso.settings.shortcut"]
    let launchAtLogin = app.descendants(matching: .any)[
      "copylasso.settings.launch-at-login"
    ]
    XCTAssertTrue(shortcut.waitForExistence(timeout: 5))
    XCTAssertEqual(shortcut.label, "Capture Text keyboard shortcut")
    XCTAssertEqual(launchAtLogin.label, "Launch CopyLasso at Login")
    XCTAssertNotNil(launchAtLogin.value)

    app.typeKey("w", modifierFlags: .command)
    XCTAssertTrue(shortcut.waitForNonExistence(timeout: 5))
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
    let automaticUpdates = app.descendants(matching: .any)[
      "copylasso.settings.automatic-updates"
    ]
    XCTAssertTrue(automaticUpdates.exists)
    XCTAssertTrue(switchIsOn(automaticUpdates))
    let successSound = app.descendants(matching: .any)[
      "copylasso.settings.success-sound"
    ]
    XCTAssertTrue(successSound.exists)
    XCTAssertTrue(switchIsOn(successSound))
    XCTAssertTrue(app.buttons["copylasso.settings.check-for-updates"].isEnabled)
    XCTAssertTrue(
      app.descendants(matching: .any)["copylasso.login.status"].exists
    )
    XCTAssertTrue(app.staticTexts["Privacy"].exists)
    XCTAssertTrue(app.staticTexts["Version"].exists)
    XCTAssertTrue(app.staticTexts["Version 0.1.1 (2)"].exists)
    XCTAssertTrue(app.links["Project Repository"].exists)
    XCTAssertTrue(app.links["Privacy Policy"].exists)
    XCTAssertTrue(app.links["MIT License"].exists)
    XCTAssertFalse(
      app.staticTexts[
        "Clear the shortcut to keep Capture Text available only from the menu bar."
      ].exists
    )
    XCTAssertFalse(
      app.staticTexts[
        "The sound plays only after recognized content reaches the clipboard."
      ].exists
    )
    XCTAssertFalse(
      app.staticTexts[
        "Checks retrieve only signed update information. CopyLasso never sends screen, OCR, or clipboard content."
      ].exists
    )
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
  private func openMenuAndWaitForCapture(
    in app: XCUIApplication,
    message: String = "Capture should return to idle"
  ) -> XCUIElement {
    openMenu(in: app)
    let capture = menuItem("Capture Text", in: app)
    let enabled = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "enabled == true"),
      object: capture
    )
    XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed, message)
    return capture
  }

  @MainActor
  private func menuItem(_ label: String, in app: XCUIApplication) -> XCUIElement {
    statusItem(in: app).menuItems[label]
  }

  @MainActor
  private func selectionOverlay(in app: XCUIApplication) -> XCUIElement {
    app.dialogs["copylasso.selection.overlay"]
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
    "Check for Updates…",
    "Settings…",
    "About CopyLasso",
    "Quit CopyLasso",
  ]
}
