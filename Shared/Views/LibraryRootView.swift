import SwiftUI

struct LibraryExperience {
    let title: String
    let subtitle: String?
    let sendButtonTitle: String
    let sendAction: (@Sendable (MediaSendPayload, String) async throws -> Void)?

    static func hostApp() -> LibraryExperience {
        LibraryExperience(
            title: "GIF Library",
            subtitle: "Use the host app for setup, extra imports, and fallback management. Day-to-day browsing and sending stays in Messages.",
            sendButtonTitle: "Insert in Messages",
            sendAction: nil
        )
    }

    static func messages(sendAction: @escaping @Sendable (MediaSendPayload, String) async throws -> Void) -> LibraryExperience {
        LibraryExperience(
            title: "Library",
            subtitle: "Recent stays fast. Folders keep the rest tidy.",
            sendButtonTitle: "Insert in Conversation",
            sendAction: sendAction
        )
    }
}

struct LibraryRootView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var isImportSheetPresented = false

    let experience: LibraryExperience

    var body: some View {
        NavigationStack {
            ZStack {
                LibraryBackgroundView()

                if let startupError = viewModel.startupError {
                    SetupRequiredView(message: startupError)
                        .padding(20)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            header
                            tabPicker
                            tabContent
                        }
                        .padding(20)
                    }
                    .scrollIndicators(.hidden)
                }

                if viewModel.isBusy {
                    BusyOverlayView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.startupError == nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isImportSheetPresented = true
                        } label: {
                            Label("Import", systemImage: "plus")
                        }
                    }

                    if viewModel.selectedTab == .folders {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                viewModel.beginCreatingFolder()
                            } label: {
                                Label("Folder", systemImage: "folder.badge.plus")
                            }
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: $isImportSheetPresented) {
            ImportMediaSheet(viewModel: viewModel, preferredFolderID: nil)
        }
        .sheet(item: $viewModel.selectedAssetForComposer) { item in
            if let payload = viewModel.sendPayload(for: item) {
                MediaComposerSheet(
                    viewModel: viewModel,
                    payload: payload,
                    experience: experience
                )
            }
        }
        .sheet(item: $viewModel.folderEditor) { editor in
            FolderEditorSheet(
                state: editor,
                onSave: { name in
                    switch editor.mode {
                    case .create:
                        await viewModel.createFolder(named: name)
                    case .rename(let folder):
                        await viewModel.renameFolder(folder, to: name)
                    }
                }
            )
        }
        .sheet(item: $viewModel.itemBeingMoved) { item in
            MoveToFolderSheet(
                item: item,
                folders: viewModel.folders,
                currentFolderID: item.folderID,
                onMove: { folderID in
                    await viewModel.move(item, to: folderID)
                }
            )
        }
        .alert(item: $viewModel.alertState) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(
            "Delete Folder?",
            isPresented: Binding(
                get: { viewModel.folderPendingDeletion != nil },
                set: { if !$0 { viewModel.folderPendingDeletion = nil } }
            ),
            presenting: viewModel.folderPendingDeletion
        ) { folder in
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteFolder(folder)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { folder in
            Text("Delete “\(folder.name)” and keep its media as unfiled items?")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(experience.title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            if let subtitle = experience.subtitle {
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LibraryCardBackground())
    }

    private var tabPicker: some View {
        Picker("Library Tab", selection: $viewModel.selectedTab) {
            ForEach(LibraryTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .recent:
            RecentTabView(viewModel: viewModel, experience: experience)
        case .folders:
            FoldersTabView(viewModel: viewModel, experience: experience)
        }
    }
}

private struct RecentTabView: View {
    @ObservedObject var viewModel: LibraryViewModel
    let experience: LibraryExperience

    var body: some View {
        if viewModel.recentItems.isEmpty {
            EmptyStateCard(
                title: "No media yet",
                message: "Import GIFs, still images, or a short video to convert into a GIF."
            )
        } else {
            MediaGridView(
                viewModel: viewModel,
                items: viewModel.recentItems,
                experience: experience,
                showFolderNames: true
            )
        }
    }
}

private struct FoldersTabView: View {
    @ObservedObject var viewModel: LibraryViewModel
    let experience: LibraryExperience

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.folders.isEmpty {
                EmptyStateCard(
                    title: "No folders yet",
                    message: "Create folders for favorites, reactions, memes, or anything else you reach for often."
                )
            } else {
                ForEach(viewModel.folders) { folder in
                    NavigationLink {
                        FolderDetailView(viewModel: viewModel, folder: folder, experience: experience)
                    } label: {
                        FolderRowView(
                            folder: folder,
                            itemCount: viewModel.count(for: folder)
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Rename", systemImage: "pencil") {
                            viewModel.beginRenamingFolder(folder)
                        }

                        Button("Delete Folder", systemImage: "trash", role: .destructive) {
                            viewModel.folderPendingDeletion = folder
                        }
                    }
                }
            }
        }
    }
}

private struct SetupRequiredView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Complete One Setup Step")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(message)
                .foregroundStyle(Color.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                Text("1. Update the bundle identifiers.")
                Text("2. Add the same App Group to both targets.")
                Text("3. Run the host app once, then open the Messages extension.")
            }
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.75))
        }
        .padding(24)
        .background(LibraryCardBackground())
    }
}

private struct BusyOverlayView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.28).ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                Text("Working…")
                    .foregroundStyle(.white)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

private struct EmptyStateCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.7))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LibraryCardBackground())
    }
}

private struct FolderRowView: View {
    let folder: MediaFolder
    let itemCount: Int

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.23, green: 0.42, blue: 0.98), Color(red: 0.08, green: 0.16, blue: 0.36)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 58, height: 58)
                .overlay {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white.opacity(0.95))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(folder.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(itemCount == 1 ? "1 item" : "\(itemCount) items")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.65))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(Color.white.opacity(0.45))
        }
        .padding(18)
        .background(LibraryCardBackground())
    }
}

private struct LibraryBackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.05, blue: 0.09),
                Color(red: 0.08, green: 0.10, blue: 0.17),
                Color(red: 0.03, green: 0.04, blue: 0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color(red: 0.10, green: 0.54, blue: 0.91).opacity(0.16))
                .frame(width: 220, height: 220)
                .blur(radius: 30)
                .offset(x: 70, y: -40)
        }
        .ignoresSafeArea()
    }
}

private struct LibraryCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
    }
}
