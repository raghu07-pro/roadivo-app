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
                // A car or display may have connected while the app was suspended, unannounced.
                environment.carConnection.refreshRoute()
            }
        }
    }
}

private struct MainTabView: View {
    let environment: AppEnvironment
    @State private var library: LibraryViewModel
    @State private var favorites: LibraryViewModel
    @State private var localVideos: LocalVideosViewModel
    @State private var browser: BrowserViewModel
    @State private var sources: SourcesViewModel
    @State private var displayProfiles: DisplayProfilesViewModel
    @State private var voiceSearch: VoiceSearchModel
    @State private var updatePrompt: UpdatePromptModel
    /// Set by a purchase or restore, so Home opens once the paywall has closed.
    @State private var goesHomeAfterPaywall = false
    /// Set by a purchase from the player's Car Mode button, so Car Mode opens once the paywall closes.
    @State private var startsCarModeAfterPaywall = false
    /// The mini player's measured height, which every screen keeps clear.
    @State private var miniPlayerHeight: CGFloat = 0
    /// The saved car or display last acted on, so a route that drops and comes back (a call, CarPlay
    /// reconnecting) doesn't reset Home's source or reopen Car Mode.
    @State private var handledProfileID: UUID?
    @Environment(\.scenePhase) private var scenePhase

    init(environment: AppEnvironment) {
        self.environment = environment
        let repository = environment.repository
        _library = State(initialValue: LibraryViewModel(repository: repository, scope: .all))
        _favorites = State(initialValue: LibraryViewModel(repository: repository, scope: .favorites))
        _localVideos = State(initialValue: LocalVideosViewModel(repository: repository))
        // A web page that starts playing takes over: Roadivo's own video stops, keeping its place, so CarPlay,
        // the lock screen and the steering wheel control the page's video, not a paused one behind it.
        _browser =
            State(initialValue: BrowserViewModel(icons: environment.siteIcons) { [playback = environment.playback] in
                if playback.isActive {
                    playback.stop()
                }
            })
        _sources = State(initialValue: SourcesViewModel(repository: repository, checker: environment.streamChecker))
        _displayProfiles = State(initialValue: DisplayProfilesViewModel(
            store: environment.displayProfiles,
            connection: environment.carConnection,
            repository: repository
        ))
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
                onVideoDeleted: videoDeleted,
                onPlayFromBeginning: playFromBeginning,
                onRemovedFromHistory: removedFromHistory
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

            DiscoverView(
                connection: environment.carConnection,
                isPro: isPro,
                browser: browser,
                onPlayWebVideo: { item in play(item, queue: [item]) },
                onImportVideos: importAndPlay,
                browserRequest: $router.browserRequest
            )
            .miniPlayer(
                playback: playback,
                isPlayerOpen: router.playerSurface != nil,
                height: $miniPlayerHeight,
                onExpand: expandPlayer
            )
            .tabItem { Label("Discover", systemImage: "sparkles.tv") }
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
                },
                profilesScreen: {
                    DisplayProfilesView(viewModel: displayProfiles, isPro: isPro)
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
        // Continue Watching and the progress bars show the place reached once the player is put away
        // or stopped. Only the history is read again; other tabs catch up when they next appear.
        .onChange(of: router.playerSurface) { _, surface in
            if surface == nil {
                reloadHistory()
            }
        }
        .onChange(of: playback.isActive) { _, isActive in
            if !isActive, router.playerSurface == nil {
                reloadHistory()
            }
        }
        // A saved car or display connecting (or already connected at launch) brings its source and Car Mode.
        .onChange(of: environment.carConnection.receiver, initial: true) { _, receiver in
            receiverConnected(receiver)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                receiverConnected(environment.carConnection.receiver) // It may have connected in the background.
            }
        }
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
                CarModeView(playback: playback, isDriveView: Bindable(environment.preferences).prefersDriveView) {
                    router.playerSurface = .player
                }
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

    private func playFromBeginning(_ item: MediaItem, queue: [MediaItem]) {
        router.playerSurface = .player
        playback.play(item, queue: queue, startingOver: true)
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

// MARK: - Watch history and connected screens

extension MainTabView {
    /// A saved screen connects: Home shows its source and Car Mode opens over what's playing, once, in the
    /// foreground and with no sheet up. Its picture and subtitles apply in `AppEnvironment`.
    private func receiverConnected(_ receiver: Receiver?) {
        guard let plan = ReceiverConnectPlan.make(
            profile: environment.displayProfiles.savedProfile(for: receiver),
            handledProfileID: handledProfileID,
            canPresent: scenePhase == .active && router.paywall == nil && router.playerPaywall == nil
                && !router.isAddingSource,
            isPro: isPro,
            isPlaying: playback.isActive
        ) else { return }
        handledProfileID = plan.profileID
        if let source = plan.sourceID {
            library.showSource(source) // A deleted source falls back to all sources on load.
        }
        if plan.opensCarMode {
            router.playerSurface = .carMode
        }
    }

    /// Cast from an app › Your Videos: added to On this iPhone as an import there would be, then the first
    /// new one plays. Any problem is shown on that page, so Favorites doesn't show it again.
    private func importAndPlay(_ urls: [URL], skipped: Int, isTemporary: Bool) async -> String? {
        localVideos.load()
        let earlier = Set(localVideos.items.map(\.id))
        let added = await localVideos.importFiles(urls, skipped: skipped, removingSourcesAfterwards: isTemporary)
        let message = localVideos.problem?.message
        localVideos.problem = nil
        guard added else { return message }
        router.libraryDidChange()
        if let video = localVideos.items.first(where: { !earlier.contains($0.id) }) {
            play(video, queue: localVideos.items)
        }
        return message
    }

    private func reloadHistory() {
        library.reloadHistory()
        favorites.reloadHistory()
    }

    /// Taken out of Continue Watching while it plays, it mustn't save its place straight back.
    private func removedFromHistory(_ id: UUID) {
        playback.forgetProgress(of: id)
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
