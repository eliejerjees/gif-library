import Foundation

struct AlertState: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct MediaSendPayload: Sendable {
    let item: MediaAsset
    let fileURL: URL
}

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var snapshot: LibrarySnapshot = .empty
    @Published var selectedTab: LibraryTab = .recent
    @Published var alertState: AlertState?
    @Published var isBusy = false
    @Published var selectedAssetForComposer: MediaAsset?
    @Published var folderEditor: FolderEditorState?
    @Published var itemBeingMoved: MediaAsset?
    @Published var folderPendingDeletion: MediaFolder?

    let startupError: String?
    let container: SharedAppGroup?

    private let store: MediaLibraryStore?
    private let remoteDownloader = RemoteMediaDownloader()

    init() {
        do {
            let container = try SharedAppGroup.configured()
            self.container = container
            self.store = MediaLibraryStore(container: container)
            self.startupError = nil
        } catch {
            self.container = nil
            self.store = nil
            self.startupError = error.localizedDescription
        }
    }

    var folders: [MediaFolder] {
        snapshot.folders.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var recentItems: [MediaAsset] {
        snapshot.items.sorted { lhs, rhs in
            if lhs.recencyDate == rhs.recencyDate {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.recencyDate > rhs.recencyDate
        }
    }

    var hasContent: Bool {
        !snapshot.items.isEmpty || !snapshot.folders.isEmpty
    }

    func load() async {
        guard let store else { return }
        do {
            snapshot = try await store.loadSnapshot()
        } catch {
            present(error)
        }
    }

    func items(in folder: MediaFolder) -> [MediaAsset] {
        snapshot.items
            .filter { $0.folderID == folder.id }
            .sorted(by: { $0.recencyDate > $1.recencyDate })
    }

    func count(for folder: MediaFolder) -> Int {
        snapshot.items.filter { $0.folderID == folder.id }.count
    }

    func folder(for id: UUID?) -> MediaFolder? {
        guard let id else { return nil }
        return snapshot.folders.first(where: { $0.id == id })
    }

    func thumbnailURL(for item: MediaAsset) -> URL? {
        container?.resolve(relativePath: item.relativeThumbnailPath)
    }

    func sendPayload(for item: MediaAsset) -> MediaSendPayload? {
        guard let container else { return nil }
        return MediaSendPayload(
            item: item,
            fileURL: container.resolve(relativePath: item.relativeFilePath)
        )
    }

    func showComposer(for item: MediaAsset) {
        selectedAssetForComposer = item
    }

    func createFolder(named name: String) async {
        guard let store else { return }
        do {
            snapshot = try await store.createFolder(named: name)
            folderEditor = nil
        } catch {
            present(error)
        }
    }

    func renameFolder(_ folder: MediaFolder, to name: String) async {
        guard let store else { return }
        do {
            snapshot = try await store.renameFolder(id: folder.id, to: name)
            folderEditor = nil
        } catch {
            present(error)
        }
    }

    func deleteFolder(_ folder: MediaFolder) async {
        guard let store else { return }
        do {
            snapshot = try await store.deleteFolder(id: folder.id)
            folderPendingDeletion = nil
        } catch {
            present(error)
        }
    }

    func move(_ item: MediaAsset, to folderID: UUID?) async {
        guard let store else { return }
        do {
            snapshot = try await store.moveItem(id: item.id, to: folderID)
            itemBeingMoved = nil
        } catch {
            present(error)
        }
    }

    func delete(_ item: MediaAsset) async {
        guard let store else { return }
        do {
            snapshot = try await store.deleteItem(id: item.id)
            if selectedAssetForComposer?.id == item.id {
                selectedAssetForComposer = nil
            }
        } catch {
            present(error)
        }
    }

    func registerSend(of item: MediaAsset) async {
        guard let store else { return }
        do {
            snapshot = try await store.registerUse(of: item.id, caption: nil)
            selectedAssetForComposer = snapshot.items.first(where: { $0.id == item.id })
        } catch {
            present(error)
        }
    }

    func availableItems(forAddingTo folder: MediaFolder) -> [MediaAsset] {
        snapshot.items
            .filter { $0.folderID != folder.id }
            .sorted { lhs, rhs in
                if lhs.recencyDate == rhs.recencyDate {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.recencyDate > rhs.recencyDate
            }
    }

    func importFromFiles(url: URL, preferredFolderID: UUID? = nil) async {
        await performBusyWork { [self] in
            guard let store = self.store else { return }
            self.snapshot = try await store.importExternalFile(
                at: url,
                sourceType: .files,
                preferredFolderID: preferredFolderID
            )
        }
    }

    func importFromPhotoProvider(_ provider: NSItemProvider, preferredFolderID: UUID? = nil) async {
        await performBusyWork { [self] in
            let temporaryURL = try await PhotosPickerImport.copySelectedItemToTemporaryURL(from: provider)
            defer { try? FileManager.default.removeItem(at: temporaryURL) }

            guard let store = self.store else { return }
            self.snapshot = try await store.importExternalFile(
                at: temporaryURL,
                sourceType: .photos,
                preferredFolderID: preferredFolderID
            )
        }
    }

    func importFromRemoteURLString(_ rawValue: String, preferredFolderID: UUID? = nil) async {
        await performBusyWork { [self] in
            guard let parsedURL = URL(string: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let scheme = parsedURL.scheme?.lowercased(),
                  ["https", "http"].contains(scheme) else {
                throw LibraryViewModelError.invalidRemoteURL
            }

            let downloadedURL = try await self.remoteDownloader.download(from: parsedURL)
            defer { try? FileManager.default.removeItem(at: downloadedURL) }

            guard let store = self.store else { return }
            self.snapshot = try await store.importExternalFile(
                at: downloadedURL,
                sourceType: .remoteURL,
                preferredFolderID: preferredFolderID
            )
        }
    }

    func beginCreatingFolder() {
        folderEditor = FolderEditorState(mode: .create)
    }

    func beginRenamingFolder(_ folder: MediaFolder) {
        folderEditor = FolderEditorState(mode: .rename(folder), initialName: folder.name)
    }

    func beginMoving(_ item: MediaAsset) {
        itemBeingMoved = item
    }

    func present(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        alertState = AlertState(title: "Something went wrong", message: message)
    }

    private func performBusyWork(operation: @escaping () async throws -> Void) async {
        isBusy = true
        defer { isBusy = false }

        do {
            try await operation()
        } catch {
            present(error)
        }
    }
}

enum LibraryTab: String, CaseIterable, Identifiable {
    case recent
    case folders

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent:
            return "Recent"
        case .folders:
            return "Folders"
        }
    }
}

struct FolderEditorState: Identifiable {
    enum Mode {
        case create
        case rename(MediaFolder)
    }

    let id = UUID()
    let mode: Mode
    var initialName: String = ""

    var title: String {
        switch mode {
        case .create:
            return "New Folder"
        case .rename:
            return "Rename Folder"
        }
    }
}

enum LibraryViewModelError: LocalizedError {
    case invalidRemoteURL

    var errorDescription: String? {
        switch self {
        case .invalidRemoteURL:
            return "Enter a full http or https URL before importing."
        }
    }
}
