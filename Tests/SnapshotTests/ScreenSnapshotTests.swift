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
    private func still(_ view: some View) -> UIHostingController<some View> {
        UIHostingController(rootView: view.environment(\._accessibilityReduceMotion, true))
    }

    private func assertScreen(
        _ view: some View,
        named name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for style in [UIUserInterfaceStyle.light, .dark] {
            assertSnapshot(
                of: still(view),
                as: .image(
                    on: .iPhone13,
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
            as: .image(on: .iPhone13, precision: 0.98, perceptualPrecision: 0.98),
            named: "onboarding-ax3"
        )
    }

    func testPaywall() async {
        let viewModel = PaywallViewModel(access: ProAccess(client: FakeStoreClient()), reason: .intro)
        await viewModel.load()
        assertSnapshot(
            of: still(PaywallView(viewModel: viewModel, onClose: {})),
            as: .image(on: .iPhone13, precision: 0.98, perceptualPrecision: 0.98),
            named: "paywall"
        )
    }

    func testSettings() {
        assertScreen(
            SettingsView(isPro: false, onUpgrade: {}, sourcesScreen: { EmptyView() }),
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
            as: .image(on: .iPhone13, precision: 0.98, perceptualPrecision: 0.98),
            named: "theme-ax3"
        )
    }

    /// Another accent reaches the whole screen: icon tiles, banner and tint.
    func testSettingsInOcean() {
        AppTheme.shared.setAccent(.ocean)
        defer { AppTheme.shared.reset() }
        assertScreen(
            SettingsView(isPro: false, onUpgrade: {}, sourcesScreen: { EmptyView() }),
            named: "settings-ocean"
        )
    }

    func testHome() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        let viewModel = LibraryViewModel(repository: library.repository, scope: .all)
        viewModel.load()
        let view = LibraryView(
            viewModel: viewModel, revision: 0, onPlay: { _, _ in }, onAddSource: {}, onFavoriteChanged: { _, _ in }
        )
        assertScreen(view, named: "home")
    }

    func testEmptyHome() throws {
        let viewModel = try LibraryViewModel(repository: TestLibrary().repository, scope: .all)
        viewModel.load()
        let view = LibraryView(
            viewModel: viewModel, revision: 0, onPlay: { _, _ in }, onAddSource: {}, onFavoriteChanged: { _, _ in }
        )
        assertScreen(view, named: "home-empty")
    }
}
