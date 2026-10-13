import Foundation

/// One group of the library ("Movies", "Sports", …) in playlist order.
struct LibrarySection: Identifiable, Hashable {
    let title: String
    let items: [MediaItem]

    var id: String {
        title
    }
}

enum LibraryScope {
    case all
    case favorites
}
