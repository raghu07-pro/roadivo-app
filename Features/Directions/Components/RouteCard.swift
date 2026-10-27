import SwiftUI

/// The chosen place and how to drive there: the fastest route and the others to pick from, with no Apple Maps button
/// (owner, 2026-10-27). It hides to one line, so the map gets the screen (DECISIONS 172).
struct RouteCard: View {
    let destination: Place
    let state: DirectionsViewModel.RouteState
    let routes: [RouteOption]
    @Binding var selectedRouteID: RouteOption.ID?
    let isLocationOff: Bool
    let onRetry: () -> Void
    let onClose: () -> Void
    /// The other screen's button beside ✕, as videos have: the car on the iPhone, the iPhone on the car.
    var move: Move?
    /// Hidden to one line; the parent keeps it, to give the map the room.
    @Binding var isCollapsed: Bool
    /// After a route chip is tapped, the chosen one again included: the car folds the card (DECISIONS 172).
    var onChooseRoute: (() -> Void)?

    /// Moves the route to the other screen (owner, 2026-10-27; DECISIONS 172).
    struct Move {
        let title: LocalizedStringResource
        let systemImage: String
        let action: () -> Void
    }

    @Environment(\.locale) private var locale

    var body: some View {
        Group {
            if isCollapsed {
                collapsed
            } else {
                // Scrolls only when it's taller than its space (large text, a short screen).
                ViewThatFits(in: .vertical) {
                    content
                    ScrollView { content }
                        .scrollBounceBehavior(.basedOnSize)
                }
            }
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
            iconButton("chevron.down", label: "Hide Routes") { setCollapsed(true) }
                .accessibilityIdentifier("directions.collapse")
            buttons
        }
    }

    /// The other screen's button and ✕, in the header and on the hidden card's line.
    @ViewBuilder private var buttons: some View {
        if let move {
            iconButton(move.systemImage, label: move.title, isAccent: true, action: move.action)
                .accessibilityIdentifier("directions.move")
        }
        iconButton("xmark", label: "Close", action: onClose)
            .accessibilityIdentifier("directions.close")
    }

    /// Round, as the card's other controls; its own style, as the car's screen gives buttons a key's look.
    private func iconButton(
        _ systemImage: String,
        label: LocalizedStringResource,
        isAccent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(isAccent ? AnyShapeStyle(.roadAccent) : AnyShapeStyle(.secondary))
                .frame(width: 44, height: 44)
                .background(
                    isAccent ? AnyShapeStyle(Color.roadBrand.opacity(0.14)) : AnyShapeStyle(.roadCanvas),
                    in: Circle()
                )
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(Text(app: label))
    }

    private func setCollapsed(_ collapsed: Bool) {
        withAnimation(.snappy(duration: 0.25)) { isCollapsed = collapsed }
    }

    // MARK: - Hidden

    /// One line: the place and the chosen route's time and distance. A tap shows the routes again.
    private var collapsed: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                setCollapsed(false)
            } label: {
                HStack(spacing: Spacing.sm) {
                    IconTile(systemImage: "arrow.triangle.turn.up.right.diamond.fill", size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(destination.name)
                            .font(Typography.cardTitle)
                            .lineLimit(1)
                        collapsedDetail
                            .font(Typography.secondary)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.up")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text(app: "Show Routes"))
            .accessibilityIdentifier("directions.expand")
            buttons
        }
    }

    @ViewBuilder private var collapsedDetail: some View {
        if state == .ready, let route = selectedRoute {
            HStack(spacing: Spacing.xs) {
                Text(route.travelTimeText(locale: locale))
                separator
                Text(route.distanceText(locale: locale))
            }
        } else if state == .loading {
            Text("Finding routes…")
        }
    }

    /// A small dot between the time, distance and road: drawn, as the app's font sets "·" with no gap after it.
    private var separator: some View {
        Circle()
            .frame(width: 4, height: 4)
            .accessibilityHidden(true)
    }

    private var selectedRoute: RouteOption? {
        routes.first { $0.id == selectedRouteID } ?? routes.first
    }

    @ViewBuilder
    private var ready: some View {
        if let route = selectedRoute {
            RouteSign(route: route)
            if routes.count > 1 {
                choices
            }
        }
    }

    /// Every route to the place, fastest first, each saying what it costs over the fastest; picking one draws it
    /// over the others.
    private var choices: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.xs) {
                ForEach(routes) { route in
                    RouteChoice(
                        tag: tag(for: route),
                        isFastest: route.id == routes.first?.id,
                        time: route.travelTimeText(locale: locale),
                        distance: route.distanceText(locale: locale),
                        isSelected: route.id == (selectedRouteID ?? routes.first?.id)
                    ) {
                        selectedRouteID = route.id
                        onChooseRoute?()
                    }
                    .accessibilityIdentifier("directions.choice.\(route.id)")
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    /// "Fastest", or how much longer than it: "+6 min".
    private func tag(for route: RouteOption) -> LocalizedStringKey {
        guard let fastest = routes.first, route.id != fastest.id else { return "Fastest" }
        let extra = Duration.seconds(max(60, (route.travelTime - fastest.travelTime).rounded()))
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated).locale(locale))
        return "+\(extra)"
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
    let tag: LocalizedStringKey
    let isFastest: Bool
    let time: String
    let distance: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Text(tag)
                    .font(Typography.badge)
                    .textCase(.uppercase)
                    .foregroundStyle(tagStyle)
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

    private var tagStyle: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(.roadOnBrand)
        }
        return isFastest ? AnyShapeStyle(.roadAccent) : AnyShapeStyle(.secondary)
    }
}
