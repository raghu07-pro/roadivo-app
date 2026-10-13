import SnapshotTesting
import SwiftUI
import XCTest
@testable import Roadivo

/// Visual regression for the key screens, light and dark. Reference images
/// live in __Snapshots__; record new ones by deleting the old image and running
/// the test once (it fails the recording run, then passes).
@MainActor
final class ScreenSnapshotTests: XCTestCase {
    private func assertScreen(
        _ view: some View,
        named name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for style in [UIUserInterfaceStyle.light, .dark] {
            assertSnapshot(
                of: UIHostingController(rootView: view),
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
            of: UIHostingController(rootView: view),
            as: .image(on: .iPhone13, precision: 0.98, perceptualPrecision: 0.98),
            named: "onboarding-ax3"
        )
    }

    func testPaywall() async {
        let viewModel = PaywallViewModel(access: ProAccess(client: FakeStoreClient()), reason: .intro)
        await viewModel.load()
        assertSnapshot(
            of: UIHostingController(rootView: PaywallView(viewModel: viewModel, onClose: {})),
            as: .image(on: .iPhone13, precision: 0.98, perceptualPrecision: 0.98),
            named: "paywall"
        )
    }

    func testSettings() {
        assertScreen(
            SettingsView(isPro: false, onUpgrade: {}, onAddSource: {}, sourcesScreen: { EmptyView() }),
            named: "settings"
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
