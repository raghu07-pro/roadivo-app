import Foundation
import Observation

@Observable
@MainActor
final class PlayerViewModel {
    let playback: PlaybackController
    private let repository: LibraryRepository
    /// Whether PlayCarTV is on the car's screen, for Play on Car Display.
    private let carConnection: CarConnection?

    /// The playing item's whole source, for browsing its groups while watching. Empty until read.
    private(set) var sourceItems: [MediaItem] = []
    /// The source's groups, as chips.
    private(set) var groups: [String] = []
    /// The chip shown: the playing item's group to begin with.
    var group = "" {
        didSet {
            if group != oldValue {
                rebuildGrid()
            }
        }
    }

    /// The chosen group's items, stored so a big source isn't sifted on every redraw.
    private var groupItems: [MediaItem] = []

    init(playback: PlaybackController, repository: LibraryRepository, carConnection: CarConnection? = nil) {
        self.playback = playback
        self.repository = repository
        self.carConnection = carConnection
    }

    var current: MediaItem? {
        playback.current
    }

    /// The video is on the car's screen: the iPhone shows its controls but not the picture, as CarTV's.
    var isOnCar: Bool {
        playback.origin == .car && playback.isActive
    }

    /// Play on Car Display, while PlayCarTV is on the car's screen and the video is on the iPhone (owner, 2026-10-26).
    var canPlayOnCar: Bool {
        carConnection?.isCarPlayConnected == true && playback.isActive && !isOnCar
    }

    func playOnPhone() {
        playback.move(to: .phone)
    }

    func playOnCar() {
        playback.move(to: .car)
    }

    /// Chips only help when the source has more than one group.
    var showsGroups: Bool {
        groups.count > 1
    }

    /// What the grid shows: the chosen group, or the queue when the source can't be read.
    var gridItems: [MediaItem] {
        sourceItems.isEmpty ? playback.queue : groupItems
    }

    /// Reads the playing item's source and opens the chips on its group.
    func loadSource() {
        // Unreadable, the grid simply shows the queue as before.
        guard let current, let sourceID = current.sourceID,
              let items = try? repository.items(in: sourceID), !items.isEmpty else { return }
        sourceItems = items
        groups = items.groupTitles
        group = groups.contains(current.groupTitle) ? current.groupTitle : groups.first ?? ""
        rebuildGrid()
    }

    var errorMessage: String? {
        if case let .failed(message) = playback.status {
            return message
        }
        return nil
    }

    /// Returns true when the favourite changed.
    func toggleFavorite() -> Bool {
        guard let current, let isFavorite = try? repository.toggleFavorite(current.id) else { return false }
        playback.updateFavorite(isFavorite, for: current.id)
        return true
    }

    func select(_ item: MediaItem) {
        guard item.id != current?.id else { return }
        // Picked from a chip: next and previous step through that group.
        let queue = sourceItems.isEmpty ? playback.queue : groupItems
        // On the car, the iPhone is its remote: the pick plays there too.
        playback.play(item, queue: queue, from: playback.origin)
    }

    func retry() {
        guard let current else { return }
        playback.play(current, queue: playback.queue, from: playback.origin)
    }

    private func rebuildGrid() {
        groupItems = sourceItems.inGroup(group)
    }
}
