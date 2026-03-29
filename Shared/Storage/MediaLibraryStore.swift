import Foundation
import UniformTypeIdentifiers

actor MediaLibraryStore {
    private let container: SharedAppGroup
    private let fileManager: FileManager
    private let gifConverter: GIFConverter

    init(
        container: SharedAppGroup,
        fileManager: FileManager = .default,
        gifConverter: GIFConverter = GIFConverter()
    ) {
        self.container = container
        self.fileManager = fileManager
        self.gifConverter = gifConverter
    }

    func loadSnapshot() throws -> LibrarySnapshot {
        try container.ensureDirectories(fileManager: fileManager)

        guard fileManager.fileExists(atPath: container.metadataURL.path) else {
            try saveSnapshot(.empty)
            return .empty
        }

        let data = try Data(contentsOf: container.metadataURL)
        guard !data.isEmpty else {
            return .empty
        }

        return try JSONDecoder.libraryDecoder.decode(LibrarySnapshot.self, from: data)
    }

    @discardableResult
    func createFolder(named rawName: String) throws -> LibrarySnapshot {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw MediaLibraryStoreError.emptyFolderName
        }

        var snapshot = try loadSnapshot()
        guard snapshot.folders.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) == false else {
            throw MediaLibraryStoreError.folderAlreadyExists
        }

        snapshot.folders.append(MediaFolder(id: UUID(), name: name, createdAt: .now))
        try saveSnapshot(snapshot)
        return snapshot
    }

    @discardableResult
    func renameFolder(id: UUID, to rawName: String) throws -> LibrarySnapshot {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw MediaLibraryStoreError.emptyFolderName
        }

        var snapshot = try loadSnapshot()
        guard let index = snapshot.folders.firstIndex(where: { $0.id == id }) else {
            throw MediaLibraryStoreError.folderNotFound
        }

        snapshot.folders[index].name = name
        try saveSnapshot(snapshot)
        return snapshot
    }

    @discardableResult
    func deleteFolder(id: UUID) throws -> LibrarySnapshot {
        var snapshot = try loadSnapshot()
        snapshot.folders.removeAll { $0.id == id }
        for index in snapshot.items.indices where snapshot.items[index].folderID == id {
            snapshot.items[index].folderID = nil
        }
        try saveSnapshot(snapshot)
        return snapshot
    }

    @discardableResult
    func moveItem(id: UUID, to folderID: UUID?) throws -> LibrarySnapshot {
        var snapshot = try loadSnapshot()
        guard let index = snapshot.items.firstIndex(where: { $0.id == id }) else {
            throw MediaLibraryStoreError.mediaNotFound
        }

        if let folderID,
           snapshot.folders.contains(where: { $0.id == folderID }) == false {
            throw MediaLibraryStoreError.folderNotFound
        }

        snapshot.items[index].folderID = folderID
        try saveSnapshot(snapshot)
        return snapshot
    }

    @discardableResult
    func deleteItem(id: UUID) throws -> LibrarySnapshot {
        var snapshot = try loadSnapshot()
        guard let item = snapshot.items.first(where: { $0.id == id }) else {
            throw MediaLibraryStoreError.mediaNotFound
        }

        try? fileManager.removeItem(at: container.resolve(relativePath: item.relativeFilePath))
        try? fileManager.removeItem(at: container.resolve(relativePath: item.relativeThumbnailPath))
        snapshot.items.removeAll { $0.id == id }
        try saveSnapshot(snapshot)
        return snapshot
    }

    @discardableResult
    func registerUse(of id: UUID, caption: String?) throws -> LibrarySnapshot {
        var snapshot = try loadSnapshot()
        guard let index = snapshot.items.firstIndex(where: { $0.id == id }) else {
            throw MediaLibraryStoreError.mediaNotFound
        }

        snapshot.items[index].lastUsedAt = .now

        let trimmedCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedCaption.isEmpty {
            var history = snapshot.items[index].captionHistory.filter { $0.caseInsensitiveCompare(trimmedCaption) != .orderedSame }
            history.insert(trimmedCaption, at: 0)
            snapshot.items[index].captionHistory = Array(history.prefix(6))
        }

        try saveSnapshot(snapshot)
        return snapshot
    }

    @discardableResult
    func importExternalFile(
        at sourceURL: URL,
        sourceType: MediaSourceType?,
        preferredFolderID: UUID?
    ) async throws -> LibrarySnapshot {
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        var snapshot = try loadSnapshot()
        if let preferredFolderID,
           snapshot.folders.contains(where: { $0.id == preferredFolderID }) == false {
            throw MediaLibraryStoreError.folderNotFound
        }

        let asset = try await persistImportedAsset(
            from: sourceURL,
            sourceType: sourceType,
            folderID: preferredFolderID
        )

        snapshot.items.append(asset)
        try saveSnapshot(snapshot)
        return snapshot
    }

    private func persistImportedAsset(
        from sourceURL: URL,
        sourceType: MediaSourceType?,
        folderID: UUID?
    ) async throws -> MediaAsset {
        let itemID = UUID()
        let contentType = try resolveContentType(for: sourceURL)

        let fileExtension: String
        let finalURL: URL
        let kind: MediaKind

        if contentType.conforms(to: .movie) || contentType.conforms(to: .video) {
            fileExtension = "gif"
            finalURL = container.mediaDirectoryURL
                .appendingPathComponent(itemID.uuidString)
                .appendingPathExtension(fileExtension)
            try await gifConverter.convertVideo(at: sourceURL, outputURL: finalURL)
            kind = .gif
        } else if contentType.conforms(to: .gif) {
            fileExtension = "gif"
            finalURL = container.mediaDirectoryURL
                .appendingPathComponent(itemID.uuidString)
                .appendingPathExtension(fileExtension)
            try copyItem(from: sourceURL, to: finalURL)
            kind = .gif
        } else if contentType.conforms(to: .image) {
            let preferredExtension = contentType.preferredFilenameExtension ?? sourceURL.pathExtension.ifEmpty("jpg")
            fileExtension = preferredExtension
            finalURL = container.mediaDirectoryURL
                .appendingPathComponent(itemID.uuidString)
                .appendingPathExtension(fileExtension)
            try copyItem(from: sourceURL, to: finalURL)
            kind = .image
        } else {
            throw MediaLibraryStoreError.unsupportedMediaType
        }

        let thumbnailURL = container.thumbnailsDirectoryURL
            .appendingPathComponent(itemID.uuidString)
            .appendingPathExtension("jpg")
        try ThumbnailService.generateThumbnail(from: finalURL, destinationURL: thumbnailURL)

        return MediaAsset(
            id: itemID,
            kind: kind,
            relativeFilePath: "Media/\(finalURL.lastPathComponent)",
            relativeThumbnailPath: "Thumbnails/\(thumbnailURL.lastPathComponent)",
            createdAt: .now,
            lastUsedAt: nil,
            folderID: folderID,
            originalSource: sourceType,
            captionHistory: [],
            originalFilename: sourceURL.lastPathComponent
        )
    }

    private func copyItem(from sourceURL: URL, to destinationURL: URL) throws {
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        if sourceURL.path == destinationURL.path {
            return
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    private func resolveContentType(for url: URL) throws -> UTType {
        if let resourceType = try url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return resourceType
        }

        if let type = UTType(filenameExtension: url.pathExtension) {
            return type
        }

        throw MediaLibraryStoreError.unsupportedMediaType
    }

    private func saveSnapshot(_ snapshot: LibrarySnapshot) throws {
        try container.ensureDirectories(fileManager: fileManager)
        let data = try JSONEncoder.libraryEncoder.encode(snapshot)
        try data.write(to: container.metadataURL, options: [.atomic])
    }
}

enum MediaLibraryStoreError: LocalizedError {
    case emptyFolderName
    case folderAlreadyExists
    case folderNotFound
    case mediaNotFound
    case unsupportedMediaType

    var errorDescription: String? {
        switch self {
        case .emptyFolderName:
            return "Enter a folder name before saving."
        case .folderAlreadyExists:
            return "A folder with that name already exists."
        case .folderNotFound:
            return "That folder could not be found."
        case .mediaNotFound:
            return "That media item could not be found."
        case .unsupportedMediaType:
            return "Only GIFs, still images, or videos that can be converted to GIF are supported."
        }
    }
}

private extension JSONEncoder {
    static let libraryEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}

private extension JSONDecoder {
    static let libraryDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
