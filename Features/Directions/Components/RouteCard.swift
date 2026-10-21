import SwiftUI

/// The chosen place and how to drive there: the fastest route, other routes to pick from, and Apple Maps.
struct RouteCard: View {
    let destination: Place
    let state: DirectionsViewModel.RouteState
    let routes: [RouteOption]
    @Binding var selectedRouteID: RouteOption.ID?
    let isLocationOff: Bool
    let onOpenInMaps: () -> Void
    let onRetry: () -> Void
    let onClose: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        // Scrolls only when it's taller than its space (large text, a short screen).
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
                .scrollBounceBehavior(.basedOnSize)
        }
        .cardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("directions.route")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            header
            switch state {
            case .loading:
                HStack(spacing: Spacing.xs) {
                    ProgressView()
                    Text("Finding routes…")
                        .font(Typography.secondary)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("directions.routing")
            case .ready:
                ready
            case .noRoute:
                note("No driving route found to this place.")
                    .accessibilityIdentifier("directions.noRoute")
            case .failed:
                retry("Couldn't find a route. Check your connection and try again.")
            case .needsLocation:
                if isLocationOff {
                    LocationOffNotice(isCard: false)
                } else {
                    retry("Couldn't find where you are. Try again in a moment.")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(destination.name)
                    .font(Typography.cardTitle)
                    .accessibilityAddTraits(.isHeader)
                if !destination.address.isEmpty, destination.address != destination.name {
                    Text(destination.address)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Close"))
            .accessibilityIdentifier("directions.close")
        }
    }

    @ViewBuilder
    private var ready: some View {
        if let route = routes.first(where: { $0.id == selectedRouteID }) ?? routes.first {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(route.travelTimeText(locale: locale)) · \(route.distanceText(locale: locale))")
                    .font(Typography.sectionTitle)
                if !route.name.isEmpty {
                    Text("via \(route.name)")
                        .font(Typography.secondary)
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("directions.summary")
            if routes.count > 1 {
                choices
            }
            PrimaryButton(
                title: "Open in Apple Maps",
                systemImage: "arrow.triangle.turn.up.right.diamond.fill",
                action: onOpenInMaps
            )
            .accessibilityIdentifier("directions.openMaps")
        }
    }

    /// Every route to the place, fastest first; picking one draws it over the others.
    private var choices: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.xs) {
                ForEach(routes) { route in
                    RouteChoice(
                        time: route.travelTimeText(locale: locale),
                        distance: route.distanceText(locale: locale),
                        isSelected: route.id == (selectedRouteID ?? routes.first?.id)
                    ) {
                        selectedRouteID = route.id
                    }
                    .accessibilityIdentifier("directions.choice.\(route.id)")
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func note(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(Typography.body)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func retry(_ text: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            note(text)
            Button("Try Again", action: onRetry)
                .font(Typography.cardTitle)
                .foregroundStyle(.roadAccent)
                .frame(minHeight: 44)
                .accessibilityIdentifier("directions.retry")
        }
    }
}

/// One route among several: its time and distance.
private struct RouteChoice: View {
    let time: String
    let distance: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Text(time)
                    .font(Typography.cardTitle)
                Text(distance)
                    .font(Typography.caption)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.roadOnBrand) : AnyShapeStyle(.secondary))
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .frame(minHeight: 44)
            .foregroundStyle(isSelected ? AnyShapeStyle(.roadOnBrand) : AnyShapeStyle(.primary))
            .background(
                isSelected ? AnyShapeStyle(.roadBrandGradient) : AnyShapeStyle(.roadCanvas),
                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
