import SwiftUI

/// Home: "Continue Watching", then one carousel per playlist group, with search.
struct LibraryView: View {
    let viewModel: LibraryViewModel
    let revision: Int
    let onPlay: (MediaItem, [MediaItem]) -> Void
    let onAddSource: () -> Void
    let onFavoriteChanged: (UUID, Bool) -> Void
    var onVideoDeleted: (UUID) -> Void = { _ in }

    /// Carousels show this many before "See All".
    private let carouselLimit = 20

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            content
                .background(.roadCanvas)
                .navigationTitle("Home")
                .navigationDestination(for: LibrarySection.self) { section in
                    GroupDetailView(section: section, onPlay: play, onToggleFavorite: toggleFavorite)
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: onAddSource) {
                            Label("Add Source", systemImage: "plus")
                        }
                        .accessibilityIdentifier("library.addSource")
                    }
                }
                .searchable(text: $viewModel.query, prompt: Text("Search channels and titles"))
        }
        .task(id: revision) { viewModel.load() }
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
                                NavigationLink(value: section) {
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
        ContentUnavailableView {
            Label("Your library is empty", systemImage: "play.square.stack")
        } description: {
            Text("Add an M3U playlist link or file, or import videos from your iPhone.")
        } actions: {
            PrimaryButton(title: "Add a Source", systemImage: "plus", isCompact: true, action: onAddSource)
                .accessibilityIdentifier("library.empty.addSource")
        }
    }
}

struct GroupDetailView: View {
    let section: LibrarySection
    let onPlay: (MediaItem, [MediaItem]?) -> Void
    let onToggleFavorite: (MediaItem) -> Void

    var body: some View {
        ScrollView {
            ChannelGrid(items: section.items, onPlay: { onPlay($0, section.items) }, onToggleFavorite: onToggleFavorite)
                .padding(.vertical, Spacing.md)
        }
        .background(.roadCanvas)
        .navigationTitle(section.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
