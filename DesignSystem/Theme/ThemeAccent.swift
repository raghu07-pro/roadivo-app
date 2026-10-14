import SwiftUI
import UIKit

/// The accent every action, selection and highlight uses. Golden Hour is the
/// default: the logo's sun, with dark lettering on its fills.
enum ThemeAccent: String, CaseIterable, Identifiable {
    case sunset
    case ocean
    case twilight
    case rose
    case golden
    case graphite

    static let standard: ThemeAccent = .golden

    var id: String {
        rawValue
    }

    var title: LocalizedStringResource {
        switch self {
        case .sunset: "Sunset"
        case .ocean: "Ocean"
        case .twilight: "Twilight"
        case .rose: "Rose"
        case .golden: "Golden Hour"
        case .graphite: "Graphite"
        }
    }

    /// Light and dark values, as sRGB hex. `ThemeTests` checks every pair
    /// against WCAG contrast on the app's canvas and surfaces.
    var palette: ThemePalette {
        switch self {
        case .sunset:
            ThemePalette(
                accent: .init(light: 0xB53A0B, dark: 0xFF8A5C),
                brand: .init(light: 0xEE6230, dark: 0xEE6230),
                brandDeep: .init(light: 0xD33C1A, dark: 0xD33C1A),
                onBrand: .init(light: 0xFFFFFF, dark: 0xFFFFFF)
            )
        case .ocean:
            ThemePalette(
                accent: .init(light: 0x1D5FD1, dark: 0x6AA6FF),
                brand: .init(light: 0x3B82F6, dark: 0x4C8DF6),
                brandDeep: .init(light: 0x1D5FD1, dark: 0x2563EB),
                onBrand: .init(light: 0xFFFFFF, dark: 0xFFFFFF)
            )
        case .twilight:
            ThemePalette(
                accent: .init(light: 0x5B3FD6, dark: 0xA796FF),
                brand: .init(light: 0x7C5CFA, dark: 0x8B6DFF),
                brandDeep: .init(light: 0x5B3FD6, dark: 0x6A4BEA),
                onBrand: .init(light: 0xFFFFFF, dark: 0xFFFFFF)
            )
        case .rose:
            ThemePalette(
                accent: .init(light: 0xC81E4E, dark: 0xFF7A98),
                brand: .init(light: 0xEC4870, dark: 0xF2567B),
                brandDeep: .init(light: 0xC81E4E, dark: 0xD82C59),
                onBrand: .init(light: 0xFFFFFF, dark: 0xFFFFFF)
            )
        case .golden:
            ThemePalette(
                accent: .init(light: 0x955300, dark: 0xFFB627),
                brand: .init(light: 0xFFC247, dark: 0xFFC247),
                brandDeep: .init(light: 0xFFA80F, dark: 0xFFA80F),
                onBrand: .init(light: 0x17191D, dark: 0x17191D)
            )
        case .graphite:
            ThemePalette(
                accent: .init(light: 0x2B2F36, dark: 0xE6E7EA),
                brand: .init(light: 0x3A3F48, dark: 0xF2F3F5),
                brandDeep: .init(light: 0x1F2228, dark: 0xC9CCD2),
                onBrand: .init(light: 0xFFFFFF, dark: 0x17191D)
            )
        }
    }

    /// Built once per accent, so SwiftUI sees the same colour on every redraw.
    var colors: ThemeColors {
        Self.table[self] ?? ThemeColors(palette)
    }

    /// The text tint for UIKit (window tint, AirPlay's active state).
    var uiAccent: UIColor {
        UIColor(palette.accent)
    }

    private static let table = Dictionary(uniqueKeysWithValues: allCases.map { ($0, ThemeColors($0.palette)) })
}

/// An accent's raw values.
struct ThemePalette: Equatable {
    struct Pair: Equatable {
        let light: UInt32
        let dark: UInt32
    }

    /// Text-sized tint: at least 4.5:1 on the canvas and surfaces.
    let accent: Pair
    /// Fills: buttons, selection, markers, icon tiles.
    let brand: Pair
    /// The fill gradient's far end.
    let brandDeep: Pair
    /// Text and glyphs on a fill: at least 3:1 against both ends (the button
    /// label is large, bold text).
    let onBrand: Pair
}

/// An accent's SwiftUI colours, each adapting to light and dark.
struct ThemeColors {
    let accent: Color
    let brand: Color
    let brandDeep: Color
    let onBrand: Color

    init(_ palette: ThemePalette) {
        accent = Color(uiColor: UIColor(palette.accent))
        brand = Color(uiColor: UIColor(palette.brand))
        brandDeep = Color(uiColor: UIColor(palette.brandDeep))
        onBrand = Color(uiColor: UIColor(palette.onBrand))
    }
}

extension UIColor {
    /// A colour that resolves to `pair.light` or `pair.dark` for the trait
    /// collection it's drawn in (including SwiftUI's colour-scheme overrides).
    convenience init(_ pair: ThemePalette.Pair) {
        self.init { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? pair.dark : pair.light)
        }
    }

    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
