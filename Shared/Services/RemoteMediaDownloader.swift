import Foundation
import UniformTypeIdentifiers

final class RemoteMediaDownloader: @unchecked Sendable {
    func download(from remoteURL: URL) async throws -> URL {
        let (temporaryURL, response) = try await URLSession.shared.download(from: remoteURL)

        let responseExtension = Self.fileExtension(
            for: remoteURL,
            mimeType: response.mimeType
        )
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(responseExtension)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.copyItem(at: temporaryURL, to: destinationURL)
        return destinationURL
    }

    private static func fileExtension(for remoteURL: URL, mimeType: String?) -> String {
        if !remoteURL.pathExtension.isEmpty {
            return remoteURL.pathExtension
        }

        if let mimeType, let type = UTType(mimeType: mimeType), let preferred = type.preferredFilenameExtension {
            return preferred
        }

        return "bin"
    }
}
