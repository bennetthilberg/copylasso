import SwiftUI

struct ContentView: View {
  var body: some View {
    VStack(spacing: 8) {
      Text("CopyLasso")
        .font(.title)
        .accessibilityLabel("CopyLasso")
        .accessibilityIdentifier("copylasso.placeholder.title")

      Text("Screen text capture is coming soon.")
        .foregroundStyle(.secondary)
    }
    .padding()
    .frame(minWidth: 320, minHeight: 180)
  }
}

#Preview {
  ContentView()
}
