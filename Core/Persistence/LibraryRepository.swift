import Foundation
import OSLog
import SwiftData

/// The one gateway features use to read and change the library.
@MainActor
final class LibraryRepository {
    private let store: SwiftDataStore
    private let writer: LibraryWriter
    let secureStore: SecureStore
    private let fetcher: PlaylistFetching
    private let mediaServers: MediaServerConnecting
    private let fileManager: FileManager
    let logger = Logger(subsystem: "com.roadivo", category: "Library")

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

    /// Internal, with `playlist(_:)` and `sourceKey(_:)`, for the extensions in other files.
    var context: ModelContext {
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

    /// Every channel in playlist order, optionally for one playlist. One sorted fetch per source:
    /// sorting 30 000 channels in memory took seconds on every heart tap.
    func items(in playlistID: UUID? = nil) throws -> [MediaItem] {
        let sources = try playlistID.map { [$0] } ?? playlists().map(\.id)
        return try sources.flatMap { id in
            let descriptor = FetchDescriptor<Channel>(
                predicate: #Predicate { $0.playlist?.id == id },
                sortBy: [SortDescriptor(\.sortIndex)]
            )
            return try context.fetch(descriptor).compactMap { $0.mediaItem(sourceID: id) }
        }
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

    /// The most recently played items, optionally from one source. `excludingLocal` filters imported
    /// videos inside the fetch, so Home's Continue Watching still gets `limit` items.
    func recentlyPlayed(
        limit: Int = 12,
        excludingLocal: Bool = false,
        in playlistID: UUID? = nil
    ) throws -> [MediaItem] {
        let localPrefix = MediaLocation.localScheme
        let predicate: Predicate<Channel>
        if let playlistID {
            predicate = #Predicate { $0.lastPlayedAt != nil && $0.playlist?.id == playlistID }
        } else if excludingLocal {
            predicate = #Predicate { $0.lastPlayedAt != nil && !$0.streamURLString.starts(with: localPrefix) }
        } else {
            predicate = #Predicate { $0.lastPlayedAt != nil }
        }
        var descriptor = FetchDescriptor<Channel>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.lastPlayedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor).compactMap(\.mediaItem)
    }

    /// How many items a source has, counted in the store: reading `channels` loaded every row.
    func channelCount(in playlistID: UUID) throws -> Int {
        try context.fetchCount(FetchDescriptor<Channel>(predicate: #Predicate { $0.playlist?.id == playlistID }))
    }

    /// Which kind of server a media-server source signed in to, read from its saved login.
    func serverKind(of playlistID: UUID) -> MediaServerKind? {
        guard let stored = try? secureStore.string(for: sourceKey(playlistID)) else { return nil }
        // Only a media server's login is JSON; a link or an unreadable login has no server.
        return (try? JSONDecoder().decode(MediaServerAccount.self, from: Data(stored.utf8)))?.kind
    }

    /// The link a source was added from, for "Copy Link". It often carries the provider's login.
    func sourceLink(_ playlistID: UUID) throws -> URL? {
        guard try playlist(playlistID).kind == .remote else { return nil }
        return try secureStore.string(for: sourceKey(playlistID)).flatMap(URL.init(string:))
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
        guard !M3UParser.looksLikeWebPage(text) else { throw LibraryError.webPage }
        let report = switch await LibraryWork.parse(text, baseURL: url) {
        case .singleStream:
            M3UParser.Report(
                entries: [PlaylistEntry(
                    name: displayName(name, fallback: url),
                    group: "",
                    logoURL: nil,
                    streamURL: url
                )],
                issues: M3UParser.Issues()
            )
        case let .entries(report):
            report
        }
        guard !report.entries.isEmpty else { throw LibraryError.emptyPlaylist }

        let playlist = Playlist(name: displayName(name, fallback: url), kind: .remote, sourceHost: url.host())
        playlist.record(report.issues)
        return try await insert(playlist, secret: url.absoluteString, entries: report.entries)
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
        return try await add(account, name: name)
    }

    /// Saves a signed-in server (Jellyfin, Emby or Plex) and its library: the account in the
    /// Keychain, the items as channels. With no `name`: `defaultName`, the server's own name, or
    /// "Jellyfin · host".
    @discardableResult
    func add(_ account: MediaServerAccount, name: String, defaultName: String? = nil) async throws -> UUID {
        let entries = try await mediaServers.library(for: account)
        guard !entries.isEmpty else { throw MediaServerError.emptyLibrary }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = defaultName ?? account.serverName ?? "\(account.kind.title) · \(account.baseURL.host() ?? "")"
        let title = trimmed.isEmpty ? fallback : trimmed
        guard let encoded = try String(bytes: JSONEncoder().encode(account), encoding: .utf8) else {
            throw LibraryError.unreadable
        }
        let playlist = Playlist(name: title, kind: .mediaServer, sourceHost: account.baseURL.host())
        return try await insert(playlist, secret: encoded, entries: entries)
    }

    /// Adds a playlist from M3U text (an imported .m3u file or pasted content).
    @discardableResult
    func addFilePlaylist(name: String, text: String) async throws -> UUID {
        let report = await Task.detached(priority: .userInitiated) { M3UParser.report(text) }.value
        guard !report.entries.isEmpty else { throw LibraryError.emptyPlaylist }
        let playlist = Playlist(name: name, kind: .file)
        playlist.record(report.issues)
        return try await insert(playlist, secret: nil, entries: report.entries)
    }

    /// Re-downloads a remote playlist, keeping favourites for streams still present. The outcome is
    /// kept for Source Health.
    func refresh(_ playlistID: UUID) async throws {
        do {
            let issues = try await downloadAgain(playlistID)
            recordRefresh(of: playlistID, issues: issues, error: nil)
        } catch {
            recordRefresh(of: playlistID, issues: nil, error: error)
            throw error
        }
    }

    /// Replaces the source's channels; returns the playlist's unusable entries (none for a server).
    private func downloadAgain(_ playlistID: UUID) async throws -> M3UParser.Issues? {
        let kind = try playlist(playlistID).kind
        // Secrets are kept "this device only", so a restored iPhone has the source but not its link.
        guard let stored = try secureStore.string(for: sourceKey(playlistID)) else { throw SourceSecretError.missing }
        if kind == .mediaServer {
            // An unreadable login is as good as a missing one: the user has to sign in again.
            guard let account = try? JSONDecoder().decode(MediaServerAccount.self, from: Data(stored.utf8)) else {
                throw SourceSecretError.missing
            }
            let entries = try await mediaServers.library(for: account)
            guard !entries.isEmpty else { throw MediaServerError.emptyLibrary }
            try await writer.replaceChannels(of: playlistID, with: entries)
            return nil
        }
        guard let url = URL(string: stored) else { throw SourceSecretError.missing }
        let text = try await fetcher.fetchText(from: url)
        // A sign-in page in place of the playlist must never replace the
        // channels: favourites are matched by stream URL and would be lost.
        guard !M3UParser.looksLikeWebPage(text) else { throw LibraryError.webPage }
        let report = switch await LibraryWork.parse(text, baseURL: url) {
        case .singleStream:
            try M3UParser.Report(
                entries: items(in: playlistID).prefix(1).map {
                    PlaylistEntry(name: $0.title, group: $0.group, logoURL: $0.artworkURL, streamURL: $0.streamURL)
                },
                issues: M3UParser.Issues()
            )
        case let .entries(report):
            report
        }
        guard !report.entries.isEmpty else { throw LibraryError.emptyPlaylist }
        try await writer.replaceChannels(of: playlistID, with: report.entries)
        return report.issues
    }

    func rename(_ playlistID: UUID, to name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try playlist(playlistID).name = trimmed
        try context.save()
    }

    /// Deletes a source, its channels and its secret. Big sources go off the main actor.
    func delete(_ playlistID: UUID) async throws {
        let playlist = try playlist(playlistID)
        try secureStore.remove(sourceKey(playlistID))
        guard playlist.kind == .localVideos else {
            try await writer.deletePlaylist(playlistID)
            return
        }
        for channel in playlist.channels where channel.streamURLString.hasPrefix(MediaLocation.localScheme) {
            if let url = MediaLocation.resolve(channel.streamURLString) {
                // The row is going away either way; a leftover file is only wasted space.
                try? fileManager.removeItem(at: url)
            }
        }
        context.delete(playlist)
        try context.save()
    }

    // MARK: Helpers

    /// Saves a new source's row, secret (link or login) and channels. If a step fails, what was
    /// written is removed, so no half-added source is left behind.
    private func insert(_ playlist: Playlist, secret: String?, entries: [PlaylistEntry]) async throws -> UUID {
        let id = playlist.id
        context.insert(playlist)
        do {
            try context.save()
            if let secret {
                try secureStore.set(secret, for: sourceKey(id))
            }
            try await writer.replaceChannels(of: id, with: entries)
            return id
        } catch {
            discard(playlist)
            throw error
        }
    }

    private func discard(_ playlist: Playlist) {
        let key = sourceKey(playlist.id)
        context.delete(playlist)
        do {
            try context.save()
        } catch {
            logger.error("Removing a half-added source failed: \(error.localizedDescription, privacy: .public)")
        }
        do {
            try secureStore.remove(key)
        } catch {
            logger.error("Removing a half-added secret failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func channel(_ id: UUID) throws -> Channel {
        var descriptor = FetchDescriptor<Channel>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let channel = try context.fetch(descriptor).first else { throw LibraryError.notFound }
        return channel
    }

    func playlist(_ id: UUID) throws -> Playlist {
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

    func sourceKey(_ id: UUID) -> String {
        "playlist.source.\(id.uuidString)"
    }
}

// MARK: - On this iPhone

extension LibraryRepository {
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

    /// Copies picked (possibly security-scoped) videos into "On this iPhone", off the main actor. Returns
    /// how many were imported, which can be fewer than `urls`; throws the first copy error when none were.
    @discardableResult
    func importVideos(_ urls: [URL]) async throws -> Int {
        let directory = MediaLocation.videosDirectory
        let logger = logger
        let copied = try await Task.detached(priority: .userInitiated) {
            try LibraryWork.copyVideos(urls, into: directory, logger: logger)
        }.value
        guard !copied.isEmpty else { throw LibraryError.unreadable }

        let playlist = try localVideosPlaylist()
        var nextIndex = (playlist.channels.map(\.sortIndex).max() ?? -1) + 1
        for video in copied {
            let channel = Channel(
                name: video.title,
                group: String(appLocalized: "On this iPhone"),
                logoURLString: nil,
                streamURLString: MediaLocation.localScheme + video.fileName,
                sortIndex: nextIndex
            )
            context.insert(channel)
            channel.playlist = playlist
            nextIndex += 1
        }
        try context.save()
        return copied.count
    }
}

/// The repository's slow work, kept off the main actor: it runs inside
/// detached tasks, so a big import never freezes the UI.
private enum LibraryWork {
    /// What a downloaded text turned out to be.
    enum ParsedText {
        /// One HLS stream (its own link is the only item).
        case singleStream
        case entries(M3UParser.Report)
    }

    /// A video file copied into the app's videos folder.
    struct CopiedVideo {
        let title: String
        let fileName: String
    }

    /// Parses on a background thread: a 100 000-line provider export takes
    /// seconds, which would freeze the UI on the main actor.
    static func parse(_ text: String, baseURL: URL) async -> ParsedText {
        await Task.detached(priority: .userInitiated) {
            M3UParser.isHLSStream(text) ? .singleStream : .entries(M3UParser.report(text, baseURL: baseURL))
        }.value
    }

    /// Copies each file into `directory` under a unique name. A file that fails is logged and skipped
    /// so the rest still import; when none copy, the first error (such as a full iPhone) is thrown.
    static func copyVideos(_ urls: [URL], into directory: URL, logger: Logger) throws -> [CopiedVideo] {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        var copied: [CopiedVideo] = []
        var firstError: (any Error)?
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
                firstError = firstError ?? error
                continue
            }
            copied.append(CopiedVideo(title: source.deletingPathExtension().lastPathComponent, fileName: fileName))
        }
        if copied.isEmpty, let firstError {
            throw firstError
        }
        return copied
    }
}

/// A source whose link or login is no longer in the Keychain, as after restoring to a new iPhone.
enum SourceSecretError: LocalizedError, Equatable {
    case missing

    var errorDescription: String? {
        String(
            appLocalized: "This iPhone no longer has the link or login for this source. Delete it and add it again."
        )
    }
}
