import Foundation

enum MediaKind: String, Codable, CaseIterable, Sendable {
    case gif
    case image

    var title: String {
        switch self {
        case .gif:
            return "GIF"
        case .image:
            return "Image"
        }
    }
}
