import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Roadivo

@Suite("Theme", .serialized)
@MainActor
struct ThemeTests {
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "roadivo.tests.\(UUID().uuidString)") ?? .standard
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

    /// WCAG 2: accent text needs 4.5:1 on every surface it sits on; the
    /// button label (17 pt extra-bold, "large text") needs 3:1 against both
    /// ends of the gradient.
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
