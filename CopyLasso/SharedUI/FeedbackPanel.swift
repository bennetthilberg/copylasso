import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class FeedbackPresentationModel {
  private(set) var feedback: CaptureFeedback?

  var content: FeedbackPresentationContent? {
    feedback.map(FeedbackPresentationContent.init)
  }

  func present(_ feedback: CaptureFeedback) {
    self.feedback = feedback
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
  private let waitForDismissal: DismissalWaiter
  private var panel: (any FeedbackPanelHosting)?
  private var presentationGeneration: UInt = 0

  init(
    displayDuration: Duration = .milliseconds(2500),
    makePanel: @escaping PanelFactory = { AppKitFeedbackPanelHost(model: $0) },
    waitForDismissal: DismissalWaiter? = nil
  ) {
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
    model.present(feedback)
    ensurePanel().show()

    do {
      try await waitForDismissal()
    } catch {
      dismissIfCurrent(generation)
      throw error
    }
    dismissIfCurrent(generation)
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
            .lineLimit(2)
            .accessibilityIdentifier("copylasso.feedback.message")
        }

        Spacer(minLength: 0)
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 14)
      .frame(width: 440, height: 104)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
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

@MainActor
private final class AppKitFeedbackPanelHost: FeedbackPanelHosting {
  private let panel: NonactivatingFeedbackPanel

  init(model: FeedbackPresentationModel) {
    panel = NonactivatingFeedbackPanel(
      contentRect: NSRect(x: 0, y: 0, width: 440, height: 104),
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
    panel.animationBehavior = .utilityWindow
    panel.contentViewController = NSHostingController(rootView: FeedbackHUDView(model: model))
  }

  func show() {
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
