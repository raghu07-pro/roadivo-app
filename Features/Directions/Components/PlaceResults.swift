import SwiftUI

/// Under the search field: the places found, or why there are none. Nothing while the field is empty.
struct PlaceResults: View {
    let search: DirectionsViewModel.Search
    let onChoose: (Place) -> Void
    let onRetry: () -> Void

    var body: some View {
        switch search {
        case .idle:
            EmptyView()
        case .searching:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 44)
                .cardStyle()
                .accessibilityIdentifier("directions.searching")
        case let .found(places):
            // Scrolls only when the list is taller than its space (large text, a short screen).
            ViewThatFits(in: .vertical) {
                list(places)
                ScrollView { list(places) }
            }
            .cardStyle(padding: 0)
        case .nothingFound:
            message(title: "No places found", detail: "Try another name or address.")
                .accessibilityIdentifier("directions.nothingFound")
        case .failed:
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Couldn't search right now. Check your connection and try again.")
                    .font(Typography.body)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Try Again", action: onRetry)
                    .font(Typography.cardTitle)
                    .foregroundStyle(.roadAccent)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("directions.searchRetry")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("directions.searchFailed")
        }
    }

    private func list(_ places: [Place]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                if index > 0 {
                    Divider().padding(.leading, Spacing.md)
                }
                row(place)
                    .accessibilityIdentifier("directions.place.\(index)")
            }
        }
    }

    private func row(_ place: Place) -> some View {
        Button {
            onChoose(place)
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "mappin.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.roadAccent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .font(Typography.body)
                        .foregroundStyle(.primary)
                    if !place.address.isEmpty, place.address != place.name {
                        Text(place.address)
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }

    private func message(title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .font(Typography.cardTitle)
            Text(detail)
                .font(Typography.secondary)
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}
