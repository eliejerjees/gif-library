import Messages
import SwiftUI

final class MessagesViewController: MSMessagesAppViewController {
    private var hostingController: UIHostingController<LibraryRootView>?
    private let sender = MessageAttachmentSender()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.04, green: 0.05, blue: 0.09, alpha: 1)
        embedSwiftUIViewIfNeeded()
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        requestPresentationStyle(.expanded)
    }

    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)
        requestPresentationStyle(.expanded)
    }

    private func embedSwiftUIViewIfNeeded() {
        guard hostingController == nil else { return }

        let rootView = LibraryRootView(
            experience: .messages { [weak self] payload in
                guard let self else {
                    throw MessageAttachmentSenderError.missingConversation
                }

                let conversation = await MainActor.run { self.activeConversation }
                guard let conversation else {
                    throw MessageAttachmentSenderError.missingConversation
                }

                try await self.sender.insert(
                    payload: payload,
                    conversation: conversation
                )
            }
        )

        let hostingController = UIHostingController(rootView: rootView)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear

        addChild(hostingController)
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)

        self.hostingController = hostingController
    }
}
