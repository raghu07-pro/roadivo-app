import SwiftUI

/// The map's two buttons, stacked in its top corner on the iPhone and the car (owner, 2026-10-27; DECISIONS 172):
/// search, which opens the place search, and under it the arrow that follows where you are. PlayCarTV's own, as Maps'
/// location button can't have another stacked on it.
struct MapButtons: View {
    /// The map follows where you are: the arrow is filled.
    let isFollowing: Bool
    /// Larger on the car's screen.
    var side: CGFloat = 48
    let onSearch: () -> Void
    /// Follows where you are; the screen folds its route card first (`DirectionsView.locate`).
    let onLocate: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xs) {
            button("magnifyingglass", label: "Search for a place", action: onSearch)
                .accessibilityIdentifier("directions.search")
            button(isFollowing ? "location.fill" : "location", label: "Show My Location", action: onLocate)
                .accessibilityIdentifier("directions.locate")
                .accessibilityAddTraits(isFollowing ? .isSelected : [])
        }
    }

    /// The stack's height, so the map's compass sits under it rather than behind it.
    static func height(side: CGFloat) -> CGFloat {
        side * 2 + Spacing.xs
    }

    private func button(
        _ systemImage: String,
        label: LocalizedStringResource,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.roadAccent)
                .frame(width: side, height: side)
                .background(.regularMaterial, in: Circle())
                .overlay { Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1) }
                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(Text(app: label))
    }
}
