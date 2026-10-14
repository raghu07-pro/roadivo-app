import SwiftUI

/// Neutral surfaces from the asset catalog (light and dark variants), and
/// the accent from the theme the user picked (Settings › Theme). Screens
/// never branch on the colour scheme or the accent themselves.
extension ShapeStyle where Self == Color {
    /// Screen background: soft grey by day, asphalt by night.
    static var roadCanvas: Color {
        Color("CanvasBackground")
    }

    /// Cards and grouped rows.
    static var roadSurface: Color {
        Color("SurfaceBackground")
    }

    /// Chips, fields and raised controls on a surface.
    static var roadSurfaceElevated: Color {
        Color("SurfaceElevated")
    }

    /// Tint for text-sized accents, from the theme: at least 4.5:1 on the
    /// canvas and surfaces in both appearances.
    @MainActor static var roadAccent: Color {
        AppTheme.shared.colors.accent
    }

    /// The theme's fill: buttons, selection, markers and icon tiles.
    @MainActor static var roadBrand: Color {
        AppTheme.shared.colors.brand
    }

    /// The far end of the fill gradient.
    @MainActor static var roadBrandDeep: Color {
        AppTheme.shared.colors.brandDeep
    }

    /// Text and glyphs on a brand fill.
    @MainActor static var roadOnBrand: Color {
        AppTheme.shared.colors.onBrand
    }

    /// Quiet supporting text that still reaches 4.5:1 at caption sizes, on
    /// the canvas and on cards (`.secondary` is about 3.5:1 there).
    static var roadMuted: Color {
        Color.primary.opacity(0.72)
    }

    /// Road surface: always-dark panels (the paywall).
    static var roadAsphalt: Color {
        Color("Asphalt")
    }

    /// "LIVE" badges.
    static var roadLive: Color {
        Color("LiveRed")
    }
}

extension ShapeStyle where Self == LinearGradient {
    /// The brand fill as a soft diagonal gradient, for buttons and tiles.
    @MainActor static var roadBrandGradient: LinearGradient {
        LinearGradient(colors: [.roadBrand, .roadBrandDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum Palette {
    /// The road's own colours in the drawn scenes: a yellow centre line and
    /// the logo's play-button sun. Artwork, so it doesn't follow the theme.
    static let laneYellow = Color("LaneYellow")

    /// Deterministic sunset-range gradient for items without artwork, so a
    /// logo-less playlist reads like postcards from the road, not grey boxes.
    static func placeholderGradient(for title: String) -> LinearGradient {
        let hues: [(Double, Double)] = [(0.02, 0.92), (0.07, 0.98), (0.55, 0.62), (0.40, 0.47), (0.75, 0.85)]
        let pair = hues[Int(title.stableHue * Double(hues.count)) % hues.count]
        return LinearGradient(
            colors: [
                // Deep enough that the white initials read at 3:1 or more
                // (large text) even at the gradient's lightest corner.
                Color(hue: pair.0, saturation: 0.70, brightness: 0.62),
                Color(hue: pair.1, saturation: 0.75, brightness: 0.32)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
