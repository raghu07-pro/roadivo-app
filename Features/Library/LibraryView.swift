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
    /// Continue Watching's "Play from Beginning".
    var onPlayFromBeginning: (MediaItem, [MediaItem]) -> Void = { _, _ in }
    /// An item left Continue Watching: the player stops keeping its place and the other screens reload.
    var onRemovedFromHistory: (UUID) -> Void = { _ in }

    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Carousels show this many; the group's header opens the rest.
    private let carouselLimit = 20

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            content
                .background(.roadCanvas)
                .clearsBottomAccessory()
                .safeAreaInset(edge: .top, spacing: 0) {
                    // Always shown, empty library or not (owner's choice, 2026-10-15).
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
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: LibraryGroupRoute.self) { route in
                    GroupDetailView(
                        viewModel: viewModel,
                        title: route.title,
                        onPlay: play,
                        onToggleFavorite: toggleFavorite
                    )
                }
                .toolbar {
                    // One button: Add with no sources yet, then the source menu (which also adds).
                    ToolbarItem(placement: .primaryAction) {
                        if viewModel.sources.isEmpty {
                            Button(action: onAddSource) {
                                Label("Add Source", systemImage: "plus")
                            }
                            .accessibilityIdentifier("library.addSource")
                        } else {
                            sourceMenu
                        }
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
                    Text("Turn on Microphone and Speech Recognition for PlayCarTV in Settings to search by voice.")
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
                    HomeHero(
                        channelCount: viewModel.items.count,
                        groupCount: viewModel.sections.count,
                        sourceName: viewModel.sources.first { $0.id == viewModel.sourceFilter }?.name
                    )
                    .padding(.horizontal, Spacing.md)
                }
                if !viewModel.isSearching, !viewModel.recent.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        // No count: it holds films and episodes as well as channels.
                        ShelfHeader(title: String(appLocalized: "Continue Watching"))
                            .padding(.horizontal, Spacing.md)
                        ChannelCarousel(
                            items: viewModel.recent,
                            onPlay: { play($0, nil) },
                            onToggleFavorite: toggleFavorite,
                            onDelete: deleteVideo,
                            onPlayFromBeginning: playFromBeginning,
                            onRemoveFromHistory: removeFromHistory
                        )
                        // Tells these cards from the same titles in the group rows.
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("library.continueWatching")
                    }
                }
                ForEach(viewModel.sections) { section in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        // The whole header opens the group, with chips to move to the others.
                        NavigationLink(value: LibraryGroupRoute(title: section.title)) {
                            GroupHeader(section: section)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityHint(Text("Shows the whole group"))
                        .accessibilityIdentifier("library.seeAll.\(section.title)")
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
        .scrollDismissesKeyboard(.immediately)
    }

    private var shownSourceName: String {
        viewModel.sources.first { $0.id == viewModel.sourceFilter }?.name ?? String(appLocalized: "All Sources")
    }

    /// Which source Home shows, with each source's channel count, and Add Source.
    private var sourceMenu: some View {
        Menu {
            Picker(
                selection: Binding(get: { viewModel.sourceFilter }, set: { viewModel.showSource($0) })
            ) {
                Text("All Sources (\(viewModel.sources.reduce(0) { $0 + $1.count }))")
                    .tag(UUID?.none)
                ForEach(viewModel.sources) { source in
                    Text("\(source.name) (\(source.count))")
                        .tag(UUID?.some(source.id))
                }
            } label: {
                Text("Sources")
            }
            .pickerStyle(.inline)
            Button(action: onAddSource) {
                Label("Add Source", systemImage: "plus")
            }
            .accessibilityIdentifier("library.menu.addSource")
        } label: {
            Label(
                "Show Source",
                systemImage: viewModel.sourceFilter == nil
                    ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill"
            )
        }
        .accessibilityValue(Text(shownSourceName))
        .accessibilityIdentifier("library.sourceFilter")
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
        dismissKeyboard()
        onPlay(item, queue ?? viewModel.queue(for: item))
    }

    /// The keyboard would come back over the tab bar when the player closes.
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func deleteVideo(_ item: MediaItem) {
        if viewModel.deleteVideo(item) {
            onVideoDeleted(item.id)
        }
    }

    private func playFromBeginning(_ item: MediaItem) {
        dismissKeyboard()
        onPlayFromBeginning(item, viewModel.queue(for: item))
    }

    private func removeFromHistory(_ item: MediaItem) {
        withAnimation(reduceMotion ? nil : .default) {
            if viewModel.removeFromHistory(item) {
                onRemovedFromHistory(item.id)
            }
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
                    .foregroundStyle(.roadMuted)
            }
        }
    }
}

/// A group's own screen (from its header on Home): a grid, with chips to switch group.
struct GroupDetailView: View {
    let viewModel: LibraryViewModel
    let onPlay: (MediaItem, [MediaItem]?) -> Void
    let onToggleFavorite: (MediaItem) -> Void
    @State private var group: String

    init(
        viewModel: LibraryViewModel,
        title: String,
        onPlay: @escaping (MediaItem, [MediaItem]?) -> Void,
        onToggleFavorite: @escaping (MediaItem) -> Void
    ) {
        self.viewModel = viewModel
        self.onPlay = onPlay
        self.onToggleFavorite = onToggleFavorite
        _group = State(initialValue: title)
    }

    var body: some View {
        // Read live, so a favourite changed here shows at once.
        let items = viewModel.items(inGroup: group)
        ScrollViewReader { proxy in
            ScrollView {
                ChannelGrid(items: items, onPlay: { onPlay($0, items) }, onToggleFavorite: onToggleFavorite)
                    .padding(.vertical, Spacing.md)
                    .id(group)
            }
            .onChange(of: group) { proxy.scrollTo(group, anchor: .top) }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if viewModel.sections.count > 1 {
                CategoryChips(
                    chips: viewModel.sections.map { .init(id: $0.title, title: $0.title) },
                    selection: $group,
                    identifier: "group"
                )
                .padding(.bottom, Spacing.xxs)
                .background(.roadCanvas)
            }
        }
        .background(.roadCanvas)
        .clearsBottomAccessory()
        .navigationTitle(group)
        .navigationBarTitleDisplayMode(.inline)
    }
}
