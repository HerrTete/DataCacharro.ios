import SwiftUI

struct AddTextView: View {
    @EnvironmentObject var storage: StorageService
    @Environment(\.dismiss) var dismiss
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .padding()
                .focused($isFocused)
                .accessibilityIdentifier("textEditor")
                .navigationTitle("Add Text")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                            .accessibilityIdentifier("cancelButton")
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            if !text.isEmpty {
                                storage.addTextItem(text: text, location: LocationService.shared.currentAddress)
                            }
                            dismiss()
                        }
                        .disabled(text.isEmpty)
                        .accessibilityIdentifier("saveButton")
                    }
                }
        }
        .onAppear {
            LocationService.shared.start()
            isFocused = true
        }
    }
}
