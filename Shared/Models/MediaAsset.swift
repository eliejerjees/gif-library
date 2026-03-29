import Foundation

struct MediaAsset: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var kind: MediaKind
    var relativeFilePath: String
    var relativeThumbnailPath: String
    var createdAt: Date
    var lastUsedAt: Date?
    var folderID: UUID?
    var originalSource: MediaSourceType?
    var captionHistory: [String]
    var originalFilename: String

    var recencyDate: Date {
        lastUsedAt ?? createdAt
    }
}
