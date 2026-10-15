import SwiftUI
import UIKit

/// The app's text styles, in the font style chosen in Settings › Theme (`ThemeFont`). Road Sign is
/// Overpass for display and SF Pro for reading; every style follows a Dynamic Type text style.
@MainActor
enum Typography {
    private static var style: ThemeFont {
        AppTheme.shared.font
    }

    static var hero: Font {
        display("Overpass-Black", size: 36, relativeTo: .largeTitle, weight: .black)
    }

    static var screenTitle: Font {
        display("Overpass-ExtraBold", size: 28, relativeTo: .title, weight: .heavy)
    }

    static var sectionTitle: Font {
        display("Overpass-ExtraBold", size: 20, relativeTo: .title3, weight: .heavy)
    }

    static var sign: Font {
        display("Overpass-Bold", size: 18, relativeTo: .headline, weight: .bold)
    }

    static var button: Font {
        display("Overpass-ExtraBold", size: 17, relativeTo: .headline, weight: .heavy)
    }

    static var cardTitle: Font {
        .system(.subheadline, design: style.design, weight: .semibold)
    }

    static var body: Font {
        .system(.body, design: style.design)
    }

    static var secondary: Font {
        .system(.subheadline, design: style.design)
    }

    static var caption: Font {
        .system(.caption, design: style.design, weight: .medium)
    }

    /// Counts and prices: Overpass Mono with Road Sign, SF Mono otherwise.
    static var data: Font {
        mono(size: 12, relativeTo: .caption)
    }

    static var badge: Font {
        mono(size: 11, relativeTo: .caption2)
    }

    private static func display(
        _ overpass: String,
        size: CGFloat,
        relativeTo: Font.TextStyle,
        weight: Font.Weight
    ) -> Font {
        style == .roadSign
            ? .custom(overpass, size: size, relativeTo: relativeTo)
            : .system(relativeTo, design: style.design, weight: weight)
    }

    private static func mono(size: CGFloat, relativeTo: Font.TextStyle) -> Font {
        style == .roadSign
            ? .custom("OverpassMono-SemiBold", size: size, relativeTo: relativeTo)
            : .system(relativeTo, design: .monospaced, weight: .semibold)
    }

    /// Navigation titles and tab-bar labels in the chosen style. UIKit appearance ignores Dynamic Type
    /// and only reaches new bars, so this re-runs on text-size and style changes and restyles open ones.
    static func applyUIKitFonts() {
        let large = UIFontMetrics(forTextStyle: .largeTitle)
            .scaledFont(for: style.uiFont(size: 34, weight: .black, overpass: "Overpass-Black"))
        let inline = UIFontMetrics(forTextStyle: .headline)
            .scaledFont(for: style.uiFont(size: 17, weight: .heavy, overpass: "Overpass-ExtraBold"))
        // An explicit colour, so a title can't come out white on the light canvas.
        let largeAttributes: [NSAttributedString.Key: Any] = [.font: large, .foregroundColor: UIColor.label]
        let inlineAttributes: [NSAttributedString.Key: Any] = [.font: inline, .foregroundColor: UIColor.label]
        let appearance = UINavigationBar.appearance()
        appearance.largeTitleTextAttributes = largeAttributes
        appearance.titleTextAttributes = inlineAttributes
        // Tab labels: Road Sign keeps the system's own; the others take their design.
        let tab: [NSAttributedString.Key: Any]? = style == .roadSign
            ? nil
            : [.font: UIFontMetrics(forTextStyle: .caption2).scaledFont(for: style.uiFont(
                size: 10,
                weight: .semibold,
                overpass: ""
            ))]
        UITabBarItem.appearance().setTitleTextAttributes(tab, for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes(tab, for: .selected)
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows {
                restyleBars(in: window, large: largeAttributes, inline: inlineAttributes, tab: tab)
            }
        }
    }

    private static func restyleBars(
        in view: UIView,
        large: [NSAttributedString.Key: Any],
        inline: [NSAttributedString.Key: Any],
        tab: [NSAttributedString.Key: Any]?
    ) {
        if let bar = view as? UITabBar {
            for item in bar.items ?? [] {
                item.setTitleTextAttributes(tab, for: .normal)
                item.setTitleTextAttributes(tab, for: .selected)
            }
        }
        if let bar = view as? UINavigationBar {
            func restyled(_ appearance: UINavigationBarAppearance) -> UINavigationBarAppearance {
                let copy = appearance.copy() as? UINavigationBarAppearance ?? appearance
                copy.largeTitleTextAttributes = large
                copy.titleTextAttributes = inline
                return copy
            }
            bar.largeTitleTextAttributes = large
            bar.titleTextAttributes = inline
            bar.standardAppearance = restyled(bar.standardAppearance)
            bar.scrollEdgeAppearance = bar.scrollEdgeAppearance.map(restyled)
            bar.compactAppearance = bar.compactAppearance.map(restyled)
        }
        for subview in view.subviews {
            restyleBars(in: subview, large: large, inline: inline, tab: tab)
        }
    }
}
