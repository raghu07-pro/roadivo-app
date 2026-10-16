import StoreKit
import SwiftUI

/// First launch: onboarding → "Buy a plan" (closable) → the four tabs. Player, Add Source and
/// the paywall sit on top; cross-feature navigation and the Pro gates live only here.
struct RootView: View {
    let environment: AppEnvironment

    private var preferences: Preferences {
        environment.preferences
    }

    private var theme: AppTheme {
        AppTheme.shared
    }

    @Environment(\.scenePhase) private var scenePhase

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
        // Settings › Theme applies at once; the windows carry it to alerts, sheets and system
        // pickers (and back to the iPhone's setting for "System").
        .tint(.roadAccent)
        // Every system font below, sheets included, takes the chosen font style.
        .fontDesign(theme.font.rootDesign)
        .preferredColorScheme(theme.appearance.colorScheme)
        .onChange(of: theme.appearance, initial: true) { theme.applyToWindows() }
        .onChange(of: theme.accent) { theme.applyToWindows() }
        // SwiftUI text follows `Typography` by itself; UIKit's navigation titles need telling.
        .onChange(of: theme.font) { Typography.applyUIKitFonts() }
        // Pro users never need the intro paywall, even if their plan lapses later.
        .onChange(of: environment.proAccess.isPro) { _, isPro in
            if isPro {
                preferences.hasSeenIntroPaywall = true
            }
        }
        // A subscription can lapse while the app sleeps, and no transaction announces it.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await environment.proAccess.refresh() }
            }
        }
    }
}

private struct MainTabView: View {
    let environment: AppEnvironment
    @State private var library: LibraryViewModel
    @State private var favorites: LibraryViewModel
    @State private var localVideos: LocalVideosViewModel
    @State private var carHub: CarHubViewModel
    @State private var sources: SourcesViewModel
    @State private var voiceSearch: VoiceSearchModel
    @State private var updatePrompt: UpdatePromptModel
    /// Set by a purchase or restore, so Home opens once the paywall has closed.
    @State private var goesHomeAfterPaywall = false
    /// Set by a purchase from the player's Car Mode button, so Car Mode opens once the paywall closes.
    @State private var startsCarModeAfterPaywall = false
    /// The mini player's measured height, which every screen keeps clear.
    @State private var miniPlayerHeight: CGFloat = 0

    init(environment: AppEnvironment) {
        self.environment = environment
        let repository = environment.repository
        _library = State(initialValue: LibraryViewModel(repository: repository, scope: .all))
        _favorites = State(initialValue: LibraryViewModel(repository: repository, scope: .favorites))
        _localVideos = State(initialValue: LocalVideosViewModel(repository: repository))
        _carHub = State(initialValue: CarHubViewModel(repository: repository))
        _sources = State(initialValue: SourcesViewModel(repository: repository))
        _voiceSearch = State(initialValue: VoiceSearchModel(speech: environment.speech, playback: environment.playback))
        _updatePrompt = State(initialValue: UpdatePromptModel(checker: environment.updateChecker))
    }

    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL

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
                voiceSearch: voiceSearch,
                onVideoDeleted: videoDeleted
            )
            .miniPlayer(
                playback: playback,
                isPlayerOpen: router.playerSurface != nil,
                height: $miniPlayerHeight,
                onExpand: expandPlayer
            )
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
            .miniPlayer(
                playback: playback,
                isPlayerOpen: router.playerSurface != nil,
                height: $miniPlayerHeight,
                onExpand: expandPlayer
            )
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
            .miniPlayer(
                playback: playback,
                isPlayerOpen: router.playerSurface != nil,
                height: $miniPlayerHeight,
                onExpand: expandPlayer
            )
            .tabItem { Label("Cast to Car", systemImage: "car") }
            .tag(AppRouter.Tab.car)

            SettingsView(
                isPro: isPro,
                currentPlan: environment.proAccess.currentPlan,
                hasSubscription: environment.proAccess.hasSubscription,
                onUpgrade: { router.paywall = .settings },
                sourcesScreen: {
                    SourcesView(
                        viewModel: sources,
                        revision: router.libraryRevision,
                        onAddSource: addSource,
                        onLibraryChanged: sourcesChanged,
                        onPlay: play,
                        onFavoriteChanged: favoriteChanged
                    )
                }
            )
            .miniPlayer(
                playback: playback,
                isPlayerOpen: router.playerSurface != nil,
                height: $miniPlayerHeight,
                onExpand: expandPlayer
            )
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(AppRouter.Tab.settings)
        }
        // "New Version Available", over everything in the tabs.
        .overlay {
            if let release = updatePrompt.release {
                UpdatePromptView(
                    release: release,
                    onUpdate: {
                        if let url = updatePrompt.openStore() {
                            openURL(url)
                        }
                    },
                    onClose: { updatePrompt.close() }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: updatePrompt.release)
        .task { await updatePrompt.check() }
        .onChange(of: router.reviewRequests) {
            // Give the video a moment to start before asking.
            Task {
                try? await Task.sleep(for: .seconds(2)) // Cancelled only if the app goes away.
                requestReview()
            }
        }
        .sheet(isPresented: $router.isAddingSource) {
            AddSourceView(
                viewModel: AddSourceViewModel(repository: environment.repository, plex: environment.plex),
                onFinished: {
                    router.isAddingSource = false
                    router.libraryDidChange()
                    router.selectedTab = .home
                },
                help: { HelpView() }
            )
        }
        .sheet(item: $router.paywall, onDismiss: goHomeAfterPurchase) { reason in
            PaywallView(
                viewModel: PaywallViewModel(access: environment.proAccess, reason: reason),
                onClose: { router.paywall = nil },
                onUnlocked: {
                    goesHomeAfterPaywall = true
                    router.paywall = nil
                }
            )
        }
        .fullScreenCover(item: $router.playerSurface) { surface in
            switch surface {
            case .player:
                PlayerView(
                    viewModel: PlayerViewModel(playback: playback, repository: environment.repository),
                    onMinimize: { router.playerSurface = nil },
                    onClose: {
                        router.playerSurface = nil
                        playback.stop()
                    },
                    onFavoriteChanged: router.libraryDidChange,
                    onCarMode: startCarModeFromPlayer
                )
                // Over the player, so a free user stays where they were; buying goes on into Car Mode.
                .sheet(item: $router.playerPaywall, onDismiss: carModeAfterPlayerPaywall) { reason in
                    PaywallView(
                        viewModel: PaywallViewModel(access: environment.proAccess, reason: reason),
                        onClose: { router.playerPaywall = nil },
                        onUnlocked: {
                            startsCarModeAfterPaywall = true
                            router.playerPaywall = nil
                        }
                    )
                }
            case .carMode:
                CarModeView(playback: playback) { router.playerSurface = .player }
            }
        }
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
        router.playerSurface = .player
        playback.play(item, queue: queue)
    }

    private func startCarMode(resuming item: MediaItem?) {
        guard isPro else {
            router.paywall = .carMode
            return
        }
        if let item {
            // Next and previous (and the steering wheel) step through the item's own group.
            playback.play(item, queue: item.isLocalFile ? localVideos.items : library.queue(for: item))
        }
        router.playerSurface = .carMode
    }

    /// The player's Car Mode button: Pro goes straight in, a free user sees the plans first.
    private func startCarModeFromPlayer() {
        if isPro {
            router.playerSurface = .carMode
        } else {
            router.playerPaywall = .carMode
        }
    }

    private func carModeAfterPlayerPaywall() {
        guard startsCarModeAfterPaywall else { return }
        startsCarModeAfterPaywall = false
        router.playerSurface = .carMode
    }

    /// After buying or restoring, the paywall closes onto Home (the owner's flow).
    private func goHomeAfterPurchase() {
        guard goesHomeAfterPaywall else { return }
        goesHomeAfterPaywall = false
        router.selectedTab = .home
    }

    private func expandPlayer() {
        router.playerSurface = .player
    }

    /// A deleted video leaves the queue, and stops if it's the one playing.
    private func videoDeleted(_ id: UUID) {
        playback.forget([id])
        router.libraryDidChange()
    }

    /// Manage Sources deleted, refreshed or renamed a source. A refresh gives every channel a new id,
    /// so whatever plays stops once its id is gone.
    private func sourcesChanged() {
        if let current = playback.current, !libraryContains(current.id) {
            playback.stop()
        }
        router.libraryDidChange()
    }

    /// Reads the whole library, so it runs only while something plays; a failed read keeps playing.
    private func libraryContains(_ id: UUID) -> Bool {
        guard let items = try? environment.repository.items() else { return true }
        return items.contains { $0.id == id }
    }

    private func favoriteChanged(_ id: UUID, _ isFavorite: Bool) {
        playback.updateFavorite(isFavorite, for: id)
        router.libraryDidChange()
    }
}

private extension View {
    /// The now-playing bar, floating just above the tab bar while the full player is closed (opening
    /// a video goes straight to the player). Its height goes to every screen so content clears it.
    func miniPlayer(
        playback: PlaybackController,
        isPlayerOpen: Bool,
        height: Binding<CGFloat>,
        onExpand: @escaping () -> Void
    ) -> some View {
        let isShown = playback.isActive && !isPlayerOpen
        return overlay(alignment: .bottom) {
            if isShown {
                MiniPlayerBar(playback: playback, onExpand: onExpand)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height.wrappedValue = $0 }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.bottom, Spacing.xs)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .environment(\.bottomAccessoryHeight, isShown ? height.wrappedValue + Spacing.xs * 2 : 0)
    }
}
