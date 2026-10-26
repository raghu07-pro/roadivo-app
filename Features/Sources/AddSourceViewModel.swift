import Foundation
import Observation

@Observable
@MainActor
final class AddSourceViewModel {
    /// A playlist link, or M3U text pasted or scanned from a QR code.
    var input = "" {
        didSet {
            if input != oldValue {
                parsedInput = SourceInput(input)
            }
        }
    }

    /// `input`, classified once per change: the view reads it several times per redraw.
    private(set) var parsedInput = SourceInput.empty
    private(set) var isWorking = false
    var errorMessage: String?

    private let repository: LibraryRepository
    private let plex: PlexLinking

    init(repository: LibraryRepository, plex: PlexLinking = ScriptedPlexLinking()) {
        self.repository = repository
        self.plex = plex
    }

    var canSubmit: Bool {
        guard !isWorking else { return false }
        switch parsedInput {
        case .link, .content: return true
        case .empty, .unusable: return false
        }
    }

    /// Shown under the field once the text can't be used; not while a link is still being typed ("h", "https://").
    var showsUnusableWarning: Bool {
        guard parsedInput == .unusable else { return false }
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isTypingLink = !text.contains(where: \.isWhitespace)
            && ["https://", "http://"].contains { $0.hasPrefix(text) || text.hasPrefix($0) }
        return !isTypingLink
    }

    func makeServerLogin(_ kind: MediaServerKind) -> ServerLoginViewModel {
        ServerLoginViewModel(kind: kind, repository: repository)
    }

    func makePlexLogin() -> PlexLoginViewModel {
        PlexLoginViewModel(plex: plex, repository: repository)
    }

    /// Returns true when the playlist was added.
    func submit() async -> Bool {
        switch parsedInput {
        case let .link(url):
            // Named after its host; renamed in Manage Sources if wanted.
            return await perform { try await self.repository.addRemotePlaylist(name: "", url: url) }
        case let .content(text):
            let title = String(appLocalized: "Pasted Playlist")
            return await perform { try await self.repository.addFilePlaylist(name: title, text: text) }
        case .empty, .unusable:
            errorMessage = LibraryError.invalidURL.localizedDescription
            return false
        }
    }

    func importPlaylistFile(_ result: Result<URL, Error>) async -> Bool {
        switch result {
        case let .failure(error):
            errorMessage = error.localizedDescription
            return false
        case let .success(url):
            return await perform {
                let scoped = url.startAccessingSecurityScopedResource()
                defer {
                    if scoped {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                let text = try PlaylistText.decode(Data(contentsOf: url))
                let title = url.deletingPathExtension().lastPathComponent
                try await self.repository.addFilePlaylist(name: title, text: text)
            }
        }
    }

    /// Fills the field from a scanned or picked QR code.
    func useScanned(_ text: String?) {
        guard let text, !text.isEmpty else {
            errorMessage = String(appLocalized: "No QR code was found in that image.")
            return
        }
        errorMessage = nil
        input = text
    }

    private func perform(_ work: () async throws -> some Any) async -> Bool {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            _ = try await work()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
