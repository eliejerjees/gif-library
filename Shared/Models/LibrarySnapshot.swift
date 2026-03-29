import Foundation

struct LibrarySnapshot: Codable, Sendable {
    var folders: [MediaFolder]
    var items: [MediaAsset]

    static let empty = LibrarySnapshot(folders: [], items: [])
}
