import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ThumbnailService {
    static func generateThumbnail(
        from sourceURL: URL,
        destinationURL: URL,
        maxPixelSize: Int = 720
    ) throws {
        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw ThumbnailError.failedToReadSource
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            throw ThumbnailError.failedToCreateThumbnail
        }

        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ThumbnailError.failedToCreateDestination
        }

        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.85
        ]

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ThumbnailError.failedToWriteThumbnail
        }
    }
}

enum ThumbnailError: LocalizedError {
    case failedToReadSource
    case failedToCreateThumbnail
    case failedToCreateDestination
    case failedToWriteThumbnail

    var errorDescription: String? {
        switch self {
        case .failedToReadSource:
            return "The imported media could not be read for thumbnail generation."
        case .failedToCreateThumbnail:
            return "A thumbnail could not be created for this media item."
        case .failedToCreateDestination:
            return "The thumbnail destination could not be prepared."
        case .failedToWriteThumbnail:
            return "The thumbnail could not be written to local storage."
        }
    }
}
