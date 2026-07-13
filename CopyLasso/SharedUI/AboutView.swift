import SwiftUI

struct AboutView: View {
  let metadata: AboutMetadata

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "viewfinder")
        .font(.system(size: 32))
        .accessibilityHidden(true)

      Text("CopyLasso")
        .font(.title2)
        .accessibilityIdentifier("copylasso.about.title")

      Text(metadata.versionDescription)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("copylasso.about.version")

      Text("Pre-release · Free, open source, private, and local")
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(24)
    .frame(minWidth: 360, idealWidth: 360)
  }
}

#Preview {
  AboutView(
    metadata: AboutMetadata(
      infoDictionary: [
        "CFBundleShortVersionString": "0.1.0",
        "CFBundleVersion": "1",
      ]
    )
  )
}
