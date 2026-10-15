import Foundation
import Observation
import SwiftUI
import UIKit

/// The look picked in Settings › Theme (appearance, accent, font style), applied live: tokens read
/// `shared`, so views redraw; `RootView` carries it to the windows for sheets, alerts and pickers.
@Observable
@MainActor
final class AppTheme {
    static let shared = AppTheme()

    private(set) var appearance: ThemeAppearance
    private(set) var accent: ThemeAccent
    private(set) var font: ThemeFont

    @ObservationIgnored private let defaults: UserDefaults

    /// Internal (not private) so tests can make their own.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = defaults.string(forKey: Keys.appearance).flatMap(ThemeAppearance.init(rawValue:)) ?? .system
        accent = defaults.string(forKey: Keys.accent).flatMap(ThemeAccent.init(rawValue:)) ?? .standard
        font = defaults.string(forKey: Keys.font).flatMap(ThemeFont.init(rawValue:)) ?? .default
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

    func setFont(_ newValue: ThemeFont) {
        guard newValue != font else { return }
        font = newValue
        defaults.set(newValue.rawValue, forKey: Keys.font)
    }

    /// Back to the defaults (System, Golden Hour, Road Sign). UI tests and snapshots start here,
    /// never from a choice left behind by an earlier run.
    func reset() {
        appearance = .system
        accent = .standard
        font = .default
        defaults.removeObject(forKey: Keys.appearance)
        defaults.removeObject(forKey: Keys.accent)
        defaults.removeObject(forKey: Keys.font)
    }

    /// Light/dark and tint for UIKit (alerts, the Photos and Files pickers). CarPlay isn't a
    /// window scene, so the car keeps its own appearance.
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
        static let font = "roadivo.theme.font"
    }
}
