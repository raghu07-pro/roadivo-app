import Foundation
import Testing
@testable import Roadivo

@Suite("Browser")
@MainActor
struct BrowserViewModelTests {
    /// Pages are never really loaded: the web view's reports are played in by hand.
    private func makeViewModel(onWebMediaStarted: @escaping () -> Void = {}) -> BrowserViewModel {
        let viewModel = BrowserViewModel(onWebMediaStarted: onWebMediaStarted)
        viewModel.web.loader = { _, _ in }
        return viewModel
    }

    @Test("Opening shows the page with its site in the address bar; Start Page goes back")
    func openAndClose() {
        let viewModel = makeViewModel()
        #expect(!viewModel.isShowingPage)

        viewModel.open("www.example.com/path")

        #expect(viewModel.isShowingPage)
        #expect(viewModel.pageURL?.absoluteString == "https://www.example.com/path")
        #expect(viewModel.address == "example.com")
        viewModel.closePage()
        #expect(!viewModel.isShowingPage)
        #expect(viewModel.address.isEmpty)
    }

    @Test("Editing the address shows all of it; leaving shows the site again")
    func editingAddress() {
        let viewModel = makeViewModel()
        viewModel.open("https://example.com/a/b")

        viewModel.isEditingAddress = true
        #expect(viewModel.address == "https://example.com/a/b")
        viewModel.isEditingAddress = false
        #expect(viewModel.address == "example.com")
    }

    @Test("A video on the page plays in Roadivo, named after the page and grouped under its site")
    func takeVideo() throws {
        let viewModel = makeViewModel()
        let page = try #require(URL(string: "https://www.example.com/watch"))
        let video = try #require(URL(string: "https://cdn.example.com/trip.m3u8"))
        viewModel.open(page)
        viewModel.web.onState?(WebPageController.State(url: page, title: "Road Trip"))

        viewModel.web.onVideo?(video)
        #expect(viewModel.foundVideo == video)
        let item = try #require(viewModel.takeVideo())

        #expect(item.streamURL == video)
        #expect(item.title == "Road Trip")
        #expect(item.groupTitle == "example.com")
        #expect(!item.isLocalFile)
        #expect(item.sourceID == nil) // Not saved to the library, so no source is used up.
        #expect(viewModel.foundVideo == nil)
    }

    @Test("A new page drops the last page's video, and a page that starts playing tells Roadivo")
    func navigationAndMedia() throws {
        var mediaStarts = 0
        let viewModel = try makeViewModel { mediaStarts += 1 }
        viewModel.open("example.com")
        try viewModel.web.onVideo?(#require(URL(string: "https://cdn.example.com/a.mp4")))

        viewModel.web.onNavigationStarted?()
        #expect(viewModel.foundVideo == nil)
        viewModel.web.onMediaStarted?()
        #expect(mediaStarts == 1)
    }

    @Test("After Start Page, a late report from the old page doesn't bring it back")
    func lateReports() {
        let viewModel = makeViewModel()
        viewModel.open("example.com")
        viewModel.closePage()

        viewModel.web.onState?(WebPageController.State(url: URL(string: "https://example.com"), isLoading: false))
        #expect(!viewModel.isShowingPage)
    }
}
