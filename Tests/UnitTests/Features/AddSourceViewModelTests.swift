import Foundation
import Testing
@testable import Roadivo

@Suite("Add source")
@MainActor
struct AddSourceViewModelTests {
    @Test("Accepts http(s) links and pasted M3U text; flags anything else")
    func validation() throws {
        let viewModel = try AddSourceViewModel(repository: TestLibrary().repository)
        #expect(!viewModel.canSubmit)
        #expect(!viewModel.showsUnusableWarning)
        viewModel.input = "not a link"
        #expect(!viewModel.canSubmit)
        #expect(viewModel.showsUnusableWarning)
        viewModel.input = "ftp://e.com/list.m3u"
        #expect(!viewModel.canSubmit)
        viewModel.input = "  https://e.com/list.m3u  "
        #expect(try viewModel.parsedInput == .link(#require(URL(string: "https://e.com/list.m3u"))))
        viewModel.input = Fixtures.playlist
        #expect(viewModel.parsedInput == .content(Fixtures.playlist))
        #expect(viewModel.canSubmit)
    }

    @Test("M3U text counts only with a playable link; a header and junk alone is flagged")
    func m3uDetection() throws {
        let viewModel = try AddSourceViewModel(repository: TestLibrary().repository)
        viewModel.input = "#EXTM3U\n#EXTINF:-1,No link\nnot a url\nlive/relative.m3u8"
        #expect(viewModel.parsedInput == .unusable)
        #expect(viewModel.showsUnusableWarning)

        let lowercase = "#extm3u\r\n#extinf:-1,Late link\r\nnot a url\r\nrtmp://cdn.example.com/live/2"
        viewModel.input = lowercase
        #expect(viewModel.parsedInput == .content(lowercase))
        #expect(viewModel.canSubmit)

        viewModel.input = "Just some notes\nhttps://e.com/a.m3u8"
        #expect(viewModel.parsedInput == .unusable)
        viewModel.input = ""
        #expect(viewModel.parsedInput == .empty)
    }

    @Test("A 100 000-line paste is recognised from its first link")
    func bigPaste() throws {
        let viewModel = try AddSourceViewModel(repository: TestLibrary().repository)
        let text = bigPlaylist(100_000)
        viewModel.input = text
        #expect(viewModel.parsedInput == .content(text))
    }

    @Test("A good link adds the playlist, named after its host")
    func success() async throws {
        let library = try TestLibrary()
        library.fetcher.stub(Fixtures.playlistURL, with: Fixtures.playlist)
        let viewModel = AddSourceViewModel(repository: library.repository)
        viewModel.input = Fixtures.playlistURL.absoluteString

        #expect(await viewModel.submit())
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isWorking)
        #expect(try library.repository.playlists().map(\.name) == ["iptv.example.com"])
    }

    @Test("Pasted M3U text is added as a playlist without any download")
    func pastedContent() async throws {
        let library = try TestLibrary()
        let viewModel = AddSourceViewModel(repository: library.repository)
        viewModel.input = Fixtures.playlist

        #expect(await viewModel.submit())
        #expect(library.fetcher.requested.isEmpty)
        #expect(try library.repository.playlists().map(\.name) == ["Pasted Playlist"])
        #expect(try library.repository.items().count == 4)
    }

    @Test("A failing link shows a readable error and adds nothing")
    func failure() async throws {
        let library = try TestLibrary()
        let viewModel = AddSourceViewModel(repository: library.repository)
        viewModel.input = "https://e.com/missing.m3u"

        #expect(await !viewModel.submit())
        #expect(viewModel.errorMessage == LibraryError.httpStatus(404).localizedDescription)
        #expect(try library.repository.playlists().isEmpty)
    }

    @Test("Importing an .m3u file names the playlist after the file")
    func fileImport() async throws {
        let library = try TestLibrary()
        let file = FileManager.default.temporaryDirectory.appending(path: "Road Trip.m3u")
        try Fixtures.playlist.write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }
        let viewModel = AddSourceViewModel(repository: library.repository)

        #expect(await viewModel.importPlaylistFile(.success(file)))
        #expect(try library.repository.playlists().map(\.name) == ["Road Trip"])
        #expect(try library.repository.items().count == 4)
    }
}
