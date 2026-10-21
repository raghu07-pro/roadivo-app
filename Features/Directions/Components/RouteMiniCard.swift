import SwiftUI

/// Over the other tabs while a route is open: a small upright window in the bottom-right corner, like Maps' own,
/// with a map of the route and the drive time. A tap goes back to Directions; ✕ ends the route (DECISIONS 146).
struct RouteMiniCard: View {
    let viewModel: DirectionsViewModel
    let onOpen: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .body) private var scaledWidth: CGFloat = 116

    var body: some View {
        if let destination = viewModel.destination, let route = viewModel.selectedRoute {
            let time = route.travelTimeText(locale: locale)
            let distance = route.distanceText(locale: locale)
            ZStack(alignment: .topTrailing) {
                openButton(destination: destination, time: time, distance: distance)
                endButton
            }
            .frame(width: width)
            .foregroundStyle(.primary)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
            .task(id: "\(destination.id)|\(route.id)|\(colorScheme)|\(width)") {
                await viewModel.makeSnapshot(size: mapSize, isDark: colorScheme == .dark, line: UIColor(.roadBrand))
            }
        }
    }

    private func openButton(destination: Place, time: String, distance: String) -> some View {
        Button(action: onOpen) {
            VStack(spacing: 0) {
                map
                VStack(spacing: 0) {
                    Text(time)
                        .font(Typography.cardTitle)
                    Text(distance)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xs)
                .padding(.horizontal, Spacing.xxs)
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(Text("Route to \(destination.name)"))
        .accessibilityValue(Text("\(time) · \(distance)"))
        .accessibilityHint(Text("Opens Directions"))
        .accessibilityIdentifier("directions.miniRoute")
    }

    /// Narrow like a picture-in-picture window, and only a little wider with larger text.
    private var width: CGFloat {
        min(scaledWidth, 150)
    }

    /// Upright, as Maps' window is.
    private var mapSize: CGSize {
        CGSize(width: width, height: (width * 1.2).rounded())
    }

    private var map: some View {
        Group {
            if let snapshot = viewModel.snapshot {
                Image(uiImage: snapshot)
                    .resizable()
                    .scaledToFill()
            } else {
                // Until the map arrives, or when it can't (no network): the theme's colour with a map glyph.
                Image(systemName: "map.fill")
                    .font(.system(size: width * 0.28, weight: .semibold))
                    .foregroundStyle(.roadOnBrand)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.roadBrandGradient)
            }
        }
        .frame(width: mapSize.width, height: mapSize.height)
        .clipped()
        .accessibilityHidden(true)
    }

    private var endButton: some View {
        Button {
            withAnimation { viewModel.clear() }
        } label: {
            Image(systemName: "xmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
                .frame(width: 26, height: 26)
                .background(.regularMaterial, in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("End Route"))
        .accessibilityIdentifier("directions.miniRoute.end")
    }
}
