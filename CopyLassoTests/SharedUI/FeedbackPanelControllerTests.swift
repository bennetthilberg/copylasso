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
    let task = Task { @MainActor in
      try await controller.present(.success(preview: "private transient preview"))
    }
    await waiter.waitUntilCallCount(1)

    XCTAssertEqual(host.showCallCount, 1)
    XCTAssertEqual(controller.model.feedback, .success(preview: "private transient preview"))
    XCTAssertEqual(controller.model.content?.message, "private transient preview")

    waiter.resumeCall(at: 0)
    try await task.value

    XCTAssertEqual(host.hideCallCount, 1)
    XCTAssertNil(controller.model.feedback)
    XCTAssertNil(controller.model.content)

    let second = Task { @MainActor in
      try await controller.present(.noText)
    }
    await waiter.waitUntilCallCount(2)
    XCTAssertEqual(host.showCallCount, 2)
    waiter.resumeCall(at: 1)
    try await second.value
    XCTAssertEqual(host.hideCallCount, 2)
  }

  func testOlderDismissalCannotHideANewerPresentation() async throws {
    let host = SpyFeedbackPanelHost()
    let waiter = ManualFeedbackWaiter()
    let controller = FeedbackPanelController(
      makePanel: { _ in host },
      waitForDismissal: waiter.wait
    )
    let first = Task { @MainActor in
      try await controller.present(.success(preview: "first"))
    }
    await waiter.waitUntilCallCount(1)
    let second = Task { @MainActor in
      try await controller.present(.noText)
    }
    await waiter.waitUntilCallCount(2)

    waiter.resumeCall(at: 0)
    try await first.value
    XCTAssertEqual(controller.model.feedback, .noText)
    XCTAssertEqual(host.hideCallCount, 0)

    waiter.resumeCall(at: 1)
    try await second.value
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

    do {
      try await controller.present(.failure(.clipboard))
      XCTFail("Expected feedback wait to fail")
    } catch {
      XCTAssertEqual(error as? TestServiceError, .injected)
    }
    XCTAssertNil(controller.model.feedback)
    XCTAssertEqual(host.showCallCount, 1)
    XCTAssertEqual(host.hideCallCount, 1)
  }

  func testProductionPanelIsVisibleNonactivatingAndMouseTransparentWithoutChangingFocus()
    async throws
  {
    let frontmostProcess = NSWorkspace.shared.frontmostApplication?.processIdentifier
    let waiter = ManualFeedbackWaiter()
    let controller = FeedbackPanelController(waitForDismissal: waiter.wait)
    let task = Task { @MainActor in
      try await controller.present(.success(preview: "accessible preview"))
    }
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
    try await task.value
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
    let task = Task { @MainActor in
      try await controller.present(.success(preview: preview))
    }
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
    try await task.value
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
private final class ManualFeedbackWaiter {
  private var continuations: [CheckedContinuation<Void, Error>] = []

  var wait: FeedbackPanelController.DismissalWaiter {
    { [weak self] in
      guard let self else { return }
      try await withCheckedThrowingContinuation { continuation in
        continuations.append(continuation)
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
}
