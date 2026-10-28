import Foundation
import SwiftUI
import Testing
import UIKit
@testable import PlayCarTV

@Suite("Theme", .serialized)
@MainActor
struct ThemeTests {
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "playcartv.tests.\(UUID().uuidString)") ?? .standard
    }

    @Test("A new install follows the iPhone, in Golden Hour")
    func defaultsToSystemAndGoldenHour() {
        let theme = AppTheme(defaults: defaults())
        #expect(theme.appearance == .system)
        #expect(theme.accent == .golden)
        #expect(ThemeAccent.standard == .golden)
    }

    @Test("Choices are remembered across launches, and reset clears them")
    func persistsAndResets() {
        let store = defaults()
        let theme = AppTheme(defaults: store)
        theme.setAppearance(.dark)
        theme.setAccent(.ocean)

        let relaunched = AppTheme(defaults: store)
        #expect(relaunched.appearance == .dark)
        #expect(relaunched.accent == .ocean)

        relaunched.reset()
        #expect(relaunched.appearance == .system)
        #expect(relaunched.accent == .golden)
        #expect(store.string(forKey: AppTheme.Keys.appearance) == nil)
        #expect(AppTheme(defaults: store).accent == .golden)
    }

    @Test("The font style starts as Road Sign, is remembered, and reset clears it")
    func fontStyle() {
        let store = defaults()
        let theme = AppTheme(defaults: store)
        #expect(theme.font == .roadSign)
        ThemeViewModel(theme: theme).choose(ThemeFont.serif)
        #expect(theme.font == .serif)
        #expect(AppTheme(defaults: store).font == .serif) // Next launch.
        theme.reset()
        #expect(theme.font == .roadSign)
        #expect(AppTheme(defaults: store).font == .roadSign)
    }

    @Test("Every font style keeps the system's text styles, so Dynamic Type still scales it")
    func fontStylesHaveDesigns() {
        #expect(ThemeFont.allCases.count == 4)
        #expect(ThemeFont.rounded.design == .rounded)
        #expect(ThemeFont.serif.design == .serif)
        let title = ThemeFont.serif.uiFont(size: 17, weight: .heavy, overpass: "Overpass-ExtraBold")
        #expect(title.fontDescriptor.symbolicTraits.contains(.traitBold))
    }

    @Test("An unknown saved value falls back to the default")
    func unknownSavedValue() {
        let store = defaults()
        store.set("neon", forKey: AppTheme.Keys.accent)
        store.set("sepia", forKey: AppTheme.Keys.appearance)
        let theme = AppTheme(defaults: store)
        #expect(theme.accent == .golden)
        #expect(theme.appearance == .system)
    }

    @Test("Appearance maps to SwiftUI and UIKit")
    func appearanceMapping() {
        #expect(ThemeAppearance.system.colorScheme == nil)
        #expect(ThemeAppearance.light.colorScheme == .light)
        #expect(ThemeAppearance.dark.colorScheme == .dark)
        #expect(ThemeAppearance.system.interfaceStyle == .unspecified)
        #expect(ThemeAppearance.dark.interfaceStyle == .dark)
    }

    @Test("The view model switches the theme and summarises it")
    func viewModel() {
        let theme = AppTheme(defaults: defaults())
        let viewModel = ThemeViewModel(theme: theme)
        #expect(viewModel.accents.count == ThemeAccent.allCases.count)
        #expect(viewModel.summary == "Golden Hour · System")

        viewModel.choose(.light)
        viewModel.choose(.twilight)
        #expect(theme.appearance == .light)
        #expect(theme.accent == .twilight)
        #expect(viewModel.summary == "Twilight · Light")
    }

    @Test("Dynamic colours resolve to each appearance's value")
    func dynamicColors() {
        let pair = ThemeAccent.ocean.palette.accent
        let color = UIColor(pair)
        let light = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        #expect(light.hexValue == pair.light)
        #expect(dark.hexValue == pair.dark)
    }

    /// WCAG 2: accent text needs 4.5:1 on every surface; the button label (17 pt extra-bold,
    /// large text) needs 3:1 against both gradient ends.
    @Test("Every accent is readable in light and dark", arguments: ThemeAccent.allCases)
    func contrast(accent: ThemeAccent) {
        let palette = accent.palette
        let lightSurfaces: [UInt32] = [0xF3F3F6, 0xFFFFFF] // canvas, cards
        let darkSurfaces: [UInt32] = [0x121417, 0x1D2025]
        for surface in lightSurfaces {
            #expect(Contrast.ratio(palette.accent.light, surface) >= 4.5, "\(accent) text on \(surface)")
        }
        for surface in darkSurfaces {
            #expect(Contrast.ratio(palette.accent.dark, surface) >= 4.5, "\(accent) dark text on \(surface)")
        }
        for fill in [palette.brand.light, palette.brandDeep.light] {
            #expect(Contrast.ratio(palette.onBrand.light, fill) >= 3, "\(accent) label on light fill")
        }
        for fill in [palette.brand.dark, palette.brandDeep.dark] {
            #expect(Contrast.ratio(palette.onBrand.dark, fill) >= 3, "\(accent) label on dark fill")
        }
    }

    /// The brief says no green; the covers' white initials are large text, so they need 3:1.
    @Test("Placeholder covers avoid green and keep white initials readable")
    func placeholderCovers() {
        var pairs = Set<UInt32>()
        for title in (0..<360).map({ "Channel \($0)" }) {
            let colors = Palette.placeholderColors(for: title).map { UIColor($0) }
            for color in colors {
                var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
                color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
                #expect(!(0.2...0.45).contains(hue), "\(title) has a green cover")
                #expect(Contrast.ratio(0xFFFFFF, color.hexValue) >= 3, "\(title) initials")
            }
            if let first = colors.first {
                pairs.insert(first.hexValue)
            }
        }
        #expect(pairs.count == 5, "Every hue pair was checked")
    }
}

private enum Contrast {
    static func ratio(_ first: UInt32, _ second: UInt32) -> Double {
        let (lighter, darker) = (max(luminance(first), luminance(second)), min(luminance(first), luminance(second)))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func luminance(_ hex: UInt32) -> Double {
        func channel(_ shift: UInt32) -> Double {
            let value = Double((hex >> shift) & 0xFF) / 255
            return value <= 0.039_28 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }
}

private extension UIColor {
    var hexValue: UInt32 {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func byte(_ value: CGFloat) -> UInt32 {
            UInt32((value * 255).rounded())
        }
        return (byte(red) << 16) | (byte(green) << 8) | byte(blue)
    }
}
