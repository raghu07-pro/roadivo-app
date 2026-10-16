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
}
