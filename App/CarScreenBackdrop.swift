#if DEBUG
    import SwiftUI

    /// The car screen's canvas with the theme's glow from the top corner, so it has depth rather than a flat fill.
    struct CarScreenBackdrop: View {
        var body: some View {
            ZStack {
                Color.roadCanvas
                RadialGradient(
                    colors: [Color.roadBrand.opacity(0.22), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 700
                )
            }
            .ignoresSafeArea()
        }
    }
#endif
