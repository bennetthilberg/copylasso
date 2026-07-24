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
    case .noContent:
      self.init(
        symbolName: "text.magnifyingglass",
        menuBarAccessibilityLabel: "CopyLasso, no text or code found",
        title: "No Text or Code Found",
        message: "Try selecting a clearer or larger area around the content.",
        accessibilityLabel:
          "No Text or Code Found. Try selecting a clearer or larger area around the content."
      )
    case .codeSuccess(let preview):
      self.init(
        symbolName: "checkmark.circle.fill",
        menuBarAccessibilityLabel: "CopyLasso, code copied",
        title: "Copied Code",
        message: preview,
        accessibilityLabel: "Copied Code: \(preview)"
      )
    case .ambiguousCodes:
      self.init(
        symbolName: "exclamationmark.triangle.fill",
        menuBarAccessibilityLabel: "CopyLasso, capture codes separately",
        title: "Capture Codes Separately",
        message: "The selection contains multiple codes with multiline content.",
        accessibilityLabel:
          "Capture Codes Separately. The selection contains multiple codes with multiline content."
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
      "Text and code recognition could not be completed."
    case .formatting:
      "Recognized content could not be prepared."
    case .clipboard:
      "Recognized content could not be copied to the clipboard."
    case .feedback:
      "CopyLasso could not show the result."
    case .internal:
      "CopyLasso could not complete the capture."
    }
  }

}
