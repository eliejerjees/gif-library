import SwiftUI

struct ItemEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    let state: ItemEditorState
    let onSave: (String) async -> Void

    @State private var itemName: String

    init(state: ItemEditorState, onSave: @escaping (String) async -> Void) {
        self.state = state
        self.onSave = onSave
        _itemName = State(initialValue: state.initialName)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Media name", text: $itemName)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        guard !itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        Task {
                            await onSave(itemName)
                        }
                    }
            }
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.05, blue: 0.09),
                        Color(red: 0.08, green: 0.10, blue: 0.17)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle(state.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await onSave(itemName)
                        }
                    }
                    .disabled(itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            isFocused = true
        }
    }
}
