import SwiftUI

/// Home: "Continue Watching", then one carousel per playlist group, with search.
struct LibraryView: View {
    let viewModel: LibraryViewModel
    let revision: Int
    let onPlay: (MediaItem, [MediaItem]) -> Void
    let onAddSource: () -> Void
    let onFavoriteChanged: (UUID, Bool) -> Void
    let voiceSearch: VoiceSearchModel
    var onVideoDeleted: (UUID) -> Void = { _ in }

    @Environment(\.openURL) private var openURL

    /// Carousels show this many before "See All".
    private let carouselLimit = 20

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            content
                .background(.roadCanvas)
                .safeAreaInset(edge: .top, spacing: 0) {
                    SearchField(
                        text: $viewModel.query,
                        prompt: "Search channels and titles",
                        isListening: voiceSearch.isListening
                    ) {
                        voiceSearch.toggle { viewModel.query = $0 }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.xs)
                    .background(.roadCanvas)
                }
                .navigationTitle("Home")
                .navigationDestination(for: LibraryGroupRoute.self) { route in
                    GroupDetailView(
                        viewModel: viewModel,
                        title: route.title,
                        onPlay: play,
                        onToggleFavorite: toggleFavorite
                    )
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: onAddSource) {
                            Label("Add Source", systemImage: "plus")
                        }
                        .accessibilityIdentifier("library.addSource")
                    }
                }
                .alert("Allow Voice Search", isPresented: alertBinding(.denied)) {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Turn on Microphone and Speech Recognition for Roadivo in Settings to search by voice.")
                }
                .alert("Voice search isn't available right now.", isPresented: alertBinding(.failed)) {
                    Button("OK", role: .cancel) {}
                }
        }
        .task(id: revision) { viewModel.load() }
        .onDisappear { voiceSearch.cancel() }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.phase {
        case .loading:
            LoadingView()
        case .empty:
            EmptyLibraryView(onAddSource: onAddSource)
        case let .failed(message):
            ErrorView(message: message) { viewModel.load() }
        case .loaded:
            if viewModel.isSearching, viewModel.filtered.isEmpty {
                ContentUnavailableView.search(text: viewModel.query)
            } else {
                sectionsList
            }
        }
    }

    private var sectionsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                if !viewModel.isSearching {
                    HomeHero(channelCount: viewModel.items.count, groupCount: viewModel.sections.count)
                        .padding(.horizontal, Spacing.md)
                }
                if !viewModel.isSearching, !viewModel.recent.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        SectionHeader(
                            title: String(appLocalized: "Continue Watching"),
                            count: viewModel.recent.count,
                            systemImage: "clock.arrow.circlepath"
                        ) {
                            EmptyView()
                        }
                        .padding(.horizontal, Spacing.md)
                        ChannelCarousel(
                            items: viewModel.recent,
                            onPlay: { play($0, nil) },
                            onToggleFavorite: toggleFavorite,
                            onDelete: deleteVideo
                        )
                    }
                }
                ForEach(viewModel.sections) { section in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        SectionHeader(title: section.title, count: section.items.count) {
                            if section.items.count > carouselLimit {
                                NavigationLink(value: LibraryGroupRoute(title: section.title)) {
                                    Text("See All").font(Typography.secondary.weight(.semibold))
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                        ChannelCarousel(
                            items: Array(section.items.prefix(carouselLimit)),
                            onPlay: { play($0, section.items) },
                            onToggleFavorite: toggleFavorite,
                            onDelete: deleteVideo
                        )
                    }
                }
            }
            .padding(.vertical, Spacing.md)
        }
    }

    private func alertBinding(_ state: VoiceSearchModel.State) -> Binding<Bool> {
        Binding(
            get: { voiceSearch.state == state },
            set: {
                if !$0 {
                    voiceSearch.dismissAlert()
                }
            }
        )
    }

    private func play(_ item: MediaItem, _ queue: [MediaItem]?) {
        onPlay(item, queue ?? viewModel.queue(for: item))
    }

    private func deleteVideo(_ item: MediaItem) {
        if viewModel.deleteVideo(item) {
            onVideoDeleted(item.id)
        }
    }

    private func toggleFavorite(_ item: MediaItem) {
        if let isFavorite = viewModel.toggleFavorite(item) {
            onFavoriteChanged(item.id, isFavorite)
        }
    }
}

private struct EmptyLibraryView: View {
    let onAddSource: () -> Void

    var body: some View {
        EmptyStateView(
            title: "Your library is empty",
            message: """
            Add an M3U link or connect a media server, and your channels land here. Videos you import are in \
            Favorites › On this iPhone.
            """,
            systemImage: "play.square.stack"
        ) {
            VStack(spacing: Spacing.sm) {
                PrimaryButton(title: "Add a Source", systemImage: "plus", isCompact: true, action: onAddSource)
                    .accessibilityIdentifier("library.empty.addSource")
                Text("M3U · Jellyfin · Emby · Plex · Xtream")
                    .font(Typography.data)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct GroupDetailView: View {
    let viewModel: LibraryViewModel
    let title: String
    let onPlay: (MediaItem, [MediaItem]?) -> Void
    let onToggleFavorite: (MediaItem) -> Void

    var body: some View {
        let items = viewModel.items(inGroup: title)
        ScrollView {
            ChannelGrid(items: items, onPlay: { onPlay($0, items) }, onToggleFavorite: onToggleFavorite)
                .padding(.vertical, Spacing.md)
        }
        .background(.roadCanvas)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
