import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class FeedbackPresentationModel {
  private(set) var feedback: CaptureFeedback?
  private(set) var feedbackHUDBackgroundStyle: FeedbackHUDBackgroundStyle = .regularMaterial

  var content: FeedbackPresentationContent? {
    feedback.map(FeedbackPresentationContent.init)
  }

  func present(
    _ feedback: CaptureFeedback,
    backgroundStyle: FeedbackHUDBackgroundStyle
  ) {
    self.feedback = feedback
    feedbackHUDBackgroundStyle = backgroundStyle
  }

  func dismiss() {
    feedback = nil
  }
}

@MainActor
protocol FeedbackPanelHosting: AnyObject {
  func show()
  func hide()
}

@MainActor
final class FeedbackPanelController: FeedbackService {
  typealias PanelFactory = @MainActor (FeedbackPresentationModel) -> any FeedbackPanelHosting
  typealias DismissalWaiter = @MainActor @Sendable () async throws -> Void

  let model = FeedbackPresentationModel()

  private let makePanel: PanelFactory
  private let appearanceProvider: any AccessibilityAppearanceProviding
  private let waitForDismissal: DismissalWaiter
  private var panel: (any FeedbackPanelHosting)?
  private var presentationGeneration: UInt = 0
  private var dismissalTask: Task<Void, any Error>?

  init(
    displayDuration: Duration = .milliseconds(2500),
    appearanceProvider: any AccessibilityAppearanceProviding =
      SystemAccessibilityAppearanceProvider(),
    makePanel: @escaping PanelFactory = { AppKitFeedbackPanelHost(model: $0) },
    waitForDismissal: DismissalWaiter? = nil
  ) {
    self.appearanceProvider = appearanceProvider
    self.makePanel = makePanel
    self.waitForDismissal =
      waitForDismissal
      ?? {
        try await Task.sleep(for: displayDuration)
      }
  }

  func present(_ feedback: CaptureFeedback) async throws {
    presentationGeneration &+= 1
    let generation = presentationGeneration
    model.present(
      feedback,
      backgroundStyle: appearanceProvider.currentAppearance.feedbackHUDBackgroundStyle
    )
    ensurePanel().show()
    let task = Task { @MainActor [waitForDismissal] in
      try await waitForDismissal()
    }
    dismissalTask = task

    do {
      try await task.value
    } catch {
      dismissIfCurrent(generation)
      throw error
    }
    dismissIfCurrent(generation)
  }

  func dismiss() {
    presentationGeneration &+= 1
    dismissalTask?.cancel()
    dismissalTask = nil
    model.dismiss()
    panel?.hide()
  }

  private func ensurePanel() -> any FeedbackPanelHosting {
    if let panel {
      return panel
    }
    let panel = makePanel(model)
    self.panel = panel
    return panel
  }

  private func dismissIfCurrent(_ generation: UInt) {
    guard generation == presentationGeneration else {
      return
    }
    dismissalTask = nil
    model.dismiss()
    panel?.hide()
  }
}

private struct FeedbackHUDView: View {
  @Bindable var model: FeedbackPresentationModel

  var body: some View {
    if let content = model.content {
      HStack(spacing: 14) {
        Image(systemName: content.symbolName)
          .font(.title2)
          .symbolRenderingMode(.hierarchical)

        VStack(alignment: .leading, spacing: 4) {
          Text(content.title)
            .font(.headline)
            .accessibilityIdentifier("copylasso.feedback.title")
          Text(content.message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("copylasso.feedback.message")
        }

        Spacer(minLength: 0)
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 14)
      .frame(width: FeedbackPanelLayout.width, alignment: .leading)
      .background(
        model.feedbackHUDBackgroundStyle.shapeStyle,
        in: RoundedRectangle(cornerRadius: 14)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 14)
          .stroke(.separator.opacity(0.8), lineWidth: 1)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(content.accessibilityLabel)
      .accessibilityIdentifier("copylasso.feedback.hud")
    }
  }
}

extension FeedbackHUDBackgroundStyle {
  fileprivate var shapeStyle: AnyShapeStyle {
    switch self {
    case .regularMaterial:
      AnyShapeStyle(.regularMaterial)
    case .opaqueWindowBackground:
      AnyShapeStyle(
        Color(nsColor: NSColor.windowBackgroundColor.withAlphaComponent(1))
      )
    }
  }
}

@MainActor
private final class AppKitFeedbackPanelHost: FeedbackPanelHosting {
  private let panel: NonactivatingFeedbackPanel
  private let hostingController: NSHostingController<FeedbackHUDView>

  init(model: FeedbackPresentationModel) {
    hostingController = NSHostingController(rootView: FeedbackHUDView(model: model))
    panel = NonactivatingFeedbackPanel(
      contentRect: NSRect(
        x: 0,
        y: 0,
        width: FeedbackPanelLayout.width,
        height: FeedbackPanelLayout.minimumHeight
      ),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.backgroundColor = .clear
    panel.identifier = NSUserInterfaceItemIdentifier("copylasso.feedback.panel")
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    panel.hasShadow = true
    panel.hidesOnDeactivate = false
    panel.ignoresMouseEvents = true
    panel.isFloatingPanel = true
    panel.isOpaque = false
    panel.isReleasedWhenClosed = false
    panel.level = .statusBar
    panel.animationBehavior = .none
    panel.contentViewController = hostingController
  }

  func show() {
    hostingController.view.invalidateIntrinsicContentSize()
    hostingController.view.layoutSubtreeIfNeeded()
    panel.setContentSize(
      NSSize(
        width: FeedbackPanelLayout.width,
        height: FeedbackPanelLayout.contentHeight(
          fittingHeight: hostingController.view.fittingSize.height
        )
      )
    )
    let pointer = NSEvent.mouseLocation
    let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main
    if let visibleFrame = screen?.visibleFrame {
      let origin = NSPoint(
        x: visibleFrame.midX - (panel.frame.width / 2),
        y: visibleFrame.maxY - panel.frame.height - 24
      )
      panel.setFrameOrigin(origin)
    }
    panel.orderFrontRegardless()
  }

  func hide() {
    panel.orderOut(nil)
  }
}

private final class NonactivatingFeedbackPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}
