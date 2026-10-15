import SwiftUI

/// A group's header on Home, which opens the group: its name, and its count at the end.
struct GroupHeader: View {
    let section: LibrarySection

    private var detail: String {
        let count = section.items.count
        return section.isFromServer
            ? String(appLocalized: "\(count) items")
            : String(appLocalized: "\(count) channels")
    }

    var body: some View {
        ShelfHeader(title: section.title, detail: detail, opensGroup: true)
    }
}

extension LibrarySection {
    /// A media server's films and episodes, which are items rather than channels.
    var isFromServer: Bool {
        items.first.map { $0.artwork != .logo } ?? false
    }
}
