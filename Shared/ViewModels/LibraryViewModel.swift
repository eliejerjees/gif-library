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
    @Published var searchText = ""
    @Published var alertState: AlertState?
    @Published var isBusy = false
    @Published var folderEditor: FolderEditorState?
    @Published var itemEditor: ItemEditorState?
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

    var filteredRecentItems: [MediaAsset] {
        filterItems(recentItems)
    }

    var filteredFolders: [MediaFolder] {
        filterFolders(folders)
    }

    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        filterItems(
            snapshot.items
            .filter { $0.folderID == folder.id }
            .sorted(by: { $0.recencyDate > $1.recencyDate })
        )
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

    func handlePrimaryTap(
        on item: MediaAsset,
        sendAction: (@Sendable (MediaSendPayload) async throws -> Void)?
    ) async {
        guard let sendAction else { return }
        guard let payload = sendPayload(for: item) else {
            present(LibraryViewModelError.unavailableMediaPayload)
            return
        }

        guard let store else { return }

        isBusy = true
        defer { isBusy = false }

        do {
            try await sendAction(payload)
            snapshot = try await store.registerUse(of: item.id, caption: nil)
        } catch {
            present(error)
        }
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

    func renameItem(_ item: MediaAsset, to name: String) async {
        guard let store else { return }
        do {
            snapshot = try await store.renameItem(id: item.id, to: name)
            itemEditor = nil
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
        } catch {
            present(error)
        }
    }

    func registerSend(of item: MediaAsset) async {
        guard let store else { return }
        do {
            snapshot = try await store.registerUse(of: item.id, caption: nil)
        } catch {
            present(error)
        }
    }

    func availableItems(forAddingTo folder: MediaFolder) -> [MediaAsset] {
        filterItems(snapshot.items
            .filter { $0.folderID != folder.id }
            .sorted { lhs, rhs in
                if lhs.recencyDate == rhs.recencyDate {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.recencyDate > rhs.recencyDate
            })
    }

    func importFromFiles(url: URL, displayName: String, preferredFolderID: UUID? = nil) async -> Bool {
        await performBusyWork { [self] in
            guard let store = self.store else { return }
            self.snapshot = try await store.importExternalFile(
                at: url,
                sourceType: .files,
                preferredFolderID: preferredFolderID,
                displayName: displayName
            )
        }
    }

    func preparePhotoImport(from provider: NSItemProvider) async throws -> ImportedTemporaryMedia {
        try await PhotosPickerImport.copySelectedItemToTemporaryURL(from: provider)
    }

    func importPreparedTemporaryFile(
        at url: URL,
        displayName: String,
        sourceType: MediaSourceType,
        preferredFolderID: UUID? = nil
    ) async -> Bool {
        await performBusyWork { [self] in
            defer { try? FileManager.default.removeItem(at: url) }

            guard let store = self.store else { return }
            self.snapshot = try await store.importExternalFile(
                at: url,
                sourceType: sourceType,
                preferredFolderID: preferredFolderID,
                displayName: displayName
            )
        }
    }

    func prepareClipboardImport() async throws -> ImportedTemporaryMedia {
        try await ClipboardImportService.copySupportedMediaToTemporaryURL()
    }

    func importFromRemoteURLString(_ rawValue: String, displayName: String, preferredFolderID: UUID? = nil) async -> Bool {
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
                preferredFolderID: preferredFolderID,
                displayName: displayName
            )
        }
    }

    func beginCreatingFolder() {
        folderEditor = FolderEditorState(mode: .create)
    }

    func beginRenamingFolder(_ folder: MediaFolder) {
        folderEditor = FolderEditorState(mode: .rename(folder), initialName: folder.name)
    }

    func beginRenamingItem(_ item: MediaAsset) {
        itemEditor = ItemEditorState(item: item, initialName: item.displayName)
    }

    func beginMoving(_ item: MediaAsset) {
        itemBeingMoved = item
    }

    func present(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        alertState = AlertState(title: "Something went wrong", message: message)
    }

    private func filterItems(_ items: [MediaAsset]) -> [MediaAsset] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }

        return items.filter { item in
            item.displayName.localizedCaseInsensitiveContains(query)
                || item.originalFilename.localizedCaseInsensitiveContains(query)
        }
    }

    private func filterFolders(_ folders: [MediaFolder]) -> [MediaFolder] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return folders }

        return folders.filter { folder in
            folder.name.localizedCaseInsensitiveContains(query)
        }
    }

    private func performBusyWork(operation: @escaping () async throws -> Void) async -> Bool {
        isBusy = true
        defer { isBusy = false }

        do {
            try await operation()
            return true
        } catch {
            present(error)
            return false
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

struct ItemEditorState: Identifiable {
    let id = UUID()
    let item: MediaAsset
    let initialName: String

    var title: String {
        "Rename Media"
    }
}

enum LibraryViewModelError: LocalizedError {
    case invalidRemoteURL
    case unavailableMediaPayload

    var errorDescription: String? {
        switch self {
        case .invalidRemoteURL:
            return "Enter a full http or https URL before importing."
        case .unavailableMediaPayload:
            return "That media item is unavailable right now. Try importing it again."
        }
    }
}
