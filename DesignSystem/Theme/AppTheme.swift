import Foundation
import Observation
import SwiftUI
import UIKit

/// The look the user picked in Settings › Theme: light, dark or the iPhone's
/// setting, and an accent colour. Both apply at once, without a relaunch:
/// - the colour tokens (`.roadAccent`, `.roadBrand`, …) read `shared`, so any
///   view that draws with them is redrawn when the accent changes;
/// - `RootView` applies the appearance and the accent to the windows, so
///   sheets, alerts and the system pickers follow too.
@Observable
@MainActor
final class AppTheme {
    static let shared = AppTheme()

    private(set) var appearance: ThemeAppearance
    private(set) var accent: ThemeAccent

    @ObservationIgnored private let defaults: UserDefaults

    /// Internal (not private) so tests can make their own.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = defaults.string(forKey: Keys.appearance).flatMap(ThemeAppearance.init(rawValue:)) ?? .system
        accent = defaults.string(forKey: Keys.accent).flatMap(ThemeAccent.init(rawValue:)) ?? .standard
    }

    /// The current accent's colours.
    var colors: ThemeColors {
        accent.colors
    }

    func setAppearance(_ newValue: ThemeAppearance) {
        guard newValue != appearance else { return }
        appearance = newValue
        defaults.set(newValue.rawValue, forKey: Keys.appearance)
    }

    func setAccent(_ newValue: ThemeAccent) {
        guard newValue != accent else { return }
        accent = newValue
        defaults.set(newValue.rawValue, forKey: Keys.accent)
    }

    /// Back to the defaults (System, Golden Hour). UI tests and snapshots start here,
    /// never from a choice left behind by an earlier run.
    func reset() {
        appearance = .system
        accent = .standard
        defaults.removeObject(forKey: Keys.appearance)
        defaults.removeObject(forKey: Keys.accent)
    }

    /// Light/dark and tint for UIKit: alerts, confirmation dialogs, the
    /// Photos and Files pickers. CarPlay isn't a window scene, so the car's
    /// own appearance is left alone.
    func applyToWindows() {
        let style = appearance.interfaceStyle
        let tint = accent.uiAccent
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = style
                window.tintColor = tint
            }
        }
    }

    enum Keys {
        static let appearance = "roadivo.theme.appearance"
        static let accent = "roadivo.theme.accent"
    }
}
