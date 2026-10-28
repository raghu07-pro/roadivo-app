import SwiftUI

/// The Browser, opened from Discover like CarTV's: a start page with a grid of sites, then the page
/// itself, full screen so a mirrored car display shows the whole page. Pages
/// stay in the Browser rather than opening their apps; a page's own video player has AirPlay, and a
/// direct video can play in PlayCarTV, with Car Mode, instead (DECISIONS 118).
struct BrowserView: View {
    let viewModel: BrowserViewModel
    let onPlay: (MediaItem) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if viewModel.isShowingPage {
                BrowserPage(viewModel: viewModel, onPlay: onPlay)
            } else {
                BrowserStartPage(viewModel: viewModel)
            }
        }
        .background(.roadCanvas)
        .navigationTitle("Browser")
        .navigationBarTitleDisplayMode(.inline)
        // On a page, CarTV's round back button with its menu takes the place of Back.
        .navigationBarBackButtonHidden(viewModel.isShowingPage)
        .toolbar { toolbar }
        // The whole screen for the page, as in CarTV; leaving returns to Discover and its tabs.
        .toolbar(.hidden, for: .tabBar)
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if viewModel.isShowingPage {
            ToolbarItem(placement: .topBarLeading) {
                pageMenu
            }
        }
    }

    /// A tap goes back to the Start Page, as a Back button would; a long press also offers Leave Browser.
    private var pageMenu: some View {
        Menu {
            Button(action: viewModel.closePage) {
                Label("Start Page", systemImage: "square.grid.2x2")
            }
            .accessibilityIdentifier("browser.start")
            Button {
                dismiss()
            } label: {
                Label("Leave Browser", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .accessibilityIdentifier("browser.leave")
        } label: {
            Label("Start Page", systemImage: "chevron.backward")
        } primaryAction: {
            viewModel.closePage()
        }
        .tint(.primary)
        .accessibilityIdentifier("browser.menu")
    }
}

#Preview("Start page") {
    NavigationStack { BrowserView(viewModel: BrowserViewModel(), onPlay: { _ in }) }
}

#Preview("Start page, largest text, dark") {
    NavigationStack { BrowserView(viewModel: BrowserViewModel(), onPlay: { _ in }) }
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility3)
}
