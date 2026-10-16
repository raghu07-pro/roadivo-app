import SwiftUI

/// How much of a video has been watched: a thin bar along the bottom edge of its artwork.
struct WatchProgressBar: View {
    /// From 0 to 1.
    let fraction: Double

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Rectangle()
            .fill(.black.opacity(contrast == .increased ? 0.7 : 0.45))
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(.roadBrand)
                        .frame(width: proxy.size.width * min(max(fraction, 0), 1))
                }
            }
            .frame(height: 4)
            .accessibilityHidden(true) // The card reads out the time left instead.
    }
}

#Preview("Light") {
    ArtworkTile(title: "Steel Horizon", imageURL: nil)
        .overlay(alignment: .bottom) { WatchProgressBar(fraction: 0.42) }
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .frame(width: 220)
        .padding()
        .background(.roadCanvas)
}

#Preview("Dark, largest text") {
    ArtworkTile(title: "Steel Horizon", imageURL: nil)
        .overlay(alignment: .bottom) { WatchProgressBar(fraction: 0.8) }
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .frame(width: 220)
        .padding()
        .background(.roadCanvas)
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility3)
}
