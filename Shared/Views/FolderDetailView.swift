import SwiftUI

struct FolderDetailView: View {
    @ObservedObject var viewModel: LibraryViewModel
    let folder: MediaFolder
    let experience: LibraryExperience

    @State private var isImportSheetPresented = false

    private var liveFolder: MediaFolder? {
        viewModel.folders.first(where: { $0.id == folder.id })
    }

    var body: some View {
        Group {
            if let liveFolder {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(liveFolder.name)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("\(viewModel.count(for: liveFolder)) items")
                                .foregroundStyle(Color.white.opacity(0.68))
                        }

                        let folderItems = viewModel.items(in: liveFolder)
                        if folderItems.isEmpty {
                            EmptyFolderView()
                        } else {
                            MediaGridView(
                                viewModel: viewModel,
                                items: folderItems,
                                experience: experience,
                                showFolderNames: false
                            )
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
                .background(Color.clear)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Import Here", systemImage: "plus") {
                                isImportSheetPresented = true
                            }
                            Button("Rename", systemImage: "pencil") {
                                viewModel.beginRenamingFolder(liveFolder)
                            }
                            Button("Delete Folder", systemImage: "trash", role: .destructive) {
                                viewModel.folderPendingDeletion = liveFolder
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .sheet(isPresented: $isImportSheetPresented) {
                    ImportMediaSheet(viewModel: viewModel, preferredFolderID: liveFolder.id)
                }
            } else {
                Text("This folder no longer exists.")
                    .foregroundStyle(.white)
                    .padding(20)
            }
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
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct EmptyFolderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This folder is empty")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Import directly into the folder or move items here from the Recent tab.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.7))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}
