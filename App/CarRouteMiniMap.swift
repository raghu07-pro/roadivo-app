#if DEBUG
    import MapKit
    import SwiftUI

    /// Over the car's other tabs while a route is open: a small live map of it in the corner, as the iPhone's route
    /// window (`RouteMiniCard`), where you are moving along it. A tap opens Maps; ✕ ends the route (DECISIONS 172).
    struct CarRouteMiniMap: View {
        let model: CarScreenModel
        let directions: DirectionsViewModel

        /// The whole route, kept in view as the car moves along it.
        @State private var camera: MapCameraPosition = .automatic
        @Environment(\.locale) private var locale

        private static let width: CGFloat = 300
        private static let mapHeight: CGFloat = 190

        var body: some View {
            if directions.hasActiveRoute, directions.isShown(on: .car), let destination = directions.destination,
               let route = directions.selectedRoute {
                let time = route.travelTimeText(locale: locale)
                let distance = route.distanceText(locale: locale)
                let shape = RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                ZStack(alignment: .topTrailing) {
                    openButton(destination: destination, time: time, distance: distance)
                    endButton
                }
                .frame(width: Self.width)
                .background(.roadSurface, in: shape)
                .clipShape(shape)
                .overlay { shape.strokeBorder(Color.primary.opacity(0.12), lineWidth: 1) }
                .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
                .onChange(of: route.id) {
                    camera = .automatic
                }
            }
        }

        private func openButton(destination: Place, time: String, distance: String) -> some View {
            Button {
                model.actions?.select(.maps)
            } label: {
                VStack(spacing: 0) {
                    // Only to look at: the tap opens Maps, where the map can be moved.
                    RouteMap(viewModel: directions, screen: .car, camera: $camera)
                        .allowsHitTesting(false)
                        .frame(width: Self.width, height: Self.mapHeight)
                        .accessibilityHidden(true)
                    VStack(spacing: 2) {
                        Text(destination.name)
                            .font(Typography.cardTitle)
                            .lineLimit(1)
                        Text(app: "\(time) · \(distance)")
                            .font(Typography.secondary)
                            .foregroundStyle(.roadMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .padding(.horizontal, Spacing.md)
                }
                .foregroundStyle(.primary)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(Text(app: "Route to \(destination.name)"))
            .accessibilityValue(Text(app: "\(time) · \(distance)"))
            .accessibilityHint(Text(app: "Opens Maps"))
        }

        private var endButton: some View {
            Button {
                withAnimation { directions.clear() }
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(.regularMaterial, in: Circle())
                    .frame(width: 56, height: 56)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(app: "End Route"))
        }
    }
#endif
