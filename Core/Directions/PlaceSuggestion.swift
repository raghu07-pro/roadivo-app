import Foundation

/// What Apple Maps suggests while a search is typed, as its own search box lists them: a name and where it is. It's
/// found on the map only once chosen (owner, 2026-10-27: "show multiple options on search"; DECISIONS 172).
struct PlaceSuggestion: Identifiable, Hashable, Sendable {
    let title: String
    /// The street, town or region, as Maps writes it; empty when it has none.
    let subtitle: String

    var id: String {
        "\(title)|\(subtitle)"
    }

    /// What finds this one on the map.
    var query: String {
        subtitle.isEmpty ? title : "\(title), \(subtitle)"
    }

    init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    /// A place already found, offered as a suggestion.
    init(_ place: Place) {
        self.init(title: place.name, subtitle: place.address == place.name ? "" : place.address)
    }
}
