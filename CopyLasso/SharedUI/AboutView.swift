import AppKit
import SwiftUI

@MainActor
struct ApplicationIconSource {
  private let imageLoader: () -> NSImage

  init(_ imageLoader: @escaping () -> NSImage) {
    self.imageLoader = imageLoader
  }

  func load() -> NSImage {
    imageLoader()
  }

  static let application = ApplicationIconSource {
    NSApp.applicationIconImage
  }
}

struct AboutView: View {
  let metadata: AboutMetadata
  let applicationIconSource: ApplicationIconSource

  @State private var isShowingAcknowledgements = false

  var body: some View {
    VStack(spacing: 10) {
      DeferredApplicationIconView(source: applicationIconSource)
        .frame(width: 80, height: 80)
        .accessibilityLabel("CopyLasso app icon")
        .accessibilityIdentifier("copylasso.about.icon")

      Text(metadata.applicationName)
        .font(.title2.weight(.semibold))
        .accessibilityIdentifier("copylasso.about.title")

      Text(metadata.versionDescription)
        .foregroundStyle(.secondary)
        .accessibilityLabel(metadata.versionDescription)
        .accessibilityIdentifier("copylasso.about.version")

      Text(metadata.summary)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      Text(metadata.creatorDescription)
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityLabel(metadata.creatorDescription)
        .accessibilityIdentifier("copylasso.about.creator")

      HStack(spacing: 16) {
        Link("Project Repository", destination: metadata.repositoryURL)
          .accessibilityIdentifier("copylasso.about.repository")
        Link(metadata.licenseName, destination: metadata.licenseURL)
          .accessibilityIdentifier("copylasso.about.license")
      }

      Button("Acknowledgements…") {
        isShowingAcknowledgements = true
      }
      .accessibilityHint("Shows licenses for open-source software included with CopyLasso.")
      .accessibilityIdentifier("copylasso.about.acknowledgements")
    }
    .padding(24)
    .frame(minWidth: 420, idealWidth: 420)
    .sheet(isPresented: $isShowingAcknowledgements) {
      AcknowledgementsView(acknowledgements: metadata.acknowledgements)
    }
  }
}

private struct DeferredApplicationIconView: NSViewRepresentable {
  let source: ApplicationIconSource

  func makeNSView(context: Context) -> NSImageView {
    let imageView = NSImageView()
    imageView.image = source.load()
    imageView.imageScaling = .scaleProportionallyUpOrDown
    return imageView
  }

  func updateNSView(_ imageView: NSImageView, context: Context) {}
}

private struct AcknowledgementsView: View {
  @Environment(\.dismiss) private var dismiss

  let acknowledgements: [AboutAcknowledgement]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Third-Party Acknowledgements")
        .font(.title2.weight(.semibold))
        .accessibilityIdentifier("copylasso.about.acknowledgements.title")

      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          ForEach(Array(acknowledgements.enumerated()), id: \.element.title) { index, item in
            Text(item.title)
              .font(.headline)
              .accessibilityIdentifier("copylasso.about.acknowledgement.\(index)")
            Text("\(item.author) · \(item.license)")
              .foregroundStyle(.secondary)
            Text(item.notice)
              .font(.system(.caption, design: .monospaced))
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
              .accessibilityLabel("\(item.title) license notice")
            if index < acknowledgements.count - 1 {
              Divider()
            }
          }
        }
      }

      HStack {
        Spacer()
        Button("Done") {
          dismiss()
        }
        .keyboardShortcut(.defaultAction)
        .accessibilityIdentifier("copylasso.about.acknowledgements.done")
      }
    }
    .padding(20)
    .frame(width: 560, height: 460)
  }
}

#Preview {
  AboutView(
    metadata: AboutMetadata(
      infoDictionary: [
        "CFBundleShortVersionString": "0.1.1",
        "CFBundleVersion": "2",
      ]
    ),
    applicationIconSource: ApplicationIconSource {
      NSImage(named: NSImage.applicationIconName) ?? NSImage()
    }
  )
}
