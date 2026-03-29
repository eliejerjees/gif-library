import Messages

enum MessageAttachmentSenderError: LocalizedError {
    case missingConversation

    var errorDescription: String? {
        switch self {
        case .missingConversation:
            return "No active Messages conversation was found."
        }
    }
}

final class MessageAttachmentSender {
    func insert(
        payload: MediaSendPayload,
        conversation: MSConversation
    ) async throws {
        try await conversation.insertAttachmentAsync(
            payload.fileURL,
            withAlternateFilename: payload.item.messageAttachmentFilename
        )
    }
}

private extension MediaAsset {
    var messageAttachmentFilename: String {
        let fileExtension = URL(fileURLWithPath: relativeFilePath).pathExtension
        guard !fileExtension.isEmpty else { return displayName }
        return "\(displayName).\(fileExtension)"
    }
}

private extension MSConversation {
    func insertAttachmentAsync(_ url: URL, withAlternateFilename filename: String?) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            insertAttachment(url, withAlternateFilename: filename) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
