import Foundation
import UniformTypeIdentifiers

enum PhotosPickerImport {
    static func copySelectedItemToTemporaryURL(from provider: NSItemProvider) async throws -> ImportedTemporaryMedia {
        guard let contentType = preferredContentType(for: provider) else {
            throw PhotosPickerImportError.unsupportedSelection
        }

        let suggestedName = provider.suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines)

        return try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: contentType.identifier) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let url else {
                    continuation.resume(throwing: PhotosPickerImportError.missingFileURL)
                    return
                }

                do {
                    let copiedURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(contentType.preferredFilenameExtension ?? url.pathExtension.ifEmpty("bin"))

                    if FileManager.default.fileExists(atPath: copiedURL.path) {
                        try FileManager.default.removeItem(at: copiedURL)
                    }

                    try FileManager.default.copyItem(at: url, to: copiedURL)
                    continuation.resume(returning: ImportedTemporaryMedia(
                        url: copiedURL,
                        suggestedName: suggestedName
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func preferredContentType(for provider: NSItemProvider) -> UTType? {
        let contentTypes = provider.registeredTypeIdentifiers.compactMap { UTType($0) }

        if let gifType = contentTypes.first(where: { $0.conforms(to: .gif) }) {
            return gifType
        }

        if let videoType = contentTypes.first(where: { $0.conforms(to: .movie) || $0.conforms(to: .video) }) {
            return videoType
        }

        return contentTypes.first(where: { $0.conforms(to: .image) })
    }
}

enum PhotosPickerImportError: LocalizedError {
    case unsupportedSelection
    case missingFileURL

    var errorDescription: String? {
        switch self {
        case .unsupportedSelection:
            return "That Photos item could not be imported. Try a GIF, still image, or short video."
        case .missingFileURL:
            return "The selected Photos item could not be copied."
        }
    }
}

struct ImportedTemporaryMedia: Sendable {
    let url: URL
    let suggestedName: String?
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
