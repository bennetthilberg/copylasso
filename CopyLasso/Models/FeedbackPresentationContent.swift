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
    case .codeSuccess(let preview):
      self.init(
        symbolName: "checkmark.circle.fill",
        menuBarAccessibilityLabel: "CopyLasso, code copied",
        title: "Copied Code",
        message: preview,
        accessibilityLabel: "Copied Code: \(preview)"
      )
    case .noCode:
      self.init(
        symbolName: "barcode.viewfinder",
        menuBarAccessibilityLabel: "CopyLasso, no code found",
        title: "No Code Found",
        message: "Try selecting a clearer or larger area around the code.",
        accessibilityLabel:
          "No Code Found. Try selecting a clearer or larger area around the code."
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
    case .codeFailure(let stage):
      let message = Self.codeFailureMessage(for: stage)
      self.init(
        symbolName: "exclamationmark.triangle.fill",
        menuBarAccessibilityLabel: "CopyLasso, code capture failed",
        title: "Code Capture Failed",
        message: message,
        accessibilityLabel: "Code Capture Failed. \(message)"
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

  private static func codeFailureMessage(for stage: CaptureFailureStage) -> String {
    switch stage {
    case .permission:
      "Screen Recording access is needed."
    case .selection:
      "The code selection could not be completed."
    case .capture:
      "The selected area could not be captured."
    case .recognition:
      "Code recognition could not be completed."
    case .formatting:
      "Recognized code payloads could not be prepared."
    case .clipboard:
      "The code payload could not be copied to the clipboard."
    case .feedback:
      "CopyLasso could not show the code result."
    case .internal:
      "CopyLasso could not complete the code capture."
    }
  }
}
