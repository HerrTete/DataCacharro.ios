import SwiftUI

struct ShareTagPickerView: View {
    let existingTags: [String]

    @State private var selectedTags: Set<String> = []
    @State private var newTagText: String = ""
    @State private var addedTags: [String] = []

    var onSave: (Set<String>) -> Void
    var onCancel: () -> Void

    private var allDisplayTags: [String] {
        Array(Set(existingTags + addedTags)).sorted()
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        TextField("New tag…", text: $newTagText)
                            .autocorrectionDisabled()
                            .onSubmit { addNewTag() }
                        if !newTagText.trimmingCharacters(in: .whitespaces).isEmpty {
                            Button("Add") { addNewTag() }
                        }
                    }
                }

                Section("Existing Tags") {
                    if allDisplayTags.isEmpty {
                        Text("No tags yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(allDisplayTags, id: \.self) { tag in
                            tagRow(tag: tag)
                        }
                    }
                }
            }
            .navigationTitle("Add Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        addNewTag()
                        onSave(selectedTags)
                    }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private func tagRow(tag: String) -> some View {
        Button {
            if selectedTags.contains(tag) {
                selectedTags.remove(tag)
            } else {
                selectedTags.insert(tag)
            }
        } label: {
            HStack {
                Text(tag)
                    .foregroundStyle(.primary)
                Spacer()
                if selectedTags.contains(tag) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    private func addNewTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let alreadyExists = allDisplayTags.contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        if !alreadyExists {
            addedTags.append(trimmed)
        }
        let existing = allDisplayTags.first { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        selectedTags.insert(existing ?? trimmed)
        newTagText = ""
    }
}
