import Foundation

/// One group of the library ("Movies", "Sports", …) in playlist order.
struct LibrarySection: Identifiable {
    let title: String
    let items: [MediaItem]

    var id: String {
        title
    }
}

/// A group's own screen. Carries only the title so the screen reads the
/// group's current items and shows favourite changes made there.
struct LibraryGroupRoute: Hashable {
    let title: String
}

enum LibraryScope {
    case all
    case favorites
}

/// A source in Home's filter menu.
struct SourceOption: Identifiable, Equatable {
    let id: UUID
    let name: String
    let count: Int
}
