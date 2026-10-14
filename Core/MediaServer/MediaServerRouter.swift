import Foundation

/// Sends each account to its own client: Plex to `PlexClient`, Jellyfin and Emby to the shared one.
struct MediaServerRouter: MediaServerConnecting {
    let embyCompatible: EmbyCompatibleClient
    let plex: PlexClient

    func signIn(kind: MediaServerKind, baseURL: URL, username: String, password: String) async throws
        -> MediaServerAccount {
        try await embyCompatible.signIn(kind: kind, baseURL: baseURL, username: username, password: password)
    }

    func library(for account: MediaServerAccount) async throws -> [PlaylistEntry] {
        account.kind == .plex ? try await plex.library(for: account) : try await embyCompatible.library(for: account)
    }
}
