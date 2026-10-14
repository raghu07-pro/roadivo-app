import Foundation
import Observation

/// Settings › Theme: Light, Dark or System, and the accent colour. A choice
/// applies across the app at once (`AppTheme`) and is remembered.
@Observable
@MainActor
final class ThemeViewModel {
    let appearances = ThemeAppearance.allCases
    let accents = ThemeAccent.allCases

    private let theme: AppTheme

    init(theme: AppTheme = .shared) {
        self.theme = theme
    }

    var appearance: ThemeAppearance {
        theme.appearance
    }

    var accent: ThemeAccent {
        theme.accent
    }

    /// The Settings row's value, as in "Golden Hour · System".
    var summary: String {
        String(appLocalized: accent.title) + " · " + String(appLocalized: appearance.title)
    }

    func choose(_ appearance: ThemeAppearance) {
        theme.setAppearance(appearance)
    }

    func choose(_ accent: ThemeAccent) {
        theme.setAccent(accent)
    }
}
