import SwiftUI

/// A section title: a short amber lane marker, the title in Overpass, and a
/// quiet count underneath ("24 channels"). An optional symbol replaces the
/// marker for special sections (Continue Watching).
struct SectionTitle: View {
    let title: String
    var detail: String?
    var systemImage: String?

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.body.weight(.bold))
                    .foregroundStyle(.roadAsphalt)
                    .frame(width: 30, height: 30)
                    .background(.roadLane, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .accessibilityHidden(true)
            } else {
                Capsule()
                    .fill(Color.roadLane)
                    .frame(width: 5, height: 26)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(Typography.sectionTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let detail {
                    Text(detail)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The yellow centre line as a divider.
struct LaneDivider: View {
    var body: some View {
        Line()
            .stroke(Color.roadLane, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [14, 10]))
            .frame(height: 3)
            .accessibilityHidden(true)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

/// The header of a feature card: an amber icon tile, the title and a live
/// status line with a coloured dot.
struct CardHeader: View {
    enum Status {
        case active
        case idle
        case locked
    }

    let title: LocalizedStringKey
    let systemImage: String
    let status: String
    var state: Status = .idle

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.roadAsphalt)
                .frame(width: 46, height: 46)
                .background(
                    LinearGradient(
                        colors: [Color.roadLane, Color.roadLane.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.sectionTitle)
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Image(systemName: state == .locked ? "lock.fill" : "circle.fill")
                        .font(.system(size: state == .locked ? 10 : 7, weight: .bold))
                        .foregroundStyle(dotColor)
                        .accessibilityHidden(true)
                    Text(status)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var dotColor: Color {
        switch state {
        case .active: .green
        case .idle: .secondary
        case .locked: .roadAccent
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        SectionTitle(title: "Movies", detail: "24 channels")
        SectionTitle(title: "Continue Watching", detail: "3 channels", systemImage: "clock.arrow.circlepath")
        CardHeader(title: "CarPlay", systemImage: "car.front.waves.up", status: "Not connected")
        CardHeader(title: "AirPlay", systemImage: "airplayvideo", status: "Car Display", state: .active)
        LaneDivider()
    }
    .padding()
    .background(.roadCanvas)
}
