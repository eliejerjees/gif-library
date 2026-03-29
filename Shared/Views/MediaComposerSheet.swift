import SwiftUI

struct MediaComposerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: LibraryViewModel
    let payload: MediaSendPayload
    let experience: LibraryExperience

    @State private var isSending = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AnimatedMediaPreview(payload: payload)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(payload.item.originalFilename)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(experience.sendAction == nil
                             ? "Sending is only available from the Messages extension. You can still use the host app to import and organize your library."
                             : "This inserts the media into the current Messages conversation. If you want text with it, type that in the chat after inserting.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                }
                .padding(20)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.04, green: 0.05, blue: 0.09),
                        Color(red: 0.08, green: 0.10, blue: 0.17)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                if experience.sendAction != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            insertIntoConversation()
                        } label: {
                            if isSending {
                                ProgressView()
                            } else {
                                Text(experience.sendButtonTitle)
                            }
                        }
                        .disabled(isSending)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func insertIntoConversation() {
        guard let sendAction = experience.sendAction else {
            return
        }

        Task {
            isSending = true
            defer { isSending = false }

            do {
                try await sendAction(payload)
                await viewModel.registerSend(of: payload.item)
                dismiss()
            } catch {
                viewModel.present(error)
            }
        }
    }
}
