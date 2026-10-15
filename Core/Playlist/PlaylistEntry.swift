import Foundation

/// One playable line of an M3U playlist, before it is stored.
struct PlaylistEntry: Equatable, Sendable {
    var name: String
    /// The `group-title` (or `#EXTGRP`) the entry belongs to; empty when the playlist gives none.
    var group: String
    var logoURL: URL?
    var streamURL: URL
    /// A film's year, from a media server.
    var year: Int?
    var artwork: ArtworkStyle = .logo
}
