import SwiftUI
import UIKit

/// Overpass (modelled on Highway Gothic signs) for display, SF Pro for reading, Overpass Mono for
/// counts and prices; every custom style is tied to a Dynamic Type text style.
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

    /// Overpass navigation-bar titles. UIKit appearance ignores Dynamic Type, so RoadivoApp re-runs
    /// this when the text size changes.
    @MainActor
    static func applyNavigationBarFonts() {
        let large = UIFontMetrics(forTextStyle: .largeTitle)
            .scaledFont(for: UIFont(name: "Overpass-Black", size: 34) ?? .preferredFont(forTextStyle: .largeTitle))
        let inline = UIFontMetrics(forTextStyle: .headline)
            .scaledFont(for: UIFont(name: "Overpass-ExtraBold", size: 17) ?? .preferredFont(forTextStyle: .headline))
        let appearance = UINavigationBar.appearance()
        // An explicit colour, so a title can't come out white on the light canvas.
        appearance.largeTitleTextAttributes = [.font: large, .foregroundColor: UIColor.label]
        appearance.titleTextAttributes = [.font: inline, .foregroundColor: UIColor.label]
    }
}
