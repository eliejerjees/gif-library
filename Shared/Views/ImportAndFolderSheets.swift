import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ImportMediaSheet: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: LibraryViewModel
    let preferredFolderID: UUID?

    @State private var isPhotoPickerPresented = false
    @State private var isFileImporterPresented = false
    @State private var remoteURLText = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Device") {
                    Button {
                        isPhotoPickerPresented = true
                    } label: {
                        Label("Import from Photos", systemImage: "photo.on.rectangle.angled")
                    }

                    Button {
                        isFileImporterPresented = true
                    } label: {
                        Label("Import from Files", systemImage: "folder")
                    }
                }

                Section("Direct URL") {
                    TextField("https://example.com/funny.gif", text: $remoteURLText)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()

                    Button("Paste from Clipboard") {
                        remoteURLText = UIPasteboard.general.string ?? remoteURLText
                    }

                    Button("Download and Save") {
                        Task {
                            await viewModel.importFromRemoteURLString(remoteURLText, preferredFolderID: preferredFolderID)
                            dismiss()
                        }
                    }
                    .disabled(remoteURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.gif, .image, .movie, .video],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task {
                        await viewModel.importFromFiles(url: url, preferredFolderID: preferredFolderID)
                        dismiss()
                    }
                case .failure(let error):
                    viewModel.present(error)
                }
            }
            .sheet(isPresented: $isPhotoPickerPresented) {
                PhotoLibraryPickerView { provider in
                    Task {
                        await viewModel.importFromPhotoProvider(provider, preferredFolderID: preferredFolderID)
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct FolderEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    let state: FolderEditorState
    let onSave: (String) async -> Void

    @State private var folderName: String

    init(state: FolderEditorState, onSave: @escaping (String) async -> Void) {
        self.state = state
        self.onSave = onSave
        _folderName = State(initialValue: state.initialName)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Folder name", text: $folderName)
                    .focused($isFocused)
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
                            await onSave(folderName)
                            dismiss()
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            isFocused = true
        }
    }
}

struct MoveToFolderSheet: View {
    @Environment(\.dismiss) private var dismiss

    let item: MediaAsset
    let folders: [MediaFolder]
    let currentFolderID: UUID?
    let onMove: (UUID?) async -> Void

    var body: some View {
        NavigationStack {
            List {
                Button {
                    Task {
                        await onMove(nil)
                        dismiss()
                    }
                } label: {
                    row(title: "Keep Unfiled", selected: currentFolderID == nil)
                }

                ForEach(folders) { folder in
                    Button {
                        Task {
                            await onMove(folder.id)
                            dismiss()
                        }
                    } label: {
                        row(title: folder.name, selected: currentFolderID == folder.id)
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
            .navigationTitle("Move “\(item.originalFilename)”")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func row(title: String, selected: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
    }
}

private struct PhotoLibraryPickerView: UIViewControllerRepresentable {
    let onPick: (NSItemProvider) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 1
        configuration.filter = .any(of: [.images, .videos])

        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onPick: (NSItemProvider) -> Void

        init(onPick: @escaping (NSItemProvider) -> Void) {
            self.onPick = onPick
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider else {
                return
            }

            onPick(provider)
        }
    }
}
