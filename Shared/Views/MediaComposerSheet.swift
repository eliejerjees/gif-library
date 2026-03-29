import SwiftUI

struct MediaComposerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: LibraryViewModel
    let payload: MediaSendPayload
    let experience: LibraryExperience

    @State private var captionText = ""
    @State private var isSending = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AnimatedMediaPreview(payload: payload)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Caption")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        TextField("Optional caption", text: $captionText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding(14)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .foregroundStyle(.white)
                    }

                    if !payload.item.captionHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent captions")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.72))

                            FlexibleTagWrap(tags: payload.item.captionHistory) { tag in
                                captionText = tag
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(payload.item.originalFilename)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(experience.sendAction == nil
                             ? "Sending is only available from the Messages extension. You can still use the host app to import and organize your library."
                             : "The extension inserts the media and optional caption into the current Messages compose field for quick sending.")
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
                    .disabled(experience.sendAction == nil || isSending)
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
                try await sendAction(payload, captionText)
                await viewModel.registerSend(of: payload.item, caption: captionText)
                dismiss()
            } catch {
                viewModel.present(error)
            }
        }
    }
}

private struct FlexibleTagWrap: View {
    let tags: [String]
    let onTap: (String) -> Void

    var body: some View {
        ViewThatFits(in: .vertical) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Button(tag) {
                        onTap(tag)
                    }
                    .buttonStyle(TagButtonStyle())
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Button(tag) {
                        onTap(tag)
                    }
                    .buttonStyle(TagButtonStyle())
                }
            }
        }
    }
}

private struct TagButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(configuration.isPressed ? 0.16 : 0.10), in: Capsule())
    }
}
