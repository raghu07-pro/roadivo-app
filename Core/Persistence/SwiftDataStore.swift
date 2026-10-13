import Foundation
import SwiftData

/// Owns the on-device SwiftData container (the library: playlists + channels).
@MainActor
final class SwiftDataStore {
    let container: ModelContainer

    var mainContext: ModelContext {
        container.mainContext
    }

    init(inMemory: Bool = false) throws {
        let schema = Schema([Playlist.self, Channel.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(for: schema, configurations: [configuration])
    }
}
