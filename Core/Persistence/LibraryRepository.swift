import Foundation
import OSLog
import SwiftData

/// The one gateway features use to read and change the library.
@MainActor
final class LibraryRepository {
    private let store: SwiftDataStore
    private let writer: LibraryWriter
    private let secureStore: SecureStore
    private let fetcher: PlaylistFetching
    private let mediaServers: MediaServerConnecting
    private let fileManager: FileManager
    private let logger = Logger(subsystem: "com.roadivo", category: "Library")

    init(
        store: SwiftDataStore,
        secureStore: SecureStore,
        fetcher: PlaylistFetching,
        mediaServers: MediaServerConnecting,
        fileManager: FileManager = .default
    ) {
        self.store = store
        self.secureStore = secureStore
        self.fetcher = fetcher
        self.mediaServers = mediaServers
        self.fileManager = fileManager
        writer = LibraryWriter(modelContainer: store.container)
    }

    private var context: ModelContext {
        store.mainContext
    }

    // MARK: Reading

    func playlists() throws -> [Playlist] {
        try context.fetch(FetchDescriptor<Playlist>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    /// Sources that count toward the free limit: everything except the
    /// "On this iPhone" shelf.
    func sourceCount() -> Int {
        let local = PlaylistKind.localVideos.rawValue
        let descriptor = FetchDescriptor<Playlist>(predicate: #Predicate { $0.kindRaw != local })
        // A failed count reads as zero: the worst case is one extra free source.
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// Every channel in playlist order, optionally limited to one playlist.
    func items(in playlistID: UUID? = nil) throws -> [MediaItem] {
        var descriptor = FetchDescriptor<Channel>(sortBy: [SortDescriptor(\.sortIndex)])
        if let playlistID {
            descriptor.predicate = #Predicate { $0.playlist?.id == playlistID }
        }
        let channels = try context.fetch(descriptor)
        // Keep playlists in the order they were added, channels in file order.
        let order = try Dictionary(uniqueKeysWithValues: playlists().enumerated().map { ($1.id, $0) })
        return channels
            .sorted { lhs, rhs in
                let left = lhs.playlist.flatMap { order[$0.id] } ?? .max
                let right = rhs.playlist.flatMap { order[$0.id] } ?? .max
                return left == right ? lhs.sortIndex < rhs.sortIndex : left < right
            }
            .compactMap(\.mediaItem)
    }

    func favorites() throws -> [MediaItem] {
        let descriptor = FetchDescriptor<Channel>(
            predicate: #Predicate { $0.isFavorite },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor).compactMap(\.mediaItem)
    }

    /// Imported video files ("On this iPhone"), in import order.
    func localVideos() throws -> [MediaItem] {
        guard let playlist = try existingLocalVideosPlaylist() else { return [] }
        return playlist.channels.sorted { $0.sortIndex < $1.sortIndex }.compactMap(\.mediaItem)
    }

    func recentlyPlayed(limit: Int = 12) throws -> [MediaItem] {
        var descriptor = FetchDescriptor<Channel>(
            predicate: #Predicate { $0.lastPlayedAt != nil },
            sortBy: [SortDescriptor(\.lastPlayedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor).compactMap(\.mediaItem)
    }

    // MARK: Changing

    @discardableResult
    func toggleFavorite(_ id: UUID) throws -> Bool {
        let channel = try channel(id)
        channel.isFavorite.toggle()
        try context.save()
        return channel.isFavorite
    }

    func isFavorite(_ id: UUID) -> Bool {
        (try? channel(id).isFavorite) ?? false
    }

    func markPlayed(_ id: UUID, at date: Date = .now) {
        do {
            try channel(id).lastPlayedAt = date
            try context.save()
        } catch {
            logger.error("markPlayed failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Downloads the playlist at `url` and adds it. A link to a single HLS
    /// stream is added as a one-item playlist. Returns the new playlist's id.
    @discardableResult
    func addRemotePlaylist(name: String, url: URL) async throws -> UUID {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme), url.host() != nil else {
            throw LibraryError.invalidURL
        }
        let text = try await fetcher.fetchText(from: url)
        let entries = M3UParser.isHLSStream(text)
            ? [PlaylistEntry(name: displayName(name, fallback: url), group: "", logoURL: nil, streamURL: url)]
            : M3UParser.parse(text, baseURL: url)
        guard !entries.isEmpty else { throw LibraryError.emptyPlaylist }

        let playlist = Playlist(name: displayName(name, fallback: url), kind: .remote, sourceHost: url.host())
        context.insert(playlist)
        try context.save()
        try secureStore.set(url.absoluteString, for: sourceKey(playlist.id))
        try await writer.replaceChannels(of: playlist.id, with: entries)
        return playlist.id
    }

    /// Builds an Xtream Codes M3U link and adds it like any other link.
    @discardableResult
    func addXtream(name: String, server: String, username: String, password: String) async throws -> UUID {
        guard let url = XtreamLink.playlistURL(server: server, username: username, password: password) else {
            throw MediaServerError.invalidAddress
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await addRemotePlaylist(name: trimmed.isEmpty ? "Xtream · \(url.host() ?? "")" : trimmed, url: url)
    }

    /// Signs in to a Jellyfin or Emby server and adds its movies and episodes.
    @discardableResult
    func addMediaServer(
        kind: MediaServerKind,
        name: String,
        address: String,
        username: String,
        password: String
    ) async throws -> UUID {
        guard let baseURL = ServerAddress.normalize(address) else { throw MediaServerError.invalidAddress }
        let account = try await mediaServers.signIn(
            kind: kind,
            baseURL: baseURL,
            username: username,
            password: password
        )
        let entries = try await mediaServers.library(for: account)
        guard !entries.isEmpty else { throw MediaServerError.emptyLibrary }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmed.isEmpty ? "\(kind.title) · \(baseURL.host() ?? "")" : trimmed
        let playlist = Playlist(name: title, kind: .mediaServer, sourceHost: baseURL.host())
        context.insert(playlist)
        try context.save()
        guard let encoded = try String(bytes: JSONEncoder().encode(account), encoding: .utf8) else {
            throw LibraryError.unreadable
        }
        try secureStore.set(encoded, for: sourceKey(playlist.id))
        try await writer.replaceChannels(of: playlist.id, with: entries)
        return playlist.id
    }

    /// Adds a playlist from M3U text (an imported .m3u file or pasted content).
    @discardableResult
    func addFilePlaylist(name: String, text: String) async throws -> UUID {
        let entries = M3UParser.parse(text)
        guard !entries.isEmpty else { throw LibraryError.emptyPlaylist }
        let playlist = Playlist(name: name, kind: .file)
        context.insert(playlist)
        try context.save()
        try await writer.replaceChannels(of: playlist.id, with: entries)
        return playlist.id
    }

    /// Re-downloads a remote playlist, keeping favourites for streams still present.
    func refresh(_ playlistID: UUID) async throws {
        guard let stored = try secureStore.string(for: sourceKey(playlistID)) else { throw LibraryError.notFound }
        if try playlist(playlistID).kind == .mediaServer {
            let account = try JSONDecoder().decode(MediaServerAccount.self, from: Data(stored.utf8))
            let entries = try await mediaServers.library(for: account)
            guard !entries.isEmpty else { throw MediaServerError.emptyLibrary }
            try await writer.replaceChannels(of: playlistID, with: entries)
            return
        }
        guard let url = URL(string: stored) else { throw LibraryError.notFound }
        let text = try await fetcher.fetchText(from: url)
        let entries = M3UParser.isHLSStream(text)
            ? try items(in: playlistID).prefix(1).map {
                PlaylistEntry(name: $0.title, group: $0.group, logoURL: $0.artworkURL, streamURL: $0.streamURL)
            }
            : M3UParser.parse(text, baseURL: url)
        guard !entries.isEmpty else { throw LibraryError.emptyPlaylist }
        try await writer.replaceChannels(of: playlistID, with: entries)
    }

    func rename(_ playlistID: UUID, to name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try playlist(playlistID).name = trimmed
        try context.save()
    }

    func delete(_ playlistID: UUID) throws {
        let playlist = try playlist(playlistID)
        if playlist.kind == .localVideos {
            for channel in playlist.channels where channel.streamURLString.hasPrefix(MediaLocation.localScheme) {
                if let url = MediaLocation.resolve(channel.streamURLString) {
                    // The row is going away either way; a leftover file is only wasted space.
                    try? fileManager.removeItem(at: url)
                }
            }
        }
        try secureStore.remove(sourceKey(playlistID))
        context.delete(playlist)
        try context.save()
    }

    /// Removes one video from "On this iPhone" and deletes its copied file.
    func deleteVideo(_ id: UUID) throws {
        let channel = try channel(id)
        guard channel.streamURLString.hasPrefix(MediaLocation.localScheme) else { throw LibraryError.notFound }
        if let url = MediaLocation.resolve(channel.streamURLString) {
            // The row goes either way; a leftover file is only wasted space.
            try? fileManager.removeItem(at: url)
        }
        context.delete(channel)
        try context.save()
    }

    /// Copies picked video files into the app and adds them to "On this iPhone".
    /// `urls` come from the document picker and may be security-scoped.
    @discardableResult
    func importVideos(_ urls: [URL]) throws -> Int {
        let directory = MediaLocation.videosDirectory
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let playlist = try localVideosPlaylist()
        var nextIndex = (playlist.channels.map(\.sortIndex).max() ?? -1) + 1
        var imported = 0
        for source in urls {
            let scoped = source.startAccessingSecurityScopedResource()
            defer {
                if scoped {
                    source.stopAccessingSecurityScopedResource()
                }
            }
            let fileName = "\(UUID().uuidString)-\(source.lastPathComponent)"
            do {
                try fileManager.copyItem(at: source, to: directory.appending(path: fileName))
            } catch {
                logger.error("Video copy failed: \(error.localizedDescription, privacy: .public)")
                continue
            }
            let channel = Channel(
                name: source.deletingPathExtension().lastPathComponent,
                group: String(appLocalized: "On this iPhone"),
                logoURLString: nil,
                streamURLString: MediaLocation.localScheme + fileName,
                sortIndex: nextIndex
            )
            context.insert(channel)
            channel.playlist = playlist
            nextIndex += 1
            imported += 1
        }
        try context.save()
        if imported == 0 {
            throw LibraryError.unreadable
        }
        return imported
    }

    // MARK: Helpers

    private func channel(_ id: UUID) throws -> Channel {
        var descriptor = FetchDescriptor<Channel>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let channel = try context.fetch(descriptor).first else { throw LibraryError.notFound }
        return channel
    }

    private func playlist(_ id: UUID) throws -> Playlist {
        var descriptor = FetchDescriptor<Playlist>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let playlist = try context.fetch(descriptor).first else { throw LibraryError.notFound }
        return playlist
    }

    private func existingLocalVideosPlaylist() throws -> Playlist? {
        let kind = PlaylistKind.localVideos.rawValue
        var descriptor = FetchDescriptor<Playlist>(predicate: #Predicate { $0.kindRaw == kind })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func localVideosPlaylist() throws -> Playlist {
        if let existing = try existingLocalVideosPlaylist() {
            return existing
        }
        let playlist = Playlist(name: String(appLocalized: "On this iPhone"), kind: .localVideos)
        context.insert(playlist)
        return playlist
    }

    private func displayName(_ name: String, fallback url: URL) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? (url.host() ?? M3UParser.fallbackName(for: url)) : trimmed
    }

    private func sourceKey(_ id: UUID) -> String {
        "playlist.source.\(id.uuidString)"
    }
}
