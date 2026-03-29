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
    var displayName: String
    var originalFilename: String

    var recencyDate: Date {
        lastUsedAt ?? createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case relativeFilePath
        case relativeThumbnailPath
        case createdAt
        case lastUsedAt
        case folderID
        case originalSource
        case captionHistory
        case displayName
        case originalFilename
    }

    init(
        id: UUID,
        kind: MediaKind,
        relativeFilePath: String,
        relativeThumbnailPath: String,
        createdAt: Date,
        lastUsedAt: Date?,
        folderID: UUID?,
        originalSource: MediaSourceType?,
        captionHistory: [String],
        displayName: String,
        originalFilename: String
    ) {
        self.id = id
        self.kind = kind
        self.relativeFilePath = relativeFilePath
        self.relativeThumbnailPath = relativeThumbnailPath
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.folderID = folderID
        self.originalSource = originalSource
        self.captionHistory = captionHistory
        self.displayName = displayName
        self.originalFilename = originalFilename
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(MediaKind.self, forKey: .kind)
        relativeFilePath = try container.decode(String.self, forKey: .relativeFilePath)
        relativeThumbnailPath = try container.decode(String.self, forKey: .relativeThumbnailPath)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        folderID = try container.decodeIfPresent(UUID.self, forKey: .folderID)
        originalSource = try container.decodeIfPresent(MediaSourceType.self, forKey: .originalSource)
        captionHistory = try container.decodeIfPresent([String].self, forKey: .captionHistory) ?? []
        originalFilename = try container.decode(String.self, forKey: .originalFilename)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
            ?? originalFilename.deletingPathExtensionIfPresent()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(relativeFilePath, forKey: .relativeFilePath)
        try container.encode(relativeThumbnailPath, forKey: .relativeThumbnailPath)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(lastUsedAt, forKey: .lastUsedAt)
        try container.encodeIfPresent(folderID, forKey: .folderID)
        try container.encodeIfPresent(originalSource, forKey: .originalSource)
        try container.encode(captionHistory, forKey: .captionHistory)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(originalFilename, forKey: .originalFilename)
    }
}

private extension String {
    func deletingPathExtensionIfPresent() -> String {
        let url = URL(fileURLWithPath: self)
        let trimmed = url.deletingPathExtension().lastPathComponent
        return trimmed.isEmpty ? self : trimmed
    }
}
