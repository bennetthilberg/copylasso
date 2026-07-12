import AppKit
import KeyboardShortcuts
import Observation
import XCTest

@testable import CopyLasso

@MainActor
final class SettingsControllerTests: XCTestCase {
  func testFreshStateNeedsOnboardingAndPresentsOnlyOncePerProcess() {
    let context = makeContext()

    XCTAssertTrue(context.controller.needsOnboarding)
    XCTAssertEqual(context.controller.onboardingShortcutDraft, suggestedShortcut)
    XCTAssertTrue(context.controller.onboardingLaunchAtLoginDraft)
    XCTAssertTrue(context.controller.takeInitialOnboardingPresentationRequest())
    XCTAssertFalse(context.controller.takeInitialOnboardingPresentationRequest())
    XCTAssertTrue(context.controller.requestOnboardingFromSettings())
  }

  func testClosingOnboardingDoesNotCompleteItOrApplyDraftChoices() {
    let context = makeContext()

    context.controller.onboardingClosed()

    XCTAssertTrue(context.controller.needsOnboarding)
    XCTAssertEqual(context.store.completedOnboardingVersion, 0)
    XCTAssertNil(context.shortcutStore.captureShortcut)
    XCTAssertEqual(context.login.enableCallCount, 0)
    XCTAssertEqual(context.login.disableCallCount, 0)
  }

  func testCompletedAndFutureOnboardingVersions() {
    let completed = makeContext(completedOnboardingVersion: 1)
    XCTAssertFalse(completed.controller.needsOnboarding)
    XCTAssertFalse(completed.controller.takeInitialOnboardingPresentationRequest())

    let migration = makeContext(completedOnboardingVersion: 1, currentOnboardingVersion: 2)
    XCTAssertTrue(migration.controller.needsOnboarding)
  }

  func testCompletingWithLoginEnabledAppliesLoginThenShortcutThenVersion() {
    let context = makeContext()
    let shortcut = suggestedShortcut
    context.login.status = .disabled
    context.login.statusAfterEnable = .enabled

    XCTAssertEqual(
      context.controller.completeOnboarding(shortcut: shortcut, launchAtLogin: true),
      .completed
    )
    XCTAssertEqual(context.login.enableCallCount, 1)
    XCTAssertEqual(context.shortcutStore.captureShortcut, shortcut)
    XCTAssertEqual(context.store.completedOnboardingVersion, 1)
    XCTAssertFalse(context.controller.needsOnboarding)
  }

  func testLoginEnableFailureKeepsOnboardingAndShortcutUncommitted() {
    let context = makeContext()
    context.login.enableError = .injected

    XCTAssertEqual(
      context.controller.completeOnboarding(
        shortcut: suggestedShortcut,
        launchAtLogin: true
      ),
      .requiresRecovery
    )
    XCTAssertEqual(context.controller.launchAtLoginIssue, .enableFailed)
    XCTAssertNil(context.shortcutStore.captureShortcut)
    XCTAssertEqual(context.store.completedOnboardingVersion, 0)
  }

  func testLoginEnableCanRetryAfterARecoverableFailure() {
    let context = makeContext()
    context.login.enableError = .injected

    XCTAssertEqual(
      context.controller.completeOnboarding(
        shortcut: suggestedShortcut,
        launchAtLogin: true
      ),
      .requiresRecovery
    )

    context.login.enableError = nil
    context.login.statusAfterEnable = .enabled
    XCTAssertEqual(
      context.controller.completeOnboarding(
        shortcut: suggestedShortcut,
        launchAtLogin: true
      ),
      .completed
    )
    XCTAssertEqual(context.login.enableCallCount, 2)
    XCTAssertEqual(context.shortcutStore.captureShortcut, suggestedShortcut)
    XCTAssertEqual(context.store.completedOnboardingVersion, 1)
  }

  func testAlreadyEnabledLoginItemCompletesWithoutRedundantRegistration() {
    let context = makeContext()
    context.login.status = .enabled

    XCTAssertEqual(
      context.controller.completeOnboarding(
        shortcut: suggestedShortcut,
        launchAtLogin: true
      ),
      .completed
    )
    XCTAssertEqual(context.login.enableCallCount, 0)
    XCTAssertTrue(context.controller.isLaunchAtLoginEnabled)
  }

  func testPreexistingApprovalAndUnavailableStatesBlockEnableWithoutRegistration() {
    for (status, issue) in [
      (LaunchAtLoginStatus.requiresApproval, LaunchAtLoginIssue.requiresApproval),
      (.unavailable, .unavailable),
    ] {
      let context = makeContext()
      context.login.status = status

      XCTAssertFalse(context.controller.setLaunchAtLoginEnabled(true))
      XCTAssertEqual(context.controller.launchAtLoginIssue, issue)
      XCTAssertEqual(context.login.enableCallCount, 0)
    }
  }

  func testRegistrationMustReadBackEnabledBeforeOnboardingCanComplete() {
    for (statusAfterEnable, expectedIssue) in [
      (LaunchAtLoginStatus.disabled, LaunchAtLoginIssue.enableFailed),
      (.unavailable, .unavailable),
    ] {
      let context = makeContext()
      context.login.statusAfterEnable = statusAfterEnable

      XCTAssertEqual(
        context.controller.completeOnboarding(
          shortcut: suggestedShortcut,
          launchAtLogin: true
        ),
        .requiresRecovery
      )
      XCTAssertEqual(context.controller.launchAtLoginIssue, expectedIssue)
      XCTAssertEqual(context.store.completedOnboardingVersion, 0)
      XCTAssertNil(context.shortcutStore.captureShortcut)
    }
  }

  func testApprovalRequirementKeepsOnboardingOpenAndOpensSystemSettings() {
    let context = makeContext()
    context.login.statusAfterEnable = .requiresApproval

    XCTAssertEqual(
      context.controller.completeOnboarding(
        shortcut: suggestedShortcut,
        launchAtLogin: true
      ),
      .requiresRecovery
    )
    XCTAssertEqual(context.controller.launchAtLoginIssue, .requiresApproval)

    context.controller.openLoginItemsSettings()
    XCTAssertEqual(context.login.openSettingsCallCount, 1)
  }

  func testContinueWithoutLoginDisablesExistingRegistrationAndCompletes() {
    let context = makeContext()
    context.login.status = .enabled
    context.login.statusAfterDisable = .disabled

    XCTAssertEqual(
      context.controller.continueWithoutLaunchAtLogin(shortcut: nil),
      .completed
    )
    XCTAssertEqual(context.login.disableCallCount, 1)
    XCTAssertNil(context.shortcutStore.captureShortcut)
    XCTAssertEqual(context.store.completedOnboardingVersion, 1)
  }

  func testSettingsToggleReflectsOnlyActualEnabledStatus() {
    let context = makeContext()
    context.login.status = .requiresApproval
    context.controller.refreshLaunchAtLoginStatus()
    XCTAssertFalse(context.controller.isLaunchAtLoginEnabled)
    XCTAssertEqual(context.controller.launchAtLoginIssue, .requiresApproval)

    context.login.status = .enabled
    context.controller.refreshLaunchAtLoginStatus()
    XCTAssertTrue(context.controller.isLaunchAtLoginEnabled)
    XCTAssertNil(context.controller.launchAtLoginIssue)
  }

  func testSettingsCanEnableDisableAndReportFailuresWithoutFalseState() {
    let context = makeContext()
    context.login.statusAfterEnable = .enabled
    XCTAssertTrue(context.controller.setLaunchAtLoginEnabled(true))
    XCTAssertTrue(context.controller.isLaunchAtLoginEnabled)

    context.login.disableError = .injected
    XCTAssertFalse(context.controller.setLaunchAtLoginEnabled(false))
    XCTAssertTrue(context.controller.isLaunchAtLoginEnabled)
    XCTAssertEqual(context.controller.launchAtLoginIssue, .disableFailed)
  }

  func testSettingsChoicesBecomeFutureOnboardingDrafts() {
    let context = makeContext()
    let replacement = KeyboardShortcuts.Shortcut(
      .eight,
      modifiers: [.option, .command]
    )

    context.controller.setCaptureShortcut(replacement)
    context.login.statusAfterEnable = .enabled
    XCTAssertTrue(context.controller.setLaunchAtLoginEnabled(true))
    XCTAssertEqual(context.controller.onboardingShortcutDraft, replacement)
    XCTAssertTrue(context.controller.onboardingLaunchAtLoginDraft)

    context.controller.setCaptureShortcut(nil)
    context.login.statusAfterDisable = .disabled
    XCTAssertTrue(context.controller.setLaunchAtLoginEnabled(false))
    XCTAssertNil(context.controller.onboardingShortcutDraft)
    XCTAssertFalse(context.controller.onboardingLaunchAtLoginDraft)
  }

  func testSuggestedShortcutPublishesAnImmediateRecorderUpdate() {
    let context = makeContext()
    let replacement = KeyboardShortcuts.Shortcut(
      .eight,
      modifiers: [.option, .command]
    )
    context.controller.setCaptureShortcut(replacement)
    let update = expectation(description: "Capture shortcut observation changed")

    withObservationTracking {
      _ = context.controller.captureShortcut
    } onChange: {
      update.fulfill()
    }

    context.controller.useSuggestedCaptureShortcut()

    wait(for: [update], timeout: 0.1)
    XCTAssertEqual(context.controller.captureShortcut, suggestedShortcut)
  }

  func testApprovalRequiredLoginItemCanBeDisabled() {
    let context = makeContext()
    context.login.status = .requiresApproval
    context.login.statusAfterDisable = .disabled
    context.controller.refreshLaunchAtLoginStatus()

    XCTAssertFalse(context.controller.isLaunchAtLoginEnabled)
    XCTAssertTrue(context.controller.setLaunchAtLoginEnabled(false))
    XCTAssertEqual(context.login.disableCallCount, 1)
    XCTAssertEqual(context.controller.launchAtLoginStatus, .disabled)
  }

  func testAlreadyDisabledLoginItemStillVerifiesThePostcondition() {
    let context = makeContext()
    context.login.status = .disabled
    context.login.statusAfterDisable = .enabled

    XCTAssertFalse(context.controller.setLaunchAtLoginEnabled(false))
    XCTAssertEqual(context.login.disableCallCount, 1)
    XCTAssertEqual(context.controller.launchAtLoginStatus, .enabled)
    XCTAssertEqual(context.controller.launchAtLoginIssue, .disableFailed)
  }

  func testEveryDisableFailureLeavesARecoverableIssue() {
    let alreadyDisabled = makeContext()
    alreadyDisabled.login.disableError = .injected
    XCTAssertFalse(alreadyDisabled.controller.setLaunchAtLoginEnabled(false))
    XCTAssertEqual(alreadyDisabled.controller.launchAtLoginIssue, .disableFailed)

    let changedExternally = makeContext()
    changedExternally.login.status = .enabled
    changedExternally.login.statusAfterDisable = .requiresApproval
    XCTAssertFalse(changedExternally.controller.setLaunchAtLoginEnabled(false))
    XCTAssertEqual(changedExternally.controller.launchAtLoginIssue, .disableFailed)
  }

  func testUnavailableLoginItemCanBeExplicitlySkippedDuringOnboarding() {
    let context = makeContext()
    context.login.status = .unavailable

    XCTAssertEqual(
      context.controller.continueWithoutLaunchAtLogin(shortcut: nil),
      .completed
    )
    XCTAssertEqual(context.login.disableCallCount, 0)
    XCTAssertEqual(context.controller.launchAtLoginIssue, .unavailable)
    XCTAssertEqual(context.store.completedOnboardingVersion, 1)
  }

  func testExternalStatusRefreshReconcilesTheDisplayedValue() {
    let context = makeContext()
    context.login.status = .disabled
    context.controller.refreshLaunchAtLoginStatus()
    XCTAssertFalse(context.controller.isLaunchAtLoginEnabled)

    context.login.status = .enabled
    context.controller.refreshLaunchAtLoginStatus()
    XCTAssertTrue(context.controller.isLaunchAtLoginEnabled)
  }

  func testDevelopmentResetIsTransactional() {
    let context = makeContext(completedOnboardingVersion: 1)
    context.login.status = .enabled
    context.login.statusAfterDisable = .disabled
    context.shortcutStore.captureShortcut = suggestedShortcut

    XCTAssertTrue(context.controller.resetLocalDevelopmentState())
    XCTAssertEqual(context.store.resetCallCount, 1)
    XCTAssertEqual(context.shortcutStore.resetCallCount, 1)
    XCTAssertTrue(context.controller.needsOnboarding)

    context.store.completedOnboardingVersion = 1
    context.shortcutStore.captureShortcut = suggestedShortcut
    context.login.status = .enabled
    context.login.disableError = .injected
    XCTAssertFalse(context.controller.resetLocalDevelopmentState())
    XCTAssertEqual(context.store.completedOnboardingVersion, 1)
    XCTAssertEqual(context.shortcutStore.captureShortcut, suggestedShortcut)
  }

  private var suggestedShortcut: KeyboardShortcuts.Shortcut {
    KeyboardShortcuts.Shortcut(.two, modifiers: [.shift, .command])
  }

  private func makeContext(
    completedOnboardingVersion: Int = 0,
    currentOnboardingVersion: Int = 1
  ) -> Context {
    let store = StubAppSettingsStore(completedOnboardingVersion: completedOnboardingVersion)
    let login = StubLaunchAtLoginService()
    let shortcutStore = StubGlobalShortcutStore()
    let controller = SettingsController(
      settingsStore: store,
      launchAtLoginService: login,
      shortcutStore: shortcutStore,
      currentOnboardingVersion: currentOnboardingVersion
    )
    return Context(
      controller: controller,
      store: store,
      login: login,
      shortcutStore: shortcutStore
    )
  }

  private struct Context {
    let controller: SettingsController
    let store: StubAppSettingsStore
    let login: StubLaunchAtLoginService
    let shortcutStore: StubGlobalShortcutStore
  }
}
