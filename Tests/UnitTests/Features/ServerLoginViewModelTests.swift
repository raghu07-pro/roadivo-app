import Foundation
import Testing
@testable import Roadivo

@Suite("Server login")
@MainActor
struct ServerLoginViewModelTests {
    @Test("Needs an address and username; Xtream also needs a password")
    func validation() throws {
        let library = try TestLibrary()
        let jellyfin = ServerLoginViewModel(kind: .jellyfin, repository: library.repository)
        #expect(!jellyfin.canConnect)
        jellyfin.address = "nas.local:8096"
        jellyfin.username = "dad"
        #expect(jellyfin.canConnect)

        let xtream = ServerLoginViewModel(kind: .xtream, repository: library.repository)
        xtream.address = "panel.example.com"
        xtream.username = "me"
        #expect(!xtream.canConnect)
        xtream.password = "pw"
        #expect(xtream.canConnect)
    }

    @Test("Connecting adds the server; a failure shows a readable error")
    func connect() async throws {
        let library = try TestLibrary()
        let viewModel = ServerLoginViewModel(kind: .emby, repository: library.repository)
        viewModel.address = "nas.local"
        viewModel.username = "dad"
        viewModel.password = "wrong"
        #expect(await !viewModel.connect())
        #expect(viewModel.errorMessage == MediaServerError.badCredentials.localizedDescription)

        viewModel.password = "pw"
        #expect(await viewModel.connect())
        #expect(try library.repository.playlists().count == 1)
    }
}
