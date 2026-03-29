import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct GIFConversionConfiguration: Sendable {
    var framesPerSecond: Double = 10
    var maximumDuration: Double = 8
    var maximumPixelSize: CGFloat = 720
}

final class GIFConverter: @unchecked Sendable {
    func convertVideo(
        at sourceURL: URL,
        outputURL: URL,
        configuration: GIFConversionConfiguration = GIFConversionConfiguration()
    ) async throws {
        let asset = AVURLAsset(url: sourceURL)
        let rawDuration = CMTimeGetSeconds(try await asset.load(.duration))
        let clippedDuration = min(max(rawDuration, 0.2), configuration.maximumDuration)
        let frameCount = max(Int(clippedDuration * configuration.framesPerSecond), 2)
        let frameDelay = clippedDuration / Double(frameCount)

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(
            width: configuration.maximumPixelSize,
            height: configuration.maximumPixelSize
        )
        generator.requestedTimeToleranceAfter = .zero
        generator.requestedTimeToleranceBefore = .zero

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.gif.identifier as CFString,
            frameCount,
            nil
        ) else {
            throw GIFConversionError.failedToCreateDestination
        }

        let fileProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0
            ]
        ]
        let frameProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: frameDelay
            ]
        ]

        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)

        for frameIndex in 0..<frameCount {
            let progress = Double(frameIndex) / Double(frameCount)
            let seconds = progress * clippedDuration
            let time = CMTime(seconds: seconds, preferredTimescale: 600)
            let image = try generator.copyCGImage(at: time, actualTime: nil)
            CGImageDestinationAddImage(destination, image, frameProperties as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw GIFConversionError.finalizeFailed
        }
    }
}

enum GIFConversionError: LocalizedError {
    case failedToCreateDestination
    case finalizeFailed

    var errorDescription: String? {
        switch self {
        case .failedToCreateDestination:
            return "The GIF destination file could not be created."
        case .finalizeFailed:
            return "The converted GIF could not be finalized."
        }
    }
}
