import Foundation

struct MediaFolder: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var createdAt: Date
}
