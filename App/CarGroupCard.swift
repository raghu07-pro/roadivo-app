#if DEBUG
    import SwiftUI

    /// A group of the car's library as a cover (DECISIONS 167): its first video's picture, its name and count over a
    /// dark fade, and a second card's edge behind it, as a stack of videos.
    struct CarGroupCard: View {
        let group: CarPlayMenu.Group
        let model: CarScreenModel
        let action: () -> Void

        var body: some View {
            let width = CarScreenMediaTile.cardWidth
            let shape = RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
            Button(action: action) {
                ZStack(alignment: .bottomLeading) {
                    Group {
                        if let first = group.items.first {
                            CarScreenArtwork(media: first, model: model, showsProgress: false)
                        } else {
                            Palette.placeholderGradient(for: group.title)
                        }
                    }
                    LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.title)
                            .font(Typography.sign)
                            .foregroundStyle(.white)
                        Text(app: "\(group.items.count) items")
                            .font(Typography.secondary)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .lineLimit(1)
                    .padding(Spacing.md)
                }
                .frame(width: width, height: width * 9 / 16)
                .clipShape(shape)
                .overlay { shape.strokeBorder(.white.opacity(0.1), lineWidth: 1) }
                .background(alignment: .top) {
                    // The stack's second card, peeking out above.
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .fill(.roadSurfaceElevated)
                        .padding(.horizontal, Spacing.md)
                        .offset(y: -Spacing.xs)
                }
                .padding(.top, Spacing.xs)
            }
            .buttonStyle(PressableStyle())
            .accessibilityElement(children: .combine)
        }
    }
#endif
