import SwiftUI

struct LaunchAtLoginStatusView: View {
  let status: LaunchAtLoginStatus
  let issue: LaunchAtLoginIssue?
  let openSystemSettings: () -> Void

  var body: some View {
    Label(statusMessage, systemImage: statusSymbol)
      .foregroundStyle(.secondary)
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("copylasso.login.status")

    if let issue {
      VStack(alignment: .leading, spacing: 6) {
        Text(issueMessage(for: issue))
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("copylasso.login.issue")

        if issue == .requiresApproval {
          Button("Open Login Items") {
            openSystemSettings()
          }
          .accessibilityIdentifier("copylasso.login.open-settings")
        }
      }
    }
  }

  private var statusMessage: String {
    switch status {
    case .disabled:
      "Launch at Login is disabled."
    case .enabled:
      "Launch at Login is enabled."
    case .requiresApproval:
      "Launch at Login is inactive until macOS approval is granted."
    case .unavailable:
      "Launch at Login is unavailable."
    }
  }

  private var statusSymbol: String {
    switch status {
    case .enabled:
      "checkmark.circle"
    case .disabled:
      "minus.circle"
    case .requiresApproval, .unavailable:
      "exclamationmark.triangle"
    }
  }

  private func issueMessage(for issue: LaunchAtLoginIssue) -> String {
    switch issue {
    case .requiresApproval:
      "macOS approval is required before CopyLasso can launch at login."
    case .unavailable:
      "Launch at Login is unavailable for this copy of CopyLasso."
    case .enableFailed:
      "CopyLasso could not enable Launch at Login. Nothing else was changed."
    case .disableFailed:
      "CopyLasso could not disable Launch at Login. Its current system state is shown above."
    }
  }
}
