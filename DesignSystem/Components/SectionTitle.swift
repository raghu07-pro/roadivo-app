import SwiftUI

/// A section title: a short lane marker in the theme's gradient, the title in
/// Overpass, and a quiet count underneath ("24 channels"). An optional symbol
/// replaces the marker for special sections (Continue Watching).
struct SectionTitle: View {
    let title: String
    var detail: String?
    var systemImage: String?

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            if let systemImage {
                IconTile(systemImage: systemImage)
            } else {
                Capsule()
                    .fill(LinearGradient(colors: [.roadBrand, .roadBrandDeep], startPoint: .top, endPoint: .bottom))
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

/// The header of a feature card: an icon tile in the theme's gradient, the
/// title and a live status line with a coloured dot.
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
            IconTile(systemImage: systemImage, size: 46)
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
    }
    .padding()
    .background(.roadCanvas)
}

#Preview("Dark, largest text") {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        SectionTitle(title: "Movies", detail: "24 channels")
        CardHeader(title: "Car Mode", systemImage: "iphone.landscape", status: "Ready", state: .locked)
    }
    .padding()
    .background(.roadCanvas)
    .preferredColorScheme(.dark)
    .environment(\.dynamicTypeSize, .accessibility3)
}
