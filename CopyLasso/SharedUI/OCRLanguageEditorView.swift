import SwiftUI

struct OCRLanguageEditorView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var draft: OCRLanguageSelectionDraft

  let onSave: ([String]) -> Void

  init(
    options: [OCRLanguageOption],
    selectedLanguageIdentifiers: [String],
    onSave: @escaping ([String]) -> Void
  ) {
    _draft = State(
      initialValue: OCRLanguageSelectionDraft(
        options: options,
        selectedLanguageIdentifiers: selectedLanguageIdentifiers
      )
    )
    self.onSave = onSave
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Text Languages")
          .font(.title2.weight(.semibold))
          .accessibilityIdentifier("copylasso.languages.title")
        Text("CopyLasso checks selected languages in priority order.")
          .foregroundStyle(.secondary)
      }

      TextField("Search languages", text: $draft.searchText)
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel("Search text languages")
        .accessibilityIdentifier("copylasso.languages.search")

      List {
        Section("Recognition Priority") {
          ForEach(Array(draft.selectedOptions.enumerated()), id: \.element.identifier) {
            index, option in
            HStack(spacing: 10) {
              VStack(alignment: .leading, spacing: 1) {
                Text(option.displayName)
                Text(option.identifier)
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Button {
                draft.move(option.identifier, by: -1)
              } label: {
                Image(systemName: "chevron.up")
              }
              .buttonStyle(.borderless)
              .disabled(index == 0)
              .accessibilityLabel("Move \(option.displayName) earlier")

              Button {
                draft.move(option.identifier, by: 1)
              } label: {
                Image(systemName: "chevron.down")
              }
              .buttonStyle(.borderless)
              .disabled(index == draft.selectedOptions.count - 1)
              .accessibilityLabel("Move \(option.displayName) later")

              Button {
                draft.remove(option.identifier)
              } label: {
                Image(systemName: "minus.circle")
              }
              .buttonStyle(.borderless)
              .disabled(draft.selectedOptions.count == 1)
              .accessibilityLabel("Remove \(option.displayName)")
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("copylasso.languages.selected.\(option.identifier)")
          }
        }

        Section("Available Languages") {
          if draft.availableOptions.isEmpty {
            Text(draft.searchText.isEmpty ? "All languages are selected." : "No matches.")
              .foregroundStyle(.secondary)
          } else {
            ForEach(draft.availableOptions) { option in
              HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                  Text(option.displayName)
                  Text(option.identifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Add") {
                  draft.add(option.identifier)
                }
                .accessibilityLabel("Add \(option.displayName)")
                .accessibilityIdentifier("copylasso.languages.add.\(option.identifier)")
              }
            }
          }
        }
      }
      .listStyle(.inset)

      HStack {
        Button("Reset to English") {
          draft.resetToEnglish()
        }
        .accessibilityIdentifier("copylasso.languages.reset")

        Spacer()

        Button("Cancel", role: .cancel) {
          dismiss()
        }
        .keyboardShortcut(.cancelAction)
        .accessibilityIdentifier("copylasso.languages.cancel")

        Button("Done") {
          onSave(draft.selectedLanguageIdentifiers)
          dismiss()
        }
        .keyboardShortcut(.defaultAction)
        .accessibilityIdentifier("copylasso.languages.done")
      }
    }
    .padding(20)
    .frame(width: 500, height: 560)
  }
}
