import Foundation

/// Plex sign-in without plex.tv, for UI tests and previews: code "RDVO", never confirmed.
struct ScriptedPlexLinking: PlexLinking {
    func createPin() async throws -> PlexPin {
        PlexPin(id: 1, code: "RDVO", expiresAt: Date().addingTimeInterval(900))
    }

    func token(for pin: PlexPin) async throws -> String? {
        nil
    }

    func servers(token: String) async throws -> [PlexServer] {
        throw PlexError.noServers
    }

    func account(for server: PlexServer) async throws -> MediaServerAccount {
        throw PlexError.serverUnreachable
    }
}
