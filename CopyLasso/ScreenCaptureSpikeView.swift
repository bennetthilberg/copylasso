#if DEBUG
  import AppKit
  import SwiftUI

  struct ScreenCaptureSpikeView: View {
    @StateObject private var model = ScreenCaptureSpikeModel.live()

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text("G06 Screen Capture Spike")
            .font(.title)
            .accessibilityIdentifier("copylasso.capture-spike.title")

          Text(
            "Debug-only proof. Captures remain in memory and disappear when cleared or when the app exits."
          )
          .foregroundStyle(.secondary)

          calibrationCard

          GroupBox("Permission observation") {
            Text(model.authorizationObservation.message)
              .frame(maxWidth: .infinity, alignment: .leading)
              .accessibilityIdentifier("copylasso.capture-spike.permission")
          }

          HStack {
            Button("Request and Capture") {
              Task { await model.requestAndCapture() }
            }
            .accessibilityIdentifier("copylasso.capture-spike.request")

            Button("Capture Again") {
              Task { await model.captureAgain() }
            }
            .accessibilityIdentifier("copylasso.capture-spike.capture-again")

            Button("Clear Preview") {
              model.clearPreview()
            }
            .accessibilityIdentifier("copylasso.capture-spike.clear")

            Button("Reset Local History") {
              model.resetLocalHistory()
            }
            .accessibilityIdentifier("copylasso.capture-spike.reset-history")
          }
          .disabled(model.isBusy)

          if model.isBusy {
            ProgressView("Capturing…")
          }

          if let error = model.lastError {
            Text(error.localizedDescription)
              .foregroundStyle(.red)
              .accessibilityIdentifier("copylasso.capture-spike.error")
          }

          if let image = model.previewImage {
            GroupBox("In-memory preview — \(image.width) × \(image.height) pixels") {
              Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 280)
                .accessibilityIdentifier("copylasso.capture-spike.preview")
            }
          } else {
            Text("No image is retained.")
              .foregroundStyle(.secondary)
              .accessibilityIdentifier("copylasso.capture-spike.no-preview")
          }
        }
        .padding(20)
      }
      .frame(minWidth: 760, minHeight: 620)
      .task {
        NSApplication.shared.windows.first?.center()
      }
    }

    private var calibrationCard: some View {
      HStack(spacing: 0) {
        Rectangle().fill(.blue)
        Rectangle().fill(.orange)
        Rectangle().fill(.green)
        Text("COPYLASSO G06")
          .font(.system(size: 28, weight: .bold, design: .monospaced))
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(.white)
          .foregroundStyle(.black)
      }
      .frame(height: 96)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(RoundedRectangle(cornerRadius: 8).stroke(.primary, lineWidth: 2))
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Blue, orange, and green calibration card labeled CopyLasso G06")
    }
  }
#endif
