import Foundation
import UIKit
import UniformTypeIdentifiers

enum ClipboardImportService {
    static func copySupportedMediaToTemporaryURL(
        from pasteboard: UIPasteboard = .general
    ) async throws -> ImportedTemporaryMedia {
        for provider in pasteboard.itemProviders {
            guard let contentType = preferredContentType(for: provider) else {
                continue
            }

            if let fileURL = try await loadFileRepresentation(from: provider, contentType: contentType) {
                return ImportedTemporaryMedia(
                    url: fileURL,
                    suggestedName: provider.suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }

            if let dataURL = try await loadDataRepresentation(from: provider, contentType: contentType) {
                return ImportedTemporaryMedia(
                    url: dataURL,
                    suggestedName: provider.suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        }

        if let image = pasteboard.image, let data = image.pngData() {
            let destinationURL = temporaryURL(extension: "png")
            try data.write(to: destinationURL, options: [.atomic])
            return ImportedTemporaryMedia(url: destinationURL, suggestedName: "Copied Image")
        }

        throw ClipboardImportError.noSupportedMedia
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

    private static func loadFileRepresentation(
        from provider: NSItemProvider,
        contentType: UTType
    ) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: contentType.identifier) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let url else {
                    continuation.resume(returning: nil)
                    return
                }

                do {
                    let destinationURL = temporaryURL(
                        extension: contentType.preferredFilenameExtension ?? url.pathExtension.ifEmpty("bin")
                    )
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                    continuation.resume(returning: destinationURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func loadDataRepresentation(
        from provider: NSItemProvider,
        contentType: UTType
    ) async throws -> URL? {
        guard provider.hasItemConformingToTypeIdentifier(contentType.identifier) else {
            return nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: contentType.identifier) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let data, !data.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                do {
                    let destinationURL = temporaryURL(
                        extension: contentType.preferredFilenameExtension ?? "bin"
                    )
                    try data.write(to: destinationURL, options: [.atomic])
                    continuation.resume(returning: destinationURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func temporaryURL(extension fileExtension: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
    }
}

enum ClipboardImportError: LocalizedError {
    case noSupportedMedia

    var errorDescription: String? {
        switch self {
        case .noSupportedMedia:
            return "The clipboard does not contain a supported GIF, image, or video. In Messages, long-press the media, tap Copy, then come back and try again."
        }
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
