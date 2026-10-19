import SnapshotTesting
import SwiftUI
import XCTest
@testable import Roadivo

/// Visual regression for the key screens, light and dark. To re-record, delete the reference image
/// in __Snapshots__ and run once (the recording run fails, the next passes).
@MainActor
final class ScreenSnapshotTests: XCTestCase {
    /// Every snapshot is drawn in the default theme (System, Golden Hour), whatever
    /// was last picked on this simulator.
    override func setUp() async throws {
        try await super.setUp()
        AppTheme.shared.reset()
    }

    /// Hosts `view` with Reduce Motion on, so the road scenes hold still (their moving dashes made
    /// every capture differ) and appear-animations end on their final frame.
    private func still(
        _ view: some View,
        style: UIUserInterfaceStyle = .unspecified
    ) -> UIHostingController<some View> {
        // The app's accent tint, as RootView applies it, so buttons are coloured as on a phone.
        let host = UIHostingController(rootView: view.tint(.roadAccent).environment(\._accessibilityReduceMotion, true))
        // The navigation bar follows this, not the snapshot traits: without it, titles drew white on light.
        host.overrideUserInterfaceStyle = style
        return host
    }

    /// Screens draw through the real window (`drawHierarchyInKeyWindow`): iOS 26's glass navigation
    /// bar otherwise renders its title white on a light screen, unlike the app.
    private func assertScreen(
        _ view: some View,
        named name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for style in [UIUserInterfaceStyle.light, .dark] {
            assertSnapshot(
                of: still(view, style: style),
                as: .image(
                    on: .iPhone13,
                    drawHierarchyInKeyWindow: true,
                    precision: 0.98,
                    perceptualPrecision: 0.98,
                    traits: UITraitCollection(userInterfaceStyle: style)
                ),
                named: "\(name)-\(style == .dark ? "dark" : "light")",
                file: file,
                testName: name,
                line: line
            )
        }
    }

    func testOnboarding() {
        assertScreen(OnboardingView(viewModel: OnboardingViewModel {}), named: "onboarding")
    }

    func testOnboardingLargestText() {
        let view = OnboardingView(viewModel: OnboardingViewModel {})
            .environment(\.dynamicTypeSize, .accessibility3)
        assertSnapshot(
            of: still(view),
            as: .image(on: .iPhone13, drawHierarchyInKeyWindow: true, precision: 0.98, perceptualPrecision: 0.98),
            named: "onboarding-ax3"
        )
    }

    func testPaywall() async {
        let viewModel = PaywallViewModel(access: ProAccess(client: FakeStoreClient()), reason: .intro)
        await viewModel.load()
        assertSnapshot(
            of: still(PaywallView(viewModel: viewModel, onClose: {})),
            as: .image(on: .iPhone13, drawHierarchyInKeyWindow: true, precision: 0.98, perceptualPrecision: 0.98),
            named: "paywall"
        )
    }

    func testSettings() {
        assertScreen(
            SettingsView(isPro: false, onUpgrade: {}, sourcesScreen: { EmptyView() }, profilesScreen: { EmptyView() }),
            named: "settings"
        )
    }

    func testTheme() {
        assertScreen(NavigationStack { ThemeView(viewModel: ThemeViewModel()) }, named: "theme")
    }

    func testThemeLargestText() {
        let view = NavigationStack { ThemeView(viewModel: ThemeViewModel()) }
            .environment(\.dynamicTypeSize, .accessibility3)
        assertSnapshot(
            of: still(view),
            as: .image(on: .iPhone13, drawHierarchyInKeyWindow: true, precision: 0.98, perceptualPrecision: 0.98),
            named: "theme-ax3"
        )
    }

    /// Another accent reaches the whole screen: icon tiles, banner and tint.
    func testSettingsInOcean() {
        AppTheme.shared.setAccent(.ocean)
        defer { AppTheme.shared.reset() }
        assertScreen(
            SettingsView(isPro: false, onUpgrade: {}, sourcesScreen: { EmptyView() }, profilesScreen: { EmptyView() }),
            named: "settings-ocean"
        )
    }

    /// Continue Watching mixing a channel, a film's poster and an episode: every card is drawn wide at
    /// full size (the poster cropped), the in-progress ones with their bar and time left.
    func testContinueWatchingMixedShapes() throws {
        let item = { (title: String, artwork: ArtworkStyle, progress: PlaybackProgress?) throws in
            try MediaItem(
                id: UUID(),
                title: title,
                group: "",
                artworkURL: nil,
                streamURL: XCTUnwrap(URL(string: "https://streams.example.com/\(title.count).m3u8")),
                isLocalFile: false,
                isFavorite: false,
                artwork: artwork,
                progress: progress
            )
        }
        let items = try [
            item("Andorra TV", .logo, nil),
            item("Jungle Book", .poster, PlaybackProgress(position: 1500, duration: 4860)),
            item("S1 · E2 — Night Drive", .still, PlaybackProgress(position: 900, duration: 2700))
        ]
        let view = ChannelCarousel(items: items, onPlay: { _ in }, onToggleFavorite: { _ in })
            .padding(.vertical)
            .frame(width: 390)
            .background(.roadCanvas)
        for style in [UIUserInterfaceStyle.light, .dark] {
            assertSnapshot(
                of: still(view),
                as: .image(
                    precision: 0.98,
                    perceptualPrecision: 0.98,
                    size: CGSize(width: 390, height: 200),
                    traits: UITraitCollection(userInterfaceStyle: style)
                ),
                named: "continue-watching-\(style == .dark ? "dark" : "light")"
            )
        }
    }

    /// Drive View on a landscape iPhone and an iPhone SE: a two-line title, the error with Try Again (the
    /// fullest state, from a missing file, no network) and the three buttons pinned in view.
    func testCarModeDriveView() {
        let playback = PlaybackController()
        let item = MediaItem(
            id: UUID(),
            title: "Steel Horizon · 1080p Director's Cut",
            group: "Movies",
            artworkURL: nil,
            streamURL: URL(fileURLWithPath: "/dev/null/steel.mp4"),
            isLocalFile: false,
            isFavorite: false
        )
        let next = MediaItem(
            id: UUID(),
            title: "Highway Stop",
            group: "Movies",
            artworkURL: nil,
            streamURL: item.streamURL,
            isLocalFile: false,
            isFavorite: false
        )
        playback.play(item, queue: [item, next])
        let deadline = Date().addingTimeInterval(10)
        while playback.status == .loading, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05)) // Waits on the state, not a fixed time.
        }
        guard case .failed = playback.status else { return XCTFail("The missing file never failed") }
        let view = CarModeDriveView(playback: playback, onExitDriveView: {}, onExit: {})
            .background(Color.black)
            .environment(\.colorScheme, .dark)
        let traits = UITraitCollection(traitsFrom: [
            UITraitCollection(verticalSizeClass: .compact),
            UITraitCollection(horizontalSizeClass: .compact),
            UITraitCollection(userInterfaceStyle: .dark)
        ])
        for (name, size) in [
            ("drive-view", CGSize(width: 844, height: 390)),
            ("drive-view-se", CGSize(width: 667, height: 375))
        ] {
            assertSnapshot(
                of: still(view, style: .dark),
                as: .image(precision: 0.98, perceptualPrecision: 0.98, size: size, traits: traits),
                named: name
            )
        }
        playback.stop()
    }

    /// No artwork shows the coloured cover; artwork still loading shows the skeleton, not the cover.
    func testArtworkLoadingStates() throws {
        let loading = try XCTUnwrap(URL(string: "https://logos.invalid/channel.png"))
        let view = HStack(spacing: Spacing.sm) {
            ArtworkTile(title: "Highway Stop", imageURL: nil)
            ArtworkTile(title: "Coastal Echoes", imageURL: loading)
        }
        .padding()
        .frame(width: 390)
        .background(.roadCanvas)
        for style in [UIUserInterfaceStyle.light, .dark] {
            assertSnapshot(
                of: still(view),
                as: .image(
                    precision: 0.98,
                    perceptualPrecision: 0.98,
                    size: CGSize(width: 390, height: 140),
                    traits: UITraitCollection(userInterfaceStyle: style)
                ),
                named: "artwork-\(style == .dark ? "dark" : "light")"
            )
        }
    }

    func testHome() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        let viewModel = LibraryViewModel(repository: library.repository, scope: .all)
        viewModel.load()
        let view = LibraryView(
            viewModel: viewModel,
            revision: 0,
            onPlay: { _, _ in },
            onAddSource: {},
            onFavoriteChanged: { _, _ in },
            voiceSearch: VoiceSearchModel(speech: ScriptedSpeechTranscriber(phrase: ""))
        )
        assertScreen(view, named: "home")
    }

    func testEmptyHome() throws {
        let viewModel = try LibraryViewModel(repository: TestLibrary().repository, scope: .all)
        viewModel.load()
        let view = LibraryView(
            viewModel: viewModel,
            revision: 0,
            onPlay: { _, _ in },
            onAddSource: {},
            onFavoriteChanged: { _, _ in },
            voiceSearch: VoiceSearchModel(speech: ScriptedSpeechTranscriber(phrase: ""))
        )
        assertScreen(view, named: "home-empty")
    }
}

// MARK: - Up Next

extension ScreenSnapshotTests {
    /// Up Next where it's tightest: the upright player at the largest text, Car Mode's video on an iPhone SE
    /// and Drive View's pinned bar. It once covered the player's buttons and cut its own labels.
    func testUpNextCountdown() throws {
        let library = try TestLibrary()
        let playback = PlaybackController()
        let item = MediaItem(
            id: UUID(),
            title: "Midnight Courier · 4K HDR",
            group: "Movies",
            artworkURL: nil,
            streamURL: URL(fileURLWithPath: "/dev/null"),
            isLocalFile: false,
            isFavorite: false
        )
        playback.upNext = UpNext(item: item, secondsLeft: 3, total: 5)
        let player = PlayerView(
            viewModel: PlayerViewModel(playback: playback, repository: library.repository),
            onMinimize: {},
            onClose: {},
            onFavoriteChanged: {},
            onCarMode: {}
        )
        .environment(\.dynamicTypeSize, .accessibility3)
        let upright = UITraitCollection(traitsFrom: [
            UITraitCollection(verticalSizeClass: .regular),
            UITraitCollection(horizontalSizeClass: .compact),
            UITraitCollection(userInterfaceStyle: .dark)
        ])
        assertSnapshot(
            of: still(player, style: .dark),
            as: .image(
                precision: 0.98,
                perceptualPrecision: 0.98,
                size: CGSize(width: 390, height: 844),
                traits: upright
            ),
            named: "player-largest-text"
        )
        let landscape = UITraitCollection(traitsFrom: [
            UITraitCollection(verticalSizeClass: .compact),
            UITraitCollection(horizontalSizeClass: .compact),
            UITraitCollection(userInterfaceStyle: .dark)
        ])
        for (name, isDriveView) in [("car-mode-se", false), ("drive-view", true)] {
            let carMode = CarModeView(playback: playback, isDriveView: .constant(isDriveView), onExit: {})
            let size = isDriveView ? CGSize(width: 844, height: 390) : CGSize(width: 667, height: 375)
            assertSnapshot(
                of: still(carMode, style: .dark),
                as: .image(precision: 0.98, perceptualPrecision: 0.98, size: size, traits: landscape),
                named: name
            )
        }
        playback.cancelUpNext()
    }
}
