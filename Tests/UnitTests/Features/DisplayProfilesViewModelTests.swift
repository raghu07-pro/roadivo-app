import Foundation
import Testing
@testable import Roadivo

@Suite("Car & Display Profiles screens")
@MainActor
struct DisplayProfilesViewModelTests {
    private let airPlay = RouteOutput(.airPlay, "Living Room TV", uid: "AA:BB-airplay")

    private struct Setup {
        let viewModel: DisplayProfilesViewModel
        let store: DisplayProfileStore
        let connection: CarConnection
        let library: TestLibrary
    }

    private func make() throws -> Setup {
        let library = try TestLibrary()
        let defaults = try #require(UserDefaults(suiteName: "roadivo.tests.\(UUID().uuidString)"))
        let store = DisplayProfileStore(defaults: defaults)
        let connection = CarConnection()
        let viewModel = DisplayProfilesViewModel(store: store, connection: connection, repository: library.repository)
        return Setup(viewModel: viewModel, store: store, connection: connection, library: library)
    }

    @Test("A connected screen with no profile is offered for saving; once saved it's the one in use")
    func saveConnectedScreen() throws {
        let setup = try make()
        let viewModel = setup.viewModel
        let store = setup.store
        let connection = setup.connection
        #expect(viewModel.unsavedReceiver == nil)
        #expect(viewModel.saveCurrentReceiver() == nil)

        connection.apply([airPlay])
        #expect(viewModel.unsavedReceiver?.name == "Living Room TV")
        #expect(viewModel.activeID == store.thisIPhone.id)

        let id = try #require(viewModel.saveCurrentReceiver())
        #expect(viewModel.unsavedReceiver == nil)
        #expect(viewModel.activeID == id)
        #expect(viewModel.saved.map(\.displayName) == ["Living Room TV"])
    }

    @Test("Deleting a profile puts This iPhone back in use")
    func delete() throws {
        let setup = try make()
        let viewModel = setup.viewModel
        let store = setup.store
        let connection = setup.connection
        connection.apply([airPlay])
        let id = try #require(viewModel.saveCurrentReceiver())

        viewModel.delete(id)

        #expect(viewModel.saved.isEmpty)
        #expect(viewModel.activeID == store.thisIPhone.id)
        #expect(viewModel.unsavedReceiver != nil)
    }

    @Test("Every editor change is saved at once")
    func editorSaves() async throws {
        let setup = try make()
        let viewModel = setup.viewModel
        let store = setup.store
        let connection = setup.connection
        let library = setup.library
        let source = try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        connection.apply([airPlay])
        let id = try #require(viewModel.saveCurrentReceiver())
        let editor = try #require(viewModel.editor(for: id))
        editor.loadSources()

        editor.name = "Lounge"
        editor.aspect = .stretch
        editor.playsNextAutomatically = false
        editor.opensCarMode = true
        editor.preferredSourceID = source

        let saved = try #require(store.profile(id: id))
        #expect(saved.name == "Lounge")
        #expect(saved.aspect == .stretch)
        #expect(!saved.playsNextAutomatically)
        #expect(saved.opensCarMode)
        #expect(saved.preferredSourceID == source)
        #expect(editor.sources.map(\.name) == ["TV"])
    }

    @Test("Subtitles On starts in the app's language and keeps the language picked")
    func subtitles() throws {
        let setup = try make()
        let viewModel = setup.viewModel
        let store = setup.store
        let editor = try #require(viewModel.editor(for: store.thisIPhone.id))
        #expect(editor.subtitleSetting == .automatic)

        editor.subtitleSetting = .on
        let appLanguage = AppLanguage.shared.locale.language.languageCode?.identifier ?? "en"
        #expect(store.thisIPhone.subtitles == .on(language: appLanguage))
        #expect(editor.subtitleLanguages.contains(appLanguage))

        editor.subtitleLanguage = "ko"
        #expect(store.thisIPhone.subtitles == .on(language: "ko"))
        editor.subtitleSetting = .off
        #expect(store.thisIPhone.subtitles == .off)
    }

    @Test("A preferred source that was deleted reads as Any Source")
    func deletedSource() async throws {
        let setup = try make()
        let viewModel = setup.viewModel
        let store = setup.store
        let connection = setup.connection
        let library = setup.library
        let source = try await library.repository.addFilePlaylist(name: "TV", text: Fixtures.playlist)
        connection.apply([airPlay])
        let id = try #require(viewModel.saveCurrentReceiver())
        try #require(viewModel.editor(for: id)).preferredSourceID = source

        try await library.repository.delete(source)

        let reopened = try #require(viewModel.editor(for: id))
        reopened.loadSources()
        #expect(reopened.preferredSourceID == nil)
        #expect(store.profile(id: id)?.preferredSourceID == source) // Kept until changed; harmless.
    }
}
