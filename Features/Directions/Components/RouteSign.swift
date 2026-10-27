import SwiftUI

/// The chosen route as a road sign (owner, 2026-10-27: "it looks normal as all have"; DECISIONS 172): the drive time
/// in Overpass, the highway-sign face, white on asphalt; when you'd arrive; the distance and road; the lane's dashes.
struct RouteSign: View {
    let route: RouteOption

    @Environment(\.locale) private var locale

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Side by side when they fit; the arrival under the time with large text or a narrow card.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    time
                    Spacer(minLength: 0)
                    arrival
                }
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    time
                    arrival
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(route.distanceText(locale: locale))
                if !route.name.isEmpty {
                    Circle()
                        .frame(width: 4, height: 4)
                        .accessibilityHidden(true)
                    Text("via \(route.name)")
                }
            }
            .font(Typography.secondary)
            .foregroundStyle(.white.opacity(0.78))
            .fixedSize(horizontal: false, vertical: true)
            LaneLine()
                .stroke(Palette.laneYellow, style: StrokeStyle(lineWidth: 3, dash: [14, 10]))
                .frame(height: 3)
                .padding(.top, Spacing.xxs)
                .accessibilityHidden(true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.roadAsphalt, in: shape)
        // Keeps the sign apart from a dark card around it.
        .overlay { shape.strokeBorder(.white.opacity(0.14), lineWidth: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("directions.summary")
    }

    private var time: some View {
        Text(route.travelTimeText(locale: locale))
            .font(Typography.screenTitle)
            .foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// When you'd get there leaving now, kept current as the minutes pass.
    private var arrival: some View {
        TimelineView(.everyMinute) { context in
            let at = context.date.addingTimeInterval(route.travelTime)
            Text("Arrive \(at.formatted(.dateTime.hour().minute().locale(locale)))")
                .font(Typography.sign)
                .foregroundStyle(Palette.laneYellow)
        }
    }
}

/// A straight line across the middle, for the lane's dashes.
private struct LaneLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

#Preview {
    let route = RouteOption(id: 0, name: "Delhi Mumbai Expressway", distance: 241_000, travelTime: 12120, path: [])
    RouteSign(route: route)
        .padding()
        .background(.roadCanvas)
}
