import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Two shelves: favourite channels, and videos stored on this iPhone.
struct FavoritesView: View {
    enum Shelf: String, CaseIterable, Identifiable {
        case favorites
        case local

        var id: String {
            rawValue
        }

        var title: LocalizedStringKey {
            switch self {
            case .favorites: "Favorites"
            case .local: "On this iPhone"
            }
        }
    }

    let viewModel: LibraryViewModel
    let localVideos: LocalVideosViewModel
    let revision: Int
    let onPlay: (MediaItem, [MediaItem]) -> Void
    let onFavoriteChanged: (UUID, Bool) -> Void
    let onLibraryChanged: () -> Void
    var onVideoDeleted: (UUID) -> Void = { _ in }
    let onBrowse: () -> Void

    @State private var shelf: Shelf = .favorites
    @State private var importKind: ImportKind = .files
    @State private var isPickingFiles = false
    @State private var isPickingPhotos = false
    @State private var photoSelection: [PhotosPickerItem] = []

    private enum ImportKind { case files, folder }

    private static let videoTypes: [UTType] = [.movie, .video, .mpeg4Movie, .quickTimeMovie]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Shelf", selection: $shelf) {
                    Text("Favorites").tag(Shelf.favorites)
                    // The count, as in "Local 2", once there are videos.
                    if localVideos.items.isEmpty {
                        Text("On this iPhone").tag(Shelf.local)
                    } else {
                        Text("On this iPhone · \(localVideos.items.count)").tag(Shelf.local)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)

                Group {
                    switch shelf {
                    case .favorites: favorites
                    case .local: local
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(.roadCanvas)
            .clearsBottomAccessory()
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if shelf == .local {
                    ToolbarItem(placement: .primaryAction) { importMenu }
                }
            }
            .fileImporter(
                isPresented: $isPickingFiles,
                allowedContentTypes: importKind == .folder ? [.folder] : Self.videoTypes,
                allowsMultipleSelection: importKind != .folder
            ) { result in
                guard case let .success(urls) = result else { return }
                // The presentation flag is reset before this runs; `importKind` is not.
                let kind = importKind
                Task {
                    let added = if kind == .folder, let folder = urls.first {
                        await localVideos.importFolder(folder)
                    } else {
                        await localVideos.importFiles(urls)
                    }
                    if added {
                        onLibraryChanged()
                    }
                }
            }
            .photosPicker(isPresented: $isPickingPhotos, selection: $photoSelection, matching: .videos)
            .onChange(of: photoSelection) { _, picked in importPhotos(picked) }
            .alert(
                title(for: localVideos.problem?.kind),
                isPresented: Binding(
                    get: { localVideos.problem != nil },
                    set: {
                        if !$0 {
                            localVideos.problem = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(localVideos.problem?.message ?? "")
            }
        }
        .task(id: revision) {
            viewModel.load()
            localVideos.load()
        }
    }

    @ViewBuilder private var favorites: some View {
        switch viewModel.phase {
        case .loading:
            LoadingView()
        case .empty:
            EmptyStateView(
                title: "Nothing saved yet",
                message: "Touch and hold any channel, or tap the heart in the player, to keep it here.",
                systemImage: "heart.fill"
            ) {
                PrimaryButton(title: "Browse Home", systemImage: "house.fill", isCompact: true, action: onBrowse)
                    .accessibilityIdentifier("favorites.browse")
            }
        case let .failed(message):
            ErrorView(message: message) { viewModel.load() }
        case .loaded:
            ScrollView {
                // No Delete here: unfavouriting already takes a video off this shelf (owner's choice).
                ChannelGrid(
                    items: viewModel.items,
                    onPlay: { onPlay($0, viewModel.items) },
                    onToggleFavorite: toggle
                )
                .padding(.vertical, Spacing.md)
            }
        }
    }

    @ViewBuilder private var local: some View {
        if localVideos.isImporting {
            LoadingView(message: "Importing…")
        } else if localVideos.items.isEmpty {
            EmptyStateView(
                title: "No videos imported",
                message: "Bring videos over from Photos or Files and play them on the road, no connection needed.",
                systemImage: "film.stack"
            ) {
                Menu {
                    importOptions
                } label: {
                    BrandButtonLabel(title: "Import Now", systemImage: "plus")
                }
                .accessibilityIdentifier("local.import")
            }
        } else {
            ScrollView {
                ChannelGrid(
                    items: localVideos.items,
                    onPlay: { onPlay($0, localVideos.items) },
                    onToggleFavorite: toggle,
                    onDelete: deleteVideo
                )
                .padding(.vertical, Spacing.md)
            }
        }
    }

    @ViewBuilder private var importOptions: some View {
        Button {
            isPickingPhotos = true
        } label: {
            Label("Import from Photos", systemImage: "photo.on.rectangle")
        }
        Button {
            importKind = .files
            isPickingFiles = true
        } label: {
            Label("Import Video Files", systemImage: "film")
        }
        Button {
            importKind = .folder
            isPickingFiles = true
        } label: {
            Label("Import Folder", systemImage: "folder")
        }
    }

    private var importMenu: some View {
        Menu {
            importOptions
        } label: {
            Label("Import Now", systemImage: "plus")
        }
        // One import at a time: the shelf shows "Importing…" until it finishes.
        .disabled(localVideos.isImporting)
        .accessibilityIdentifier("local.importMenu")
    }

    private func title(for kind: LocalVideosViewModel.Problem.Kind?) -> Text {
        switch kind {
        case .load: Text("Couldn't load your videos")
        case .delete: Text("Couldn't delete the video")
        case .importing, nil: Text("Couldn't import")
        }
    }

    private func toggle(_ item: MediaItem) {
        if let isFavorite = viewModel.toggleFavorite(item) {
            onFavoriteChanged(item.id, isFavorite)
        }
    }

    private func deleteVideo(_ item: MediaItem) {
        if localVideos.delete(item) {
            onVideoDeleted(item.id)
        }
    }

    private func importPhotos(_ picked: [PhotosPickerItem]) {
        guard !picked.isEmpty else { return }
        localVideos.beginImport()
        Task {
            var urls: [URL] = []
            for item in picked {
                if let video = try? await item.loadTransferable(type: PickedVideo.self) {
                    urls.append(video.url)
                }
            }
            photoSelection = []
            localVideos.endImport()
            // Picks that failed to export are reported once the rest have been imported.
            let skipped = picked.count - urls.count
            if await localVideos.importFiles(urls, skipped: skipped, removingSourcesAfterwards: true) {
                onLibraryChanged()
            }
        }
    }
}
