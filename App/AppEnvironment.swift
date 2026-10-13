import Foundation
import Observation
import OSLog

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
    let carConnection = CarConnection()

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
        preferences: Preferences
    ) {
        self.apiClient = apiClient
        self.store = store
        self.preferences = preferences
        repository = LibraryRepository(
            store: store, secureStore: secureStore, fetcher: fetcher, mediaServers: mediaServers
        )
        proAccess = ProAccess(client: storeClient)
        playback = PlaybackController()
        router = AppRouter()
        playback.onItemStarted = { [repository, preferences, router] item in
            repository.markPlayed(item.id)
            preferences.videosOpened += 1
            if ReviewMilestones.shouldAsk(afterOpening: preferences.videosOpened) {
                router.requestReview()
            }
        }
    }

    /// Launch arguments used by UI tests and screenshot runs:
    /// `-ui-testing` (in-memory everything and a fake App Store),
    /// `-skip-onboarding` (also skips the intro paywall), `-pro` (the fake
    /// store starts with Pro), and in Debug builds `-demo-library` (seeds the
    /// demo playlist).
    static func live(arguments: [String]) -> AppEnvironment {
        let isUITesting = arguments.contains("-ui-testing")
        let logger = Logger(subsystem: "com.roadivo", category: "App")

        let store: SwiftDataStore
        do {
            store = try SwiftDataStore(inMemory: isUITesting)
        } catch {
            // A corrupt on-disk store must not brick the app: fall back to memory
            // for this launch and log it.
            logger.fault("Store failed to open: \(error.localizedDescription, privacy: .public)")
            store = memoryStore()
        }

        // UI tests start in "Follow System" (or a language passed with
        // -AppleLanguages), never a choice left behind by an earlier run.
        if isUITesting {
            AppLanguage.shared.set(nil)
        }
        let preferences = Preferences(defaults: isUITesting ? volatileDefaults() : .standard)
        if arguments.contains("-skip-onboarding") {
            preferences.hasCompletedOnboarding = true
            preferences.hasSeenIntroPaywall = true
        }
        let storeClient: StoreClient = isUITesting
            ? FakeStoreClient(isPro: arguments.contains("-pro"))
            : StoreKitClient()

        let environment = AppEnvironment(
            apiClient: (try? AppInfo.apiBaseURL()).map { APIClient(baseURL: $0) },
            store: store,
            secureStore: isUITesting ? InMemorySecureStore() : KeychainStore(),
            fetcher: URLSessionPlaylistFetcher(),
            mediaServers: EmbyCompatibleClient(deviceID: preferences.deviceID),
            storeClient: storeClient,
            preferences: preferences
        )
        environment.router.asksForReviews = !isUITesting
        environment.proAccess.start()
        environment.carConnection.start()
        current = environment
        #if DEBUG
            if arguments.contains("-demo-library") {
                Task { await DemoLibrary.seed(into: environment) }
            }
        #endif
        return environment
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
