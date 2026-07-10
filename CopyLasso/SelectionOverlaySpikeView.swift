#if DEBUG
  import AppKit
  import Combine
  import SwiftUI

  @MainActor
  final class SelectionOverlaySpikeModel: ObservableObject {
    @Published private(set) var displays: [LiveDisplayDescriptor] = []
    @Published private(set) var lastOutcome: SelectionOutcome?
    @Published private(set) var focusWasPreserved: Bool?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isWaiting = false
    @Published private(set) var isSelecting = false

    private var overlayController: SelectionOverlayController?
    private var delayedTask: Task<Void, Never>?

    init() {
      refreshDisplays()
    }

    var screensHaveSeparateSpaces: Bool {
      NSScreen.screensHaveSeparateSpaces
    }

    func beginNow() {
      delayedTask?.cancel()
      delayedTask = nil
      isWaiting = false
      guard overlayController == nil else { return }

      refreshDisplays()
      let frontmostProcessIdentifier = NSWorkspace.shared.frontmostApplication?.processIdentifier
      do {
        let controller = try SelectionOverlayController { [weak self] outcome in
          guard let self else { return }
          lastOutcome = outcome
          let currentIdentifier = NSWorkspace.shared.frontmostApplication?.processIdentifier
          focusWasPreserved = frontmostProcessIdentifier == currentIdentifier
          isSelecting = false
          overlayController = nil
          refreshDisplays()
        }
        overlayController = controller
        isSelecting = true
        errorMessage = nil
        controller.start()
      } catch {
        errorMessage = error.localizedDescription
        isSelecting = false
      }
    }

    func beginAfterFiveSeconds() {
      guard overlayController == nil, delayedTask == nil else { return }
      isWaiting = true
      errorMessage = nil
      delayedTask = Task { @MainActor [weak self] in
        do {
          try await Task.sleep(for: .seconds(5))
        } catch {
          return
        }
        guard let self else { return }
        delayedTask = nil
        isWaiting = false
        beginNow()
      }
    }

    func stop() {
      delayedTask?.cancel()
      delayedTask = nil
      isWaiting = false
      overlayController?.cancelWithEscape()
    }

    private func refreshDisplays() {
      do {
        displays = try LiveDisplayDescriptor.current()
        errorMessage = nil
      } catch {
        displays = []
        errorMessage = error.localizedDescription
      }
    }
  }

  struct SelectionOverlaySpikeView: View {
    @StateObject private var model = SelectionOverlaySpikeModel()

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text("G07 Selection Overlay Spike")
            .font(.title)
            .accessibilityIdentifier("copylasso.selection-spike.title")

          Text(
            "Debug-only geometry proof. The overlay does not capture pixels, run OCR, or change the clipboard."
          )
          .foregroundStyle(.secondary)

          calibrationCard

          HStack {
            Button("Begin Selection Now") {
              model.beginNow()
            }
            .accessibilityIdentifier("copylasso.selection-spike.begin-now")

            Button("Begin in 5 Seconds") {
              model.beginAfterFiveSeconds()
            }
            .accessibilityIdentifier("copylasso.selection-spike.begin-delayed")
          }
          .disabled(model.isSelecting || model.isWaiting)

          if model.isWaiting {
            ProgressView("Selection begins in 5 seconds…")
          } else if model.isSelecting {
            Text("Drag on any display, or press Escape to cancel.")
              .foregroundStyle(.secondary)
          }

          displayInventory
          outcomeView

          if let errorMessage = model.errorMessage {
            Text(errorMessage)
              .foregroundStyle(.red)
              .accessibilityIdentifier("copylasso.selection-spike.error")
          }
        }
        .padding(20)
      }
      .frame(minWidth: 860, minHeight: 700)
      .task {
        NSApplication.shared.windows.first?.center()
      }
      .onDisappear {
        model.stop()
      }
    }

    private var calibrationCard: some View {
      HStack(spacing: 0) {
        VStack(spacing: 0) {
          Rectangle().fill(.blue)
          Rectangle().fill(.orange)
        }
        VStack(spacing: 0) {
          Rectangle().fill(.green)
          Rectangle().fill(.purple)
        }
        Text("COPYLASSO\nG07\n320 × 180 pt")
          .font(.system(size: 20, weight: .bold, design: .monospaced))
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(.white)
          .foregroundStyle(.black)
      }
      .frame(width: 320, height: 180)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(RoundedRectangle(cornerRadius: 8).stroke(.primary, lineWidth: 2))
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("CopyLasso G07 calibration card, 320 by 180 points")
      .accessibilityIdentifier("copylasso.selection-spike.calibration")
    }

    private var displayInventory: some View {
      GroupBox("Current displays") {
        VStack(alignment: .leading, spacing: 10) {
          Text("Separate Spaces: \(model.screensHaveSeparateSpaces ? "enabled" : "disabled")")
          ForEach(model.displays) { display in
            Text(displaySummary(display))
              .font(.system(.caption, design: .monospaced))
              .textSelection(.enabled)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }

    @ViewBuilder
    private var outcomeView: some View {
      GroupBox("Last outcome") {
        if let outcome = model.lastOutcome {
          VStack(alignment: .leading, spacing: 6) {
            switch outcome {
            case .selected(let result):
              Text("Selected display ID: \(result.displayID)")
                .accessibilityIdentifier("copylasso.selection-spike.selected")
              rectRow("AppKit global", result.appKitGlobalRect)
              rectRow("Display local", result.displayLocalRect)
              rectRow("Core Graphics global", result.coreGraphicsGlobalRect)
              rectRow("Core Graphics local", result.coreGraphicsDisplayLocalRect)
              rectRow("Backing pixels", result.backingPixelRect)
            case .cancelled(let reason):
              Text("Cancelled: \(reason.rawValue)")
                .accessibilityIdentifier("copylasso.selection-spike.cancelled")
            }
            if let focusWasPreserved = model.focusWasPreserved {
              Text("Frontmost application preserved: \(focusWasPreserved ? "yes" : "no")")
            }
          }
          .font(.system(.body, design: .monospaced))
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
        } else {
          Text("No selection has been attempted.")
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("copylasso.selection-spike.no-outcome")
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }

    private func rectRow(_ label: String, _ rect: CGRect) -> some View {
      Text("\(label): \(format(rect))")
    }

    private func displaySummary(_ display: LiveDisplayDescriptor) -> String {
      let geometry = display.geometry
      return
        "\(display.name) | ID \(display.id) | AppKit \(format(geometry.appKitFrame)) | CG \(format(geometry.coreGraphicsBounds)) | scale \(format(geometry.backingScale))× | backing check \(format(display.backingConversionScale))× \(display.backingScaleMatchesConversion ? "match" : "MISMATCH")"
    }

    private func format(_ rect: CGRect) -> String {
      String(
        format: "x %.2f, y %.2f, w %.2f, h %.2f",
        locale: Locale(identifier: "en_US_POSIX"),
        rect.origin.x,
        rect.origin.y,
        rect.width,
        rect.height
      )
    }

    private func format(_ value: CGFloat) -> String {
      String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
  }
#endif
