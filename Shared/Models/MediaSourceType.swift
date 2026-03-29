import Foundation

enum MediaSourceType: String, Codable, CaseIterable, Sendable {
    case photos
    case files
    case remoteURL
    case clipboard

    var title: String {
        switch self {
        case .photos:
            return "Photos"
        case .files:
            return "Files"
        case .remoteURL:
            return "URL"
        case .clipboard:
            return "Clipboard"
        }
    }
}
