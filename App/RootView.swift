import StoreKit
import SwiftUI

/// First launch: onboarding → "Buy a plan" (closable) → the four tabs.
/// Player surfaces, Add Source and the paywall sit on top. Cross-feature
/// navigation and the Pro gates live only here.
struct RootView: View {
    let environment: AppEnvironment

    private var preferences: Preferences {
        environment.preferences
    }

    var body: some View {
        Group {
            if !preferences.hasCompletedOnboarding {
                OnboardingView(viewModel: OnboardingViewModel { [preferences] in
                    preferences.hasCompletedOnboarding = true
                })
                .transition(.opacity)
            } else if !preferences.hasSeenIntroPaywall, !environment.proAccess.isPro {
                PaywallView(viewModel: PaywallViewModel(access: environment.proAccess, reason: .intro)) {
                    preferences.hasSeenIntroPaywall = true
                }
                .transition(.move(edge: .bottom))
            } else {
                MainTabView(environment: environment)
            }
        }
        .animation(.default, value: preferences.hasCompletedOnboarding)
        .animation(.default, value: preferences.hasSeenIntroPaywall)
    }
}

private struct MainTabView: View {
    let environment: AppEnvironment
    @State private var library: LibraryViewModel
    @State private var favorites: LibraryViewModel
    @State private var localVideos: LocalVideosViewModel
    @State private var carHub: CarHubViewModel
    @State private var sources: SourcesViewModel

    init(environment: AppEnvironment) {
        self.environment = environment
        let repository = environment.repository
        _library = State(initialValue: LibraryViewModel(repository: repository, scope: .all))
        _favorites = State(initialValue: LibraryViewModel(repository: repository, scope: .favorites))
        _localVideos = State(initialValue: LocalVideosViewModel(repository: repository))
        _carHub = State(initialValue: CarHubViewModel(repository: repository))
        _sources = State(initialValue: SourcesViewModel(repository: repository))
    }

    @Environment(\.requestReview) private var requestReview

    private var router: AppRouter {
        environment.router
    }

    private var playback: PlaybackController {
        environment.playback
    }

    private var isPro: Bool {
        environment.proAccess.isPro
    }

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            LibraryView(
                viewModel: library,
                revision: router.libraryRevision,
                onPlay: play,
                onAddSource: addSource,
                onFavoriteChanged: favoriteChanged,
                onVideoDeleted: videoDeleted
            )
            .miniPlayerInset(playback: playback, onExpand: expandPlayer)
            .tabItem { Label("Home", systemImage: "house") }
            .tag(AppRouter.Tab.home)

            FavoritesView(
                viewModel: favorites,
                localVideos: localVideos,
                revision: router.libraryRevision,
                onPlay: play,
                onFavoriteChanged: favoriteChanged,
                onLibraryChanged: router.libraryDidChange,
                onVideoDeleted: videoDeleted,
                onBrowse: { router.selectedTab = .home }
            )
            .miniPlayerInset(playback: playback, onExpand: expandPlayer)
            .tabItem { Label("Favorites", systemImage: "heart") }
            .tag(AppRouter.Tab.favorites)

            CarHubView(
                viewModel: carHub,
                playback: playback,
                connection: environment.carConnection,
                isPro: isPro,
                revision: router.libraryRevision,
                onStartCarMode: startCarMode,
                onUpgrade: { router.paywall = .carMode },
                onBrowse: { router.selectedTab = .home }
            )
            .miniPlayerInset(playback: playback, onExpand: expandPlayer)
            .tabItem { Label("Cast to Car", systemImage: "car") }
            .tag(AppRouter.Tab.car)

            SettingsView(
                isPro: isPro,
                onUpgrade: { router.paywall = .settings },
                onAddSource: addSource,
                sourcesScreen: {
                    SourcesView(
                        viewModel: sources,
                        revision: router.libraryRevision,
                        onAddSource: addSource,
                        onLibraryChanged: router.libraryDidChange
                    )
                }
            )
            .miniPlayerInset(playback: playback, onExpand: expandPlayer)
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(AppRouter.Tab.settings)
        }
        .tint(.roadAccent)
        .onChange(of: router.reviewRequests) {
            // Give the video a moment to start before asking.
            Task {
                try? await Task.sleep(for: .seconds(2)) // Cancelled only if the app goes away.
                requestReview()
            }
        }
        .sheet(isPresented: $router.isAddingSource) {
            AddSourceView(
                viewModel: AddSourceViewModel(repository: environment.repository),
                onFinished: {
                    router.isAddingSource = false
                    router.libraryDidChange()
                    router.selectedTab = .home
                },
                help: { HelpView() }
            )
        }
        .sheet(item: $router.paywall) { reason in
            paywall(reason) { router.paywall = nil }
        }
        .fullScreenCover(item: $router.playerSurface) { surface in
            switch surface {
            case .player:
                PlayerView(
                    viewModel: PlayerViewModel(playback: playback, repository: environment.repository),
                    onMinimize: { router.playerSurface = nil },
                    onCarMode: { router.playerSurface = isPro ? .carMode : .carModePaywall },
                    onFavoriteChanged: router.libraryDidChange
                )
            case .carMode:
                CarModeView(playback: playback) { router.playerSurface = .player }
            case .carModePaywall:
                // Buying goes straight on to Car Mode; closing returns to the player.
                paywall(.carMode) {
                    router.playerSurface = environment.proAccess.isPro ? .carMode : .player
                }
            }
        }
    }

    private func paywall(_ reason: PaywallReason, onClose: @escaping () -> Void) -> some View {
        PaywallView(viewModel: PaywallViewModel(access: environment.proAccess, reason: reason), onClose: onClose)
    }

    /// Free users get one source; the next one asks for Pro.
    private func addSource() {
        if isPro || environment.repository.sourceCount() < ProAccess.freeSourceLimit {
            router.isAddingSource = true
        } else {
            router.paywall = .sources
        }
    }

    private func play(_ item: MediaItem, queue: [MediaItem]) {
        playback.play(item, queue: queue)
        router.playerSurface = .player
    }

    private func startCarMode(resuming item: MediaItem?) {
        guard isPro else {
            router.paywall = .carMode
            return
        }
        if let item {
            playback.play(item, queue: [item])
        }
        router.playerSurface = .carMode
    }

    private func expandPlayer() {
        router.playerSurface = .player
    }

    /// A deleted video can't keep playing.
    private func videoDeleted(_ id: UUID) {
        if playback.current?.id == id {
            playback.stop()
        }
        router.libraryDidChange()
    }

    private func favoriteChanged(_ id: UUID, _ isFavorite: Bool) {
        playback.updateFavorite(isFavorite, for: id)
        router.libraryDidChange()
    }
}

private extension View {
    func miniPlayerInset(playback: PlaybackController, onExpand: @escaping () -> Void) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            if playback.isActive {
                MiniPlayerBar(playback: playback, onExpand: onExpand)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.bottom, Spacing.xs)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}
