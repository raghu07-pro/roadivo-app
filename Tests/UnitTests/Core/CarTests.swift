import AVFoundation
import Foundation
import Testing
@testable import Roadivo

@Suite("Car")
@MainActor
struct CarTests {
    @Test("Routes: AirPlay destination and car audio are read from the outputs")
    func routes() {
        let connection = CarConnection()
        connection.apply([RouteOutput(.airPlay, "Car Display"), RouteOutput(.builtInSpeaker, "Speaker")])
        #expect(connection.airPlayDestination == "Car Display")
        #expect(!connection.isCarAudio)

        connection.apply([RouteOutput(.carAudio, "CarPlay")])
        #expect(connection.airPlayDestination == nil)
        #expect(connection.isCarAudio)
    }

    @Test("Car Mode reopens in Drive View when it was left that way")
    func driveViewRemembered() throws {
        let defaults = try #require(UserDefaults(suiteName: "roadivo.tests.\(UUID().uuidString)"))
        #expect(!Preferences(defaults: defaults).prefersDriveView)
        Preferences(defaults: defaults).prefersDriveView = true
        #expect(Preferences(defaults: defaults).prefersDriveView)
    }

    @Test("CarPlay menu mirrors favourites, recent and groups in playlist order")
    func menu() async throws {
        let library = try TestLibrary()
        try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        let items = try library.repository.items()
        try library.repository.toggleFavorite(items[2].id)
        library.repository.markPlayed(items[0].id)

        let menu = CarPlayMenu.build(from: library.repository)

        #expect(menu.favorites.map(\.title) == ["Football Live"])
        #expect(menu.recent.map(\.title) == ["News One"])
        #expect(menu.groups.map(\.title) == ["News", "Sports", "Other"])
        #expect(menu.groups.first?.items.count == 2)
    }

    @Test("CarPlay menu stays inside CarPlay's list limits")
    func menuLimit() async throws {
        let library = try TestLibrary()
        let rows = (0..<150).map { "#EXTINF:-1 group-title=\"Big\",Ch \($0)\nhttps://e.com/\($0).m3u8" }
        try await library.repository.addFilePlaylist(name: "Big", text: rows.joined(separator: "\n"))
        let menu = CarPlayMenu.build(from: library.repository)
        #expect(menu.groups.first?.items.count == CarPlayMenu.itemLimit)
    }

    @Test("A car that allows fewer rows gets fewer, and Library's list of groups is capped too")
    func menuFollowsTheCarsLimit() async throws {
        let library = try TestLibrary()
        let rows = (0..<30).flatMap { group in
            (0..<20).map { "#EXTINF:-1 group-title=\"G\(group)\",Ch \(group)-\($0)\nhttps://e.com/\(group)/\($0).m3u8" }
        }
        try await library.repository.addFilePlaylist(name: "Many", text: rows.joined(separator: "\n"))

        let menu = CarPlayMenu.build(from: library.repository, limit: 12)

        #expect(menu.groups.count == 12)
        #expect(menu.groups.allSatisfy { $0.items.count == 12 })
        #expect(CarPlayMenu.build(from: library.repository, limit: 500).groups.count == 30)
    }

    @Test("CarPlay's Browser tab lists the Browser's sites, within the car's limit")
    func menuSites() throws {
        let library = try TestLibrary()
        #expect(CarPlayMenu.build(from: library.repository).sites == BrowserSite.all)
        #expect(CarPlayMenu.build(from: library.repository, limit: 12).sites.count == 12)
    }

    @Test("CarPlay's Browser icons are split into rows no longer than CarPlay allows, every site once, in order")
    func menuSiteRows() throws {
        let library = try TestLibrary()
        let menu = CarPlayMenu.build(from: library.repository)
        let rows = menu.siteRows(perRow: 5)
        #expect(rows.allSatisfy { (1...5).contains($0.count) })
        #expect(rows.flatMap(\.self) == menu.sites)
        #expect(menu.siteRows(perRow: 0).flatMap(\.self) == menu.sites)
    }

    @Test("A CarPlay video row picks up where a film stopped; an unplayed channel's length is unknown (0)")
    func videoTimes() throws {
        let url = try #require(URL(string: "https://e.com/film.m3u8"))
        var film = MediaItem(
            id: UUID(),
            title: "Film",
            group: "Films",
            artworkURL: nil,
            streamURL: url,
            isLocalFile: false,
            isFavorite: false
        )
        #expect(CarPlayMenu.videoTimes(for: film) == (0, 0))

        film.progress = PlaybackProgress(position: 1200, duration: 6000)
        #expect(CarPlayMenu.videoTimes(for: film) == (1200, 6000))

        film.progress = PlaybackProgress(position: 30, duration: 6000) // Under a minute in: starts over.
        #expect(CarPlayMenu.videoTimes(for: film) == (0, 6000))
    }

    @Test("A site picked on CarPlay opens in Discover's Browser")
    func siteFromCarPlay() throws {
        let router = AppRouter()
        let site = try #require(BrowserSite.all.first)
        router.openInBrowser(site.url)
        #expect(router.selectedTab == .car)
        #expect(router.browserRequest == site.url)
    }
}
