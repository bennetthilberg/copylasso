import AppKit
import XCTest

@testable import CopyLasso

@MainActor
final class FeedbackPanelControllerTests: XCTestCase {
  func testContentDistinguishesSuccessNoTextAndFailureWithoutRawErrors() {
    XCTAssertEqual(
      FeedbackPresentationContent(feedback: .success(preview: "known preview")),
      FeedbackPresentationContent(
        symbolName: "checkmark.circle.fill",
        menuBarAccessibilityLabel: "CopyLasso, text copied",
        title: "Copied Text",
        message: "known preview",
        accessibilityLabel: "Copied Text: known preview"
      )
    )
    XCTAssertEqual(
      FeedbackPresentationContent(feedback: .noText),
      FeedbackPresentationContent(
        symbolName: "text.magnifyingglass",
        menuBarAccessibilityLabel: "CopyLasso, no text found",
        title: "No Text Found",
        message: "Try selecting a clearer or larger area.",
        accessibilityLabel: "No Text Found. Try selecting a clearer or larger area."
      )
    )
    XCTAssertEqual(
      FeedbackPresentationContent(feedback: .failure(.recognition)),
      FeedbackPresentationContent(
        symbolName: "exclamationmark.triangle.fill",
        menuBarAccessibilityLabel: "CopyLasso, capture failed",
        title: "Copy Failed",
        message: "Text recognition could not be completed.",
        accessibilityLabel: "Copy Failed. Text recognition could not be completed."
      )
    )
  }

  func testEveryFailureStageUsesBoundedUserSafeGenericContent() {
    let stages: [CaptureFailureStage] = [
      .permission, .selection, .capture, .recognition, .formatting, .clipboard, .feedback,
      .internal,
    ]

    for stage in stages {
      let content = FeedbackPresentationContent(feedback: .failure(stage))
      XCTAssertEqual(content.title, "Copy Failed")
      XCTAssertEqual(content.symbolName, "exclamationmark.triangle.fill")
      XCTAssertEqual(content.menuBarAccessibilityLabel, "CopyLasso, capture failed")
      XCTAssertFalse(content.message.isEmpty)
      XCTAssertLessThanOrEqual(content.message.count, FeedbackPreview.maximumCharacterCount)
      XCTAssertFalse(content.message.localizedCaseInsensitiveContains("error domain"))
      XCTAssertFalse(content.message.localizedCaseInsensitiveContains("underlying"))
    }
  }

  func testPresentationUsesOneHostAndReleasesPreviewAfterAutomaticDismissal() async throws {
    let host = SpyFeedbackPanelHost()
    let waiter = ManualFeedbackWaiter()
    let controller = FeedbackPanelController(
      makePanel: { _ in host },
      waitForDismissal: waiter.wait
    )
    try controller.present(.success(preview: "private transient preview"))
    await waiter.waitUntilCallCount(1)

    XCTAssertEqual(host.showCallCount, 1)
    XCTAssertEqual(controller.model.feedback, .success(preview: "private transient preview"))
    XCTAssertEqual(controller.model.content?.message, "private transient preview")

    waiter.resumeCall(at: 0)
    await waitUntilDismissed(controller)

    XCTAssertEqual(host.hideCallCount, 1)
    XCTAssertNil(controller.model.feedback)
    XCTAssertNil(controller.model.content)

    try controller.present(.noText)
    await waiter.waitUntilCallCount(2)
    XCTAssertEqual(host.showCallCount, 2)
    waiter.resumeCall(at: 1)
    await waitUntilDismissed(controller)
    XCTAssertEqual(host.hideCallCount, 2)
  }

  func testReusedHostRefreshesBackgroundStyleFromCurrentAccessibilityAppearance()
    async throws
  {
    let appearanceProvider = MutableAccessibilityAppearanceProvider(
      currentAppearance: AccessibilityAppearance(
        increaseContrast: false,
        differentiateWithoutColor: false,
        reduceTransparency: false,
        reduceMotion: false
      )
    )
    let host = SpyFeedbackPanelHost()
    let waiter = ManualFeedbackWaiter()
    var makePanelCallCount = 0
    let controller = FeedbackPanelController(
      appearanceProvider: appearanceProvider,
      makePanel: { _ in
        makePanelCallCount += 1
        return host
      },
      waitForDismissal: waiter.wait
    )

    try controller.present(.noText)
    await waiter.waitUntilCallCount(1)
    XCTAssertEqual(controller.model.feedbackHUDBackgroundStyle, .regularMaterial)
    XCTAssertEqual(makePanelCallCount, 1)
    waiter.resumeCall(at: 0)
    await waitUntilDismissed(controller)

    appearanceProvider.currentAppearance = AccessibilityAppearance(
      increaseContrast: false,
      differentiateWithoutColor: false,
      reduceTransparency: true,
      reduceMotion: false
    )
    try controller.present(.failure(.feedback))
    await waiter.waitUntilCallCount(2)

    XCTAssertEqual(
      controller.model.feedbackHUDBackgroundStyle,
      .opaqueWindowBackground
    )
    XCTAssertEqual(makePanelCallCount, 1)
    XCTAssertEqual(host.showCallCount, 2)

    waiter.resumeCall(at: 1)
    await waitUntilDismissed(controller)
  }

  func testOlderDismissalCannotHideANewerPresentation() async throws {
    let host = SpyFeedbackPanelHost()
    let waiter = ManualFeedbackWaiter()
    let controller = FeedbackPanelController(
      makePanel: { _ in host },
      waitForDismissal: waiter.wait
    )
    try controller.present(.success(preview: "first"))
    await waiter.waitUntilCallCount(1)
    try controller.present(.noText)
    await waiter.waitUntilCallCount(2)

    await Task.yield()
    XCTAssertEqual(controller.model.feedback, .noText)
    XCTAssertEqual(host.hideCallCount, 0)

    waiter.resumeCall(at: 1)
    await waitUntilDismissed(controller)
    XCTAssertNil(controller.model.feedback)
    XCTAssertEqual(host.hideCallCount, 1)
    XCTAssertEqual(host.showCallCount, 2)
  }

  func testWaitFailureCleansUpThePanelAndPreview() async {
    let host = SpyFeedbackPanelHost()
    let controller = FeedbackPanelController(
      makePanel: { _ in host },
      waitForDismissal: { throw TestServiceError.injected }
    )

    XCTAssertNoThrow(try controller.present(.failure(.clipboard)))
    await waitUntilDismissed(controller)
    XCTAssertNil(controller.model.feedback)
    XCTAssertEqual(host.showCallCount, 1)
    XCTAssertEqual(host.hideCallCount, 1)
  }

  func testExplicitDismissHidesEveryFeedbackKindImmediatelyAndCancelsTheActiveWait() async {
    let feedbackCases: [CaptureFeedback] = [
      .success(preview: "first"),
      .noText,
      .failure(.recognition),
    ]

    for feedback in feedbackCases {
      let host = SpyFeedbackPanelHost()
      let waiter = ManualFeedbackWaiter()
      let controller = FeedbackPanelController(
        makePanel: { _ in host },
        waitForDismissal: waiter.wait
      )
      XCTAssertNoThrow(try controller.present(feedback))
      await waiter.waitUntilCallCount(1)

      controller.dismiss()

      XCTAssertNil(controller.model.feedback)
      XCTAssertEqual(host.hideCallCount, 1)
      await Task.yield()
    }
  }

  func testProductionPanelIsVisibleNonactivatingAndMouseTransparentWithoutChangingFocus()
    async throws
  {
    let frontmostProcess = NSWorkspace.shared.frontmostApplication?.processIdentifier
    let waiter = ManualFeedbackWaiter()
    let controller = FeedbackPanelController(waitForDismissal: waiter.wait)
    try controller.present(.success(preview: "accessible preview"))
    await waiter.waitUntilCallCount(1)

    let panel = try XCTUnwrap(
      NSApp.windows.first(where: { $0.identifier?.rawValue == "copylasso.feedback.panel" })
        as? NSPanel
    )
    XCTAssertTrue(panel.isVisible)
    XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
    XCTAssertFalse(panel.canBecomeKey)
    XCTAssertFalse(panel.canBecomeMain)
    XCTAssertTrue(panel.ignoresMouseEvents)
    XCTAssertEqual(panel.level, .statusBar)
    XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
    XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary))
    XCTAssertTrue(panel.collectionBehavior.contains(.ignoresCycle))
    XCTAssertEqual(panel.animationBehavior, .none)
    XCTAssertEqual(
      NSWorkspace.shared.frontmostApplication?.processIdentifier,
      frontmostProcess
    )

    waiter.resumeCall(at: 0)
    await waitUntilDismissed(controller)
    XCTAssertFalse(panel.isVisible)
    XCTAssertNil(controller.model.feedback)
  }

  func testProductionPanelExpandsVerticallyForWrappedPreviewInsteadOfClipping() async throws {
    let waiter = ManualFeedbackWaiter()
    let controller = FeedbackPanelController(waitForDismissal: waiter.wait)
    let preview = String(
      repeating: "Readable enlarged preview content ",
      count: 8
    )
    try controller.present(.success(preview: preview))
    await waiter.waitUntilCallCount(1)

    let panel = try XCTUnwrap(
      NSApp.windows.first(where: { $0.identifier?.rawValue == "copylasso.feedback.panel" })
        as? NSPanel
    )
    XCTAssertGreaterThan(panel.contentLayoutRect.height, FeedbackPanelLayout.minimumHeight)
    XCTAssertGreaterThanOrEqual(
      panel.contentLayoutRect.height,
      try XCTUnwrap(panel.contentViewController?.view.fittingSize.height)
    )

    waiter.resumeCall(at: 0)
    await waitUntilDismissed(controller)
  }

  private func waitUntilDismissed(_ controller: FeedbackPanelController) async {
    for _ in 0..<100 where controller.model.feedback != nil {
      await Task.yield()
    }
    XCTAssertNil(controller.model.feedback)
  }
}

@MainActor
private final class SpyFeedbackPanelHost: FeedbackPanelHosting {
  private(set) var showCallCount = 0
  private(set) var hideCallCount = 0

  func show() {
    showCallCount += 1
  }

  func hide() {
    hideCallCount += 1
  }
}

@MainActor
private final class MutableAccessibilityAppearanceProvider: AccessibilityAppearanceProviding {
  var currentAppearance: AccessibilityAppearance

  init(currentAppearance: AccessibilityAppearance) {
    self.currentAppearance = currentAppearance
  }
}

@MainActor
private final class ManualFeedbackWaiter {
  private var continuations: [CheckedContinuation<Void, Error>] = []

  var wait: FeedbackPanelController.DismissalWaiter {
    { [weak self] in
      guard let self else { return }
      let index = continuations.count
      try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
          continuations.append(continuation)
        }
      } onCancel: {
        Task { @MainActor [weak self] in
          self?.cancelCall(at: index)
        }
      }
    }
  }

  func waitUntilCallCount(_ count: Int) async {
    while continuations.count < count {
      await Task.yield()
    }
  }

  func resumeCall(at index: Int) {
    continuations[index].resume()
  }

  private func cancelCall(at index: Int) {
    guard continuations.indices.contains(index) else { return }
    continuations[index].resume(throwing: CancellationError())
  }
}
