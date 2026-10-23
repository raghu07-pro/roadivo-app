import Foundation
import Observation
import OSLog
import SwiftData

/// The composition root: builds every service once and hands them to features.
@Observable
@MainActor
final class AppEnvironment {
    let apiClient: APIClient?
    let store: SwiftDataStore
    let repository: LibraryRepository
    let playback: PlaybackController
    let preferences: Preferences
    let router: AppRouter
    let proAccess: ProAccess
    let speech: SpeechTranscribing
    let plex: PlexLinking
    /// The App Store's newest version, for "New Version Available"; nil in UI tests.
    let updateChecker: AppUpdateChecking?
    let carConnection = CarConnection()
    /// Source Health's stream check; scripted in UI tests, so they never open real streams.
    let streamChecker: StreamChecker
    /// Settings per car or display, applied to the player whenever the connected screen changes.
    let displayProfiles: DisplayProfileStore
    /// The Browser's site icons, shared by Discover and the CarPlay screen's Browser tab.
    let siteIcons = SiteIconStore.onDevice()
    /// Discover's Browser; the CarPlay screen offers its page's video (DECISIONS 134).
    let browser: BrowserViewModel
    /// Directions' place search and routes, and the iPhone's location; scripted in UI tests (DECISIONS 145).
    let places: PlaceFinding
    let location: LocationProviding
    /// The Directions tab, shared with the CarPlay map so both show the same place and routes (DECISIONS 147).
    let directions: DirectionsViewModel
    /// Whether the car is parked, so Roadivo's CarPlay window shows video only then (DECISIONS 152).
    let parking: ParkingMonitor

    enum DirectionsSetup {
        /// Apple Maps and the iPhone's own location.
        case live
        /// Two places and two routes from a fixed spot, with no network; Location on or off.
        case scripted(isLocationDenied: Bool)
    }

    /// The running app's environment, for the CarPlay scene: it is created by
    /// the system, not by SwiftUI, so it can't be handed one.
    private(set) static var current: AppEnvironment?

    init(
        apiClient: APIClient?,
        store: SwiftDataStore,
        secureStore: SecureStore,
        fetcher: PlaylistFetching,
        mediaServers: MediaServerConnecting,
        storeClient: StoreClient,
        preferences: Preferences,
        speech: SpeechTranscribing = SpeechTranscriber(),
        plex: PlexLinking = ScriptedPlexLinking(),
        updateChecker: AppUpdateChecking? = nil,
        streamChecker: StreamChecker = .live,
        displayProfiles: DisplayProfileStore = DisplayProfileStore(),
        directions: DirectionsSetup = .live
    ) {
        parking = ParkingMonitor(sampler: LocationMotionSampler())
        switch directions {
        case .live:
            places = MapKitPlaceFinder()
            location = DeviceLocation()
        case let .scripted(isLocationDenied):
            places = ScriptedPlaceFinder()
            location = ScriptedLocation(status: isLocationDenied ? .denied : .allowed)
        }
        self.directions = DirectionsViewModel(finder: places, location: location)
        self.apiClient = apiClient
        self.streamChecker = streamChecker
        self.displayProfiles = displayProfiles
        self.speech = speech
        self.plex = plex
        self.updateChecker = updateChecker
        self.store = store
        self.preferences = preferences
        repository = LibraryRepository(
            store: store, secureStore: secureStore, fetcher: fetcher, mediaServers: mediaServers
        )
        proAccess = ProAccess(client: storeClient)
        playback = PlaybackController()
        playback.progressStore = repository
        router = AppRouter()
        // A web page that starts playing takes over: Roadivo's own video stops, keeping its place, so CarPlay,
        // the lock screen and the steering wheel control the page's video, not a paused one behind it.
        browser = BrowserViewModel(icons: siteIcons) { [playback] in
            if playback.isActive {
                playback.stop()
            }
        }
        playback.onItemStarted = { [repository, preferences, router] item in
            repository.markPlayed(item.id)
            preferences.videosOpened += 1
            if ReviewMilestones.shouldAsk(afterOpening: preferences.videosOpened) {
                router.requestReview()
            }
        }
        // The connected screen's profile, or This iPhone's, whenever either changes.
        // Weak: the connection and the store keep this closure, which would otherwise keep them.
        let applyProfile = { [weak playback, weak carConnection, weak displayProfiles] in
            guard let playback, let carConnection, let displayProfiles else { return }
            playback.apply(displayProfiles.profile(for: carConnection.receiver))
        }
        carConnection.onReceiverChange = { _ in applyProfile() }
        displayProfiles.onChange = applyProfile
        applyProfile()
    }

    /// Launch arguments for UI tests and screenshots: `-ui-testing` (in-memory, fake App Store, scripted mic),
    /// `-skip-onboarding` (and the intro paywall), `-pro`, `-car-connected`, and Debug-only `-demo-library`
    /// (with `-demo-history`, a film part-watched and a channel played) and `-car-parked` (DECISIONS 152).
    static func live(arguments: [String]) -> AppEnvironment {
        let switches = TestSwitches(arguments: arguments)
        let isUITesting = switches.isUITesting
        let logger = Logger(subsystem: "com.roadivo", category: "App")

        let store = openLibrary(inMemory: isUITesting, logger: logger)
        let secureStore: SecureStore = isUITesting ? InMemorySecureStore() : KeychainStore()
        clearSecretsFromEarlierInstall(secureStore, library: store, logger: logger)

        // UI tests start in Follow System (or a language from -AppleLanguages) and the default
        // theme, never a choice left by an earlier run.
        if isUITesting {
            AppLanguage.shared.set(nil)
            AppTheme.shared.reset()
        }
        // One instance: making a second would clear the first's test settings.
        let defaults = isUITesting ? volatileDefaults() : .standard
        let preferences = Preferences(defaults: defaults)
        if switches.skipsOnboarding {
            preferences.hasCompletedOnboarding = true
            preferences.hasSeenIntroPaywall = true
        }
        let environment = AppEnvironment(
            apiClient: (try? AppInfo.apiBaseURL()).map { APIClient(baseURL: $0) },
            store: store,
            secureStore: secureStore,
            fetcher: URLSessionPlaylistFetcher(),
            mediaServers: MediaServerRouter(
                embyCompatible: EmbyCompatibleClient(deviceID: preferences.deviceID),
                plex: PlexClient(clientID: preferences.deviceID)
            ),
            storeClient: storeClient(isUITesting: isUITesting, arguments: arguments),
            preferences: preferences,
            speech: isUITesting && !arguments.contains("-live-voice")
                ? ScriptedSpeechTranscriber(phrase: voicePhrase(in: arguments))
                : SpeechTranscriber(),
            plex: isUITesting ? ScriptedPlexLinking() : PlexClient(clientID: preferences.deviceID),
            updateChecker: isUITesting ? nil : AppStoreUpdateChecker(
                bundleID: Bundle.main.bundleIdentifier ?? "",
                country: Locale.current.region?.identifier ?? "US"
            ),
            streamChecker: isUITesting ? StreamChecker(probe: ScriptedStreamProbe()) : .live,
            displayProfiles: DisplayProfileStore(defaults: defaults),
            directions: isUITesting ? .scripted(isLocationDenied: switches.isLocationDenied) : .live
        )
        environment.parking.assumesParkedCar = switches.isCarParked
        environment.router.asksForReviews = !isUITesting
        // UI tests tap and audit the Up Next card and the player's controls; real 5 s and 3 s timers could run out
        // mid-step on a busy simulator.
        if isUITesting {
            environment.playback.upNextDelay = 120
            environment.playback.controlsHideDelay = .seconds(120)
        }
        environment.proAccess.start()
        environment.carConnection.simulatedOutputs = switches.isCarConnected ? [RouteOutput(.carAudio, "CarPlay")] : nil
        environment.carConnection.start()
        current = environment
        #if DEBUG
            if arguments.contains("-demo-library") {
                Task { await DemoLibrary.seed(into: environment, withHistory: arguments.contains("-demo-history")) }
            }
        #endif
        return environment
    }

    /// UI tests get a fake App Store (`-pro` starts with Pro, `-restorable` has a Yearly plan to restore).
    private static func storeClient(isUITesting: Bool, arguments: [String]) -> StoreClient {
        guard isUITesting else { return StoreKitClient() }
        return FakeStoreClient(
            isPro: arguments.contains("-pro"),
            restorable: arguments.contains("-restorable") ? [.yearly] : []
        )
    }

    /// iOS keeps Keychain items after the app is deleted, so a reinstall would inherit old logins. Cleared
    /// once per install; never when the library has sources (an update) or is memory-only (UI tests).
    private static func clearSecretsFromEarlierInstall(
        _ secureStore: SecureStore,
        library: SwiftDataStore,
        logger: Logger
    ) {
        let defaults = UserDefaults.standard
        let flag = "roadivo.keychainInitialized"
        let isOnDisk = library.container.configurations.allSatisfy { !$0.isStoredInMemoryOnly }
        guard isOnDisk, !defaults.bool(forKey: flag) else { return }
        // A failed count keeps the secrets: wiping a live library's logins is worse than a stale item.
        let sourceCount = (try? library.mainContext.fetchCount(FetchDescriptor<Playlist>())) ?? 1
        if sourceCount == 0 {
            do {
                try secureStore.removeAll()
            } catch {
                // The flag stays unset, so this is tried again next launch.
                logger.error("Keychain cleanup failed: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
        defaults.set(true, forKey: flag)
    }

    /// What the scripted microphone "hears" in UI tests: `-voice-phrase <text>`, else "Football".
    private static func voicePhrase(in arguments: [String]) -> String {
        guard let index = arguments.firstIndex(of: "-voice-phrase"), arguments.indices.contains(index + 1) else {
            return "Football"
        }
        return arguments[index + 1]
    }

    /// A corrupt on-disk store must not brick the app: it falls back to memory for this launch, logged.
    private static func openLibrary(inMemory: Bool, logger: Logger) -> SwiftDataStore {
        do {
            return try SwiftDataStore(inMemory: inMemory)
        } catch {
            logger.fault("Store failed to open: \(error.localizedDescription, privacy: .public)")
            return memoryStore()
        }
    }

    private static func memoryStore() -> SwiftDataStore {
        do {
            return try SwiftDataStore(inMemory: true)
        } catch {
            fatalError("An in-memory SwiftData store cannot fail to open: \(error)")
        }
    }

    private static func volatileDefaults() -> UserDefaults {
        let name = "roadivo.uitests"
        UserDefaults().removePersistentDomain(forName: name)
        return UserDefaults(suiteName: name) ?? .standard
    }
}

/// UI-test launch switches, honoured only in Debug: a shipped build never gets the fake App Store
/// or free Pro. A struct, so Release doesn't flag the test-only branches as dead code.
private struct TestSwitches {
    let isUITesting: Bool
    let skipsOnboarding: Bool
    /// `-car-connected`: the iPhone acts as if plugged into a car, for the car-connected paths.
    let isCarConnected: Bool
    /// `-location-denied`: Location is off for Roadivo, for Directions' "turn it on" path.
    let isLocationDenied: Bool
    /// `-car-parked`: the car always says it's stopped, so the CarPlay window shows video at a desk (DECISIONS 154).
    let isCarParked: Bool

    init(arguments: [String]) {
        #if DEBUG
            isUITesting = arguments.contains("-ui-testing")
            skipsOnboarding = arguments.contains("-skip-onboarding")
            isCarConnected = isUITesting && arguments.contains("-car-connected")
            isLocationDenied = isUITesting && arguments.contains("-location-denied")
            isCarParked = arguments.contains("-car-parked")
        #else
            isUITesting = false
            skipsOnboarding = false
            isCarConnected = false
            isLocationDenied = false
            isCarParked = false
        #endif
    }
}
