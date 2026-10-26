#if DEBUG
    import SwiftUI

    /// A video on the car's screen as a streaming app's card (DECISIONS 167): its picture (`CarScreenArtwork`) with the
    /// title and the group or time left over a dark fade, so bright frames don't glare and the rows stay compact.
    struct CarScreenMediaTile: View {
        let media: MediaItem
        let model: CarScreenModel
        /// The picture's width, in points; `aspect` is width over height.
        var width: CGFloat = side
        var aspect: CGFloat = 1
        let action: () -> Void

        /// A square tile's side, in points.
        static let side: CGFloat = 168
        /// A 16:9 card's width on the shelves and grids.
        static let cardWidth: CGFloat = 240

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
            Button(action: action) {
                CarScreenArtwork(media: media, model: model)
                    .overlay(alignment: .bottomLeading) { caption }
                    .frame(width: width, height: width / aspect)
                    .clipShape(shape)
                    .overlay { shape.strokeBorder(Color.primary.opacity(0.1), lineWidth: 1) }
                    .overlay(alignment: .topLeading) { playing }
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            }
            .buttonStyle(PressableStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(media.title))
            .accessibilityValue(Text(detail))
        }

        private var caption: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(media.title)
                    .font(Typography.sign)
                    .foregroundStyle(.white)
                Text(detail)
                    .font(Typography.secondary)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .lineLimit(1)
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.xl)
            // Clear of the progress bar along the very bottom.
            .padding(.bottom, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
            }
        }

        /// The group, or "42 min left" when it can be picked up, as the iPhone's cards say it.
        private var detail: String {
            guard let progress = media.progress else { return media.groupTitle }
            return String(appLocalized: "\(progress.remainingText(locale: AppLanguage.shared.locale)) left")
        }

        /// As CarTV's "Playing" on the channel that's on.
        @ViewBuilder private var playing: some View {
            if model.playingID == media.id {
                Text(app: "Playing")
                    .font(Typography.cardTitle)
                    .foregroundStyle(.roadOnBrand)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, Spacing.xxs)
                    .background(.roadBrandGradient, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    .padding(Spacing.xs)
            }
        }
    }
#endif
