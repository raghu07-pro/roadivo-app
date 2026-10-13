import SwiftUI
import UIKit

/// Overpass — the open-source face modelled on the US Highway Gothic sign
/// alphabet — for display and signs; SF Pro for reading; Overpass Mono for
/// counts and prices. Every custom style is tied to a Dynamic Type text
/// style (`relativeTo:`), so it scales like the system fonts.
enum Typography {
    static let hero = Font.custom("Overpass-Black", size: 36, relativeTo: .largeTitle)
    static let screenTitle = Font.custom("Overpass-ExtraBold", size: 28, relativeTo: .title)
    static let sectionTitle = Font.custom("Overpass-ExtraBold", size: 20, relativeTo: .title3)
    static let sign = Font.custom("Overpass-Bold", size: 18, relativeTo: .headline)
    static let cardTitle = Font.subheadline.weight(.semibold)
    static let body = Font.body
    static let secondary = Font.subheadline
    static let caption = Font.caption.weight(.medium)
    static let data = Font.custom("OverpassMono-SemiBold", size: 12, relativeTo: .caption)
    static let badge = Font.custom("OverpassMono-SemiBold", size: 11, relativeTo: .caption2)
    static let button = Font.custom("Overpass-ExtraBold", size: 17, relativeTo: .headline)

    /// Navigation-bar titles in Overpass. UIKit appearance doesn't follow
    /// Dynamic Type by itself, so this re-runs whenever the text size changes
    /// (RoadivoApp observes the notification).
    @MainActor
    static func applyNavigationBarFonts() {
        let large = UIFontMetrics(forTextStyle: .largeTitle)
            .scaledFont(for: UIFont(name: "Overpass-Black", size: 34) ?? .preferredFont(forTextStyle: .largeTitle))
        let inline = UIFontMetrics(forTextStyle: .headline)
            .scaledFont(for: UIFont(name: "Overpass-ExtraBold", size: 17) ?? .preferredFont(forTextStyle: .headline))
        let appearance = UINavigationBar.appearance()
        appearance.largeTitleTextAttributes = [.font: large]
        appearance.titleTextAttributes = [.font: inline]
    }
}
