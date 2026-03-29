import Foundation

struct SharedAppGroup: Sendable {
    let identifier: String
    let rootURL: URL
    let storeURL: URL
    let mediaDirectoryURL: URL
    let thumbnailsDirectoryURL: URL
    let metadataURL: URL

    static func configured(bundle: Bundle = .main) throws -> SharedAppGroup {
        let rawIdentifier = (bundle.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !rawIdentifier.isEmpty else {
            throw SharedAppGroupError.missingIdentifier
        }

        guard let rootURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: rawIdentifier
        ) else {
            throw SharedAppGroupError.missingSharedContainer(rawIdentifier)
        }

        let storeURL = rootURL.appendingPathComponent("LibraryStore", isDirectory: true)
        let mediaDirectoryURL = storeURL.appendingPathComponent("Media", isDirectory: true)
        let thumbnailsDirectoryURL = storeURL.appendingPathComponent("Thumbnails", isDirectory: true)
        let metadataURL = storeURL.appendingPathComponent("library.json")

        return SharedAppGroup(
            identifier: rawIdentifier,
            rootURL: rootURL,
            storeURL: storeURL,
            mediaDirectoryURL: mediaDirectoryURL,
            thumbnailsDirectoryURL: thumbnailsDirectoryURL,
            metadataURL: metadataURL
        )
    }

    func ensureDirectories(fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: storeURL, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: mediaDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: thumbnailsDirectoryURL, withIntermediateDirectories: true, attributes: nil)
    }

    func resolve(relativePath: String) -> URL {
        storeURL.appendingPathComponent(relativePath)
    }
}

enum SharedAppGroupError: LocalizedError {
    case missingIdentifier
    case missingSharedContainer(String)

    var errorDescription: String? {
        switch self {
        case .missingIdentifier:
            return "The App Group identifier is missing. Add AppGroupIdentifier to both targets' Info.plist files."
        case .missingSharedContainer(let identifier):
            return """
            The shared App Group container \(identifier) is unavailable. Add the same App Group capability to the host app and the Messages extension, then update the bundle IDs and App Group identifier to match your signing team.
            """
        }
    }
}
