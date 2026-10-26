#if DEBUG
    import SwiftUI

    /// The split view's left side while it has no picture, as CarTV's: how to cast the iPhone here, or, while it
    /// casts but the car moves, why the picture is off (DECISIONS 163).
    struct CarSplitPlaceholder: View {
        let model: CarScreenModel

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Image(systemName: "tv")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
                if model.isCasting {
                    Text(CarWindowCard.Content(state: .driving).message ?? "")
                        .font(.title3)
                } else {
                    Text(app: "Cast anything to this screen")
                        .font(.title3.bold())
                    Text(app: "On your iPhone, open Roadivo and go to Discover › Cast to Screen to get started.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
        }
    }
#endif
