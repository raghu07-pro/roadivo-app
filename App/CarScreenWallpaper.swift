#if DEBUG
    import SwiftUI

    /// The soft wave CarPlay drew behind Roadivo's template tabs, which a plain window can't show: its colours,
    /// sampled from the CarPlay Simulator (owner, 2026-10-26; DECISIONS 163), with night versions in the catalog.
    struct CarScreenWallpaper: View {
        private static let sand = Color("CarWallpaperSand")
        private static let linen = Color("CarWallpaperLinen")
        private static let stone = Color("CarWallpaperStone")
        private static let lavender = Color("CarWallpaperLavender")
        private static let mist = Color("CarWallpaperMist")

        var body: some View {
            Group {
                if #available(iOS 18, *) {
                    MeshGradient(
                        width: 3,
                        height: 3,
                        points: [
                            [0, 0], [0.55, 0], [1, 0],
                            [0, 0.5], [0.45, 0.55], [1, 0.45],
                            [0, 1], [0.5, 1], [1, 1]
                        ],
                        colors: [
                            Self.stone, Self.sand, Self.linen,
                            Self.linen, Self.stone, Self.linen,
                            Self.stone, Self.lavender, Self.mist
                        ]
                    )
                } else {
                    LinearGradient(
                        colors: [Self.sand, Self.linen, Self.stone, Self.lavender, Self.mist],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
        }
    }

    #Preview {
        CarScreenWallpaper()
            .frame(width: 1019, height: 573)
    }
#endif
