import SwiftUI

struct MediaGridView: View {
    @ObservedObject var viewModel: LibraryViewModel
    let items: [MediaAsset]
    let experience: LibraryExperience
    let showFolderNames: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 14, alignment: .top),
        GridItem(.flexible(), spacing: 14, alignment: .top)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(items) { item in
                Button {
                    viewModel.showComposer(for: item)
                } label: {
                    MediaTileView(
                        item: item,
                        thumbnailURL: viewModel.thumbnailURL(for: item),
                        folderName: showFolderNames ? viewModel.folder(for: item.folderID)?.name : nil
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(experience.sendAction == nil ? "Preview" : "Insert", systemImage: "paperplane") {
                        viewModel.showComposer(for: item)
                    }

                    Button("Rename", systemImage: "pencil") {
                        viewModel.beginRenamingItem(item)
                    }

                    Button("Move to Folder", systemImage: "folder") {
                        viewModel.beginMoving(item)
                    }

                    if item.folderID != nil {
                        Button("Remove from Folder", systemImage: "folder.badge.minus") {
                            Task {
                                await viewModel.move(item, to: nil)
                            }
                        }
                    }

                    Button("Delete", systemImage: "trash", role: .destructive) {
                        Task {
                            await viewModel.delete(item)
                        }
                    }
                }
            }
        }
    }
}

struct MediaTileView: View {
    let item: MediaAsset
    let thumbnailURL: URL?
    let folderName: String?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))

            if let thumbnailURL {
                LocalStaticImageView(url: thumbnailURL)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                Color.white.opacity(0.06)
            }

            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.68)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                if let folderName {
                    Text(folderName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.82))
                        .lineLimit(1)
                }

                Text(item.displayName)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            Text(item.kind.title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.48), in: Capsule())
                .padding(10)
        }
    }
}
