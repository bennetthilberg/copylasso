import SwiftUI

struct SettingsPlaceholderView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("CopyLasso Settings")
        .font(.title2)
        .accessibilityIdentifier("copylasso.settings.title")

      Text("Settings are not available in this pre-release build.")
        .foregroundStyle(.secondary)
    }
    .padding(24)
    .frame(width: 420, height: 160, alignment: .topLeading)
  }
}

#Preview {
  SettingsPlaceholderView()
}
