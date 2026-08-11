import SwiftUI

struct CaptureHistoryView: View {
  @Environment(\.openSettings) private var openSettings
  @ObservedObject var controller: CaptureHistoryController

  @State private var selectedID: UUID?
  @State private var isShowingClearConfirmation = false

  private var selectedEntry: CaptureHistoryEntry? {
    guard let selectedID else { return nil }
    return controller.entries.first(where: { $0.id == selectedID })
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      header
      content
    }
    .padding(20)
    .frame(minWidth: 560, idealWidth: 620, minHeight: 400, idealHeight: 460)
    .accessibilityIdentifier("copylasso.history.window")
    .task {
      await controller.openHistory()
      selectFirstEntryIfNeeded()
    }
    .onDisappear {
      controller.closeHistory()
      selectedID = nil
    }
    .onChange(of: controller.entries.map(\.id)) {
      if let selectedID, controller.entries.contains(where: { $0.id == selectedID }) {
        return
      }
      self.selectedID = controller.entries.first?.id
    }
    .alert("Clear Capture History?", isPresented: $isShowingClearConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Clear All", role: .destructive) {
        Task {
          if await controller.clearAll() {
            selectedID = nil
          }
        }
      }
    } message: {
      Text(
        "This removes CopyLasso's active encrypted archive and encryption key, then creates a new key for future captures. APFS snapshots or external backups may retain prior bytes."
      )
    }
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 3) {
        Text("Capture History")
          .font(.title2.weight(.semibold))
          .accessibilityIdentifier("copylasso.history.title")
        Text("Successful captures are kept for seven days, up to 100 entries.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      Spacer()
      if controller.isEnabled {
        Button("Clear All", role: .destructive) {
          isShowingClearConfirmation = true
        }
        .disabled(controller.entries.isEmpty && controller.presentationState != .unavailable)
        .accessibilityIdentifier("copylasso.history.clear-all")
      }
    }
  }

  @ViewBuilder
  private var content: some View {
    switch controller.presentationState {
    case .disabled:
      ContentUnavailableView {
        Label("Capture History Is Off", systemImage: "clock.arrow.circlepath")
          .accessibilityIdentifier("copylasso.history.disabled")
      } description: {
        Text("Turn it on in Privacy settings to save encrypted text and code output locally.")
      } actions: {
        Button("Open Privacy Settings") {
          openSettings()
        }
        .accessibilityIdentifier("copylasso.history.open-settings")
      }
    case .unavailable:
      ContentUnavailableView {
        Label("History Is Unavailable", systemImage: "exclamationmark.lock.fill")
          .accessibilityIdentifier("copylasso.history.unavailable")
      } description: {
        Text("CopyLasso could not authenticate the local archive. No stored content is shown.")
      } actions: {
        Button("Delete Unreadable History", role: .destructive) {
          isShowingClearConfirmation = true
        }
        .accessibilityIdentifier("copylasso.history.delete-unreadable")
      }
    case .locked:
      ContentUnavailableView {
        Label("History Was Locked", systemImage: "lock.fill")
          .accessibilityIdentifier("copylasso.history.locked")
      } description: {
        Text("Saved content was cleared from the window when this Mac locked.")
      } actions: {
        Button("Reload History") {
          Task {
            await controller.openHistory()
            selectFirstEntryIfNeeded()
          }
        }
        .accessibilityIdentifier("copylasso.history.reload")
      }
    case .ready where controller.entries.isEmpty:
      ContentUnavailableView {
        Label("No Saved Captures", systemImage: "clock")
          .accessibilityIdentifier("copylasso.history.empty")
      } description: {
        Text("Successful text and code captures will appear here while history is enabled.")
      }
    case .ready:
      historySplitView
    }
  }

  private var historySplitView: some View {
    HSplitView {
      List(controller.entries, selection: $selectedID) { entry in
        CaptureHistoryRow(entry: entry)
          .tag(entry.id)
      }
      .frame(minWidth: 220, idealWidth: 250)
      .accessibilityLabel("Saved captures, newest first")
      .accessibilityIdentifier("copylasso.history.entries")

      Group {
        if let selectedEntry {
          CaptureHistoryDetail(
            entry: selectedEntry,
            copy: { controller.copy(id: selectedEntry.id) },
            delete: {
              Task {
                if await controller.delete(id: selectedEntry.id) {
                  selectedID = controller.entries.first?.id
                }
              }
            }
          )
        } else {
          ContentUnavailableView("Select a Capture", systemImage: "text.page")
        }
      }
      .frame(minWidth: 300)
    }
    .accessibilityIdentifier("copylasso.history.content")
  }

  private func selectFirstEntryIfNeeded() {
    if selectedID == nil {
      selectedID = controller.entries.first?.id
    }
  }
}

private struct CaptureHistoryRow: View {
  let entry: CaptureHistoryEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Label(
          entry.kind.displayName, systemImage: entry.kind == .code ? "qrcode" : "text.alignleft"
        )
        .font(.caption.weight(.semibold))
        Spacer()
        Text(entry.capturedAt, format: .dateTime.month().day().hour().minute())
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Text(FeedbackPreview(text: entry.content).text)
        .font(.subheadline)
        .lineLimit(2)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("copylasso.history.row")
    .accessibilityLabel(
      "\(entry.kind.displayName), \(entry.capturedAt.formatted(date: .abbreviated, time: .shortened)), \(FeedbackPreview(text: entry.content).text)"
    )
  }
}

private struct CaptureHistoryDetail: View {
  let entry: CaptureHistoryEntry
  let copy: () -> Bool
  let delete: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(entry.kind.displayName)
            .font(.headline)
          Text(entry.capturedAt.formatted(date: .long, time: .standard))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button("Copy") {
          _ = copy()
        }
        .accessibilityHint("Copies the exact saved content without creating a new history entry.")
        .accessibilityIdentifier("copylasso.history.copy")
        Button("Delete", role: .destructive, action: delete)
          .accessibilityIdentifier("copylasso.history.delete")
      }

      ScrollView {
        Text(entry.content)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .textSelection(.enabled)
          .padding(12)
      }
      .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
      .accessibilityLabel("Complete saved content")
      .accessibilityIdentifier("copylasso.history.detail")
    }
    .padding(.leading, 12)
  }
}
