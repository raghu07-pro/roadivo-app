import SwiftUI

/// One brand, taken from the logo: the road at golden hour. Sun amber for
/// actions and the centre line, asphalt for sign panels and dark surfaces,
/// and the sunset sky in the scenes. Each token is an asset colour with light and dark
/// variants, so screens never branch on the colour scheme themselves.
extension ShapeStyle where Self == Color {
    /// Screen background: pale concrete by day, asphalt by night.
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

    /// Tint for text-sized accents: burnt amber in light mode (4.5:1 on the
    /// canvas), sun amber in dark mode.
    static var roadAccent: Color {
        Color("AccentColor")
    }

    /// Sun amber (#FFB627): primary buttons, selection, the centre line.
    static var roadLane: Color {
        Color("LaneYellow")
    }

    /// Road surface; also the text colour on lane-yellow buttons.
    static var roadAsphalt: Color {
        Color("Asphalt")
    }

    /// "LIVE" badges.
    static var roadLive: Color {
        Color("LiveRed")
    }
}

enum Palette {
    /// Deterministic sunset-range gradient for items without artwork, so a
    /// logo-less playlist reads like postcards from the road, not grey boxes.
    static func placeholderGradient(for title: String) -> LinearGradient {
        let hues: [(Double, Double)] = [(0.02, 0.92), (0.07, 0.98), (0.55, 0.62), (0.40, 0.47), (0.75, 0.85)]
        let pair = hues[Int(title.stableHue * Double(hues.count)) % hues.count]
        return LinearGradient(
            colors: [
                Color(hue: pair.0, saturation: 0.70, brightness: 0.78),
                Color(hue: pair.1, saturation: 0.75, brightness: 0.32)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
