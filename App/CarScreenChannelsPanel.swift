#if DEBUG
    import SwiftUI

    /// The car player's channels, as CarTV's panel (DECISIONS 164): Home, Favorites and what's playing's group, each a
    /// grid of tiles with the playing one marked, over the video; it closes once a channel is picked.
    struct CarScreenChannelsPanel: View {
        let model: CarScreenModel

        var body: some View {
            let items = model.channels(in: model.channelList)
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    lists
                    Spacer(minLength: 0)
                    Button {
                        model.actions?.closeChannels()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.roadAccent)
                            .frame(width: 56, height: 56)
                    }
                    .buttonStyle(CarKeyStyle(isRound: true))
                    .accessibilityLabel(Text(app: "Close"))
                }
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    title(of: model.channelList)
                        .font(Typography.screenTitle)
                    Text(app: "\(items.count) items")
                        .font(.title3)
                        .foregroundStyle(.roadMuted)
                }
                .lineLimit(1)
                if items.isEmpty {
                    Text(app: "Nothing here yet")
                        .font(Typography.body)
                        .foregroundStyle(.roadMuted)
                    Spacer(minLength: 0)
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: CarScreenMediaTile.side), spacing: Spacing.md)],
                            alignment: .leading,
                            spacing: Spacing.lg
                        ) {
                            ForEach(items) { media in
                                CarScreenMediaTile(media: media, model: model) {
                                    model.actions?.play(media, queue: items)
                                    model.showsChannels = false
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                .roadCanvas,
                in: UnevenRoundedRectangle(bottomTrailingRadius: Radius.lg, topTrailingRadius: Radius.lg)
            )
            .shadow(color: .black.opacity(0.3), radius: 16, x: 4)
        }

        /// The three lists, as the car's own tabs: the chosen one on the theme's gradient.
        private var lists: some View {
            HStack(spacing: Spacing.xxs) {
                ForEach(CarScreenModel.ChannelList.allCases, id: \.self) { list in
                    let isChosen = model.channelList == list
                    Button {
                        model.channelList = list
                    } label: {
                        title(of: list)
                            .font(Typography.sign)
                            .lineLimit(1)
                            .foregroundStyle(isChosen ? AnyShapeStyle(.roadOnBrand) : AnyShapeStyle(.primary))
                            .padding(.horizontal, Spacing.md)
                            .frame(minHeight: 48)
                            .background {
                                if isChosen {
                                    Capsule().fill(.roadBrandGradient)
                                }
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isChosen ? .isSelected : [])
                }
            }
            .padding(Spacing.xxs)
            .background(.roadSurface, in: Capsule())
        }

        private func title(of list: CarScreenModel.ChannelList) -> Text {
            switch list {
            case .home: Text(app: "Home")
            case .favorites: Text(app: "Favorites")
            case .group: model.playingGroup.map { Text($0) } ?? Text(app: "Channels")
            }
        }
    }
#endif
