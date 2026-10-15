import SwiftUI

/// A sideways-scrolling row of choices ("Movies", "Sports", …); the chosen one is filled
/// with the accent and kept in view.
struct CategoryChips<ID: Hashable>: View {
    struct Chip: Identifiable {
        let id: ID
        let title: String
    }

    let chips: [Chip]
    @Binding var selection: ID
    /// The accessibility identifier prefix; each chip is `<prefix>.<title>`.
    var identifier = "chip"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(chips) { chip in
                        button(for: chip)
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
            .onChange(of: selection) { _, chosen in
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                    proxy.scrollTo(chosen, anchor: .center)
                }
            }
        }
    }

    private func button(for chip: Chip) -> some View {
        let isSelected = chip.id == selection
        return Button {
            selection = chip.id
        } label: {
            Text(chip.title)
                .font(Typography.secondary.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(isSelected ? Color.roadOnBrand : Color.primary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background {
                    if isSelected {
                        Capsule().fill(.roadBrandGradient)
                    } else {
                        Capsule()
                            .fill(.roadSurface)
                            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                    }
                }
                // A 44 pt touch target around the smaller capsule.
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(chip.id)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("\(identifier).\(chip.title)")
    }
}

#Preview {
    @Previewable @State var selection = "Movies"
    VStack(spacing: Spacing.lg) {
        CategoryChips(
            chips: ["Movies", "Sports", "Travel", "Interviews", "Kids"].map { .init(id: $0, title: $0) },
            selection: $selection
        )
        CategoryChips(
            chips: ["Movies", "Sports"].map { .init(id: $0, title: $0) },
            selection: $selection
        )
        .environment(\.dynamicTypeSize, .accessibility3)
    }
    .preferredColorScheme(.dark)
}
