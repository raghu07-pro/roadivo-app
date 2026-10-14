import SwiftUI

/// Full player: video on top, the rest of the group below so the user can
/// switch while watching. Landscape is video-only.
struct PlayerView: View {
    @State var viewModel: PlayerViewModel
    let onMinimize: () -> Void
    let onCarMode: () -> Void
    let onFavoriteChanged: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        Group {
            if verticalSizeClass == .compact {
                landscape
            } else {
                portrait
            }
        }
        .background(.roadCanvas)
    }

    private var landscape: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            video.ignoresSafeArea()
            minimizeButton.padding(Spacing.md)
        }
    }

    private var portrait: some View {
        VStack(spacing: 0) {
            topBar
            video
                .aspectRatio(16 / 9, contentMode: .fit)
                .background(.black)
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    details
                    if viewModel.upNext.count > 1 {
                        upNext
                    }
                }
                .padding(Spacing.md)
            }
        }
    }

    private var video: some View {
        ZStack {
            SystemVideoPlayer(player: viewModel.playback.player)
            if let message = viewModel.errorMessage {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.title)
                    Text(message).font(Typography.secondary).multilineTextAlignment(.center)
                    Button("Try Again", action: viewModel.retry)
                        .buttonStyle(.borderedProminent)
                        .tint(.roadBrand)
                        .foregroundStyle(.roadOnBrand)
                }
                .foregroundStyle(.white)
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black.opacity(0.75))
            }
        }
    }

    private var minimizeButton: some View {
        Button(action: onMinimize) {
            Image(systemName: "chevron.down")
                .font(.body.weight(.bold))
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel(Text("Minimize player"))
        .accessibilityIdentifier("player.minimize")
    }

    private var topBar: some View {
        HStack(spacing: Spacing.xs) {
            minimizeButton
            Spacer()
            RoutePickerButton(tint: .label)
                .frame(width: 44, height: 44)
            Button(action: onCarMode) {
                Label("Car Mode", systemImage: "car.fill")
                    .font(Typography.secondary.weight(.semibold))
                    .padding(.horizontal, Spacing.sm)
                    .frame(minHeight: 44)
                    .background(.roadSurfaceElevated, in: Capsule())
            }
            .accessibilityIdentifier("player.carMode")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
    }

    private var details: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                if viewModel.playback.isLive, viewModel.errorMessage == nil, viewModel.playback.status == .playing {
                    LiveBadge()
                }
                Text(viewModel.current?.title ?? "")
                    .font(Typography.screenTitle)
                    .accessibilityAddTraits(.isHeader)
                Text(viewModel.current?.groupTitle ?? "")
                    .font(Typography.secondary)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            let isFavorite = viewModel.current?.isFavorite ?? false
            Button {
                if viewModel.toggleFavorite() {
                    onFavoriteChanged()
                }
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundStyle(isFavorite ? Color.roadLive : Color.primary)
                    .frame(width: 48, height: 48)
                    .background(.roadSurfaceElevated, in: Circle())
                    .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityLabel(isFavorite ? Text("Remove from Favorites") : Text("Add to Favorites"))
            .accessibilityIdentifier("player.favorite")
        }
    }

    private var upNext: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("More in \(viewModel.current?.groupTitle ?? "")")
                .font(Typography.sectionTitle)
                .accessibilityAddTraits(.isHeader)
            LazyVStack(spacing: Spacing.xxs) {
                ForEach(viewModel.upNext) { item in
                    UpNextRow(item: item, isCurrent: item.id == viewModel.current?.id) {
                        viewModel.select(item)
                    }
                }
            }
        }
    }
}
