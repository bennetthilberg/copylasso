struct FeedbackPresentationContent: Equatable, Sendable {
  let symbolName: String
  let menuBarAccessibilityLabel: String
  let title: String
  let message: String
  let accessibilityLabel: String

  init(feedback: CaptureFeedback) {
    switch feedback {
    case .success(let preview):
      self.init(
        symbolName: "checkmark.circle.fill",
        menuBarAccessibilityLabel: "CopyLasso, text copied",
        title: "Copied Text",
        message: preview,
        accessibilityLabel: "Copied Text: \(preview)"
      )
    case .noText:
      self.init(
        symbolName: "text.magnifyingglass",
        menuBarAccessibilityLabel: "CopyLasso, no text found",
        title: "No Text Found",
        message: "Try selecting a clearer or larger area.",
        accessibilityLabel: "No Text Found. Try selecting a clearer or larger area."
      )
    case .failure(let stage):
      let message = Self.failureMessage(for: stage)
      self.init(
        symbolName: "exclamationmark.triangle.fill",
        menuBarAccessibilityLabel: "CopyLasso, capture failed",
        title: "Copy Failed",
        message: message,
        accessibilityLabel: "Copy Failed. \(message)"
      )
    }
  }

  init(
    symbolName: String,
    menuBarAccessibilityLabel: String,
    title: String,
    message: String,
    accessibilityLabel: String
  ) {
    self.symbolName = symbolName
    self.menuBarAccessibilityLabel = menuBarAccessibilityLabel
    self.title = title
    self.message = message
    self.accessibilityLabel = accessibilityLabel
  }

  private static func failureMessage(for stage: CaptureFailureStage) -> String {
    switch stage {
    case .permission:
      "Screen Recording access is needed."
    case .selection:
      "The selection could not be completed."
    case .capture:
      "The selected area could not be captured."
    case .recognition:
      "Text recognition could not be completed."
    case .formatting:
      "Recognized text could not be prepared."
    case .clipboard:
      "Text could not be copied to the clipboard."
    case .feedback:
      "CopyLasso could not show the result."
    case .internal:
      "CopyLasso could not complete the capture."
    }
  }
}
