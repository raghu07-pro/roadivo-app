#if DEBUG
    import SwiftUI

    /// The split view's left side while it has no picture, as CarTV's: how to cast the iPhone here, or, while it
    /// casts but the car moves, why the picture is off (DECISIONS 163). Drawn as the car screen's Cast tab.
    struct CarSplitPlaceholder: View {
        let model: CarScreenModel

        var body: some View {
            // Centred in the panel, and scrolls rather than clips at large text sizes.
            GeometryReader { proxy in
                ScrollView {
                    message
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .background { CarScreenBackdrop() }
            // Settings › Theme's accent and font style, as the rest of the car screen (`CarScreenView`).
            .tint(.roadAccent)
            .fontDesign(AppTheme.shared.font.rootDesign)
        }

        private var message: some View {
            VStack(spacing: Spacing.sm) {
                IconTile(systemImage: model.isCasting ? "car.fill" : "rectangle.on.rectangle", style: .soft, size: 64)
                if model.isCasting {
                    Text(CarWindowCard.Content(state: .driving).message ?? "")
                        .font(Typography.sectionTitle)
                } else {
                    Text(app: "Cast anything to this screen")
                        .font(Typography.sectionTitle)
                    Text(app: "On your iPhone, open PlayCarTV and go to Discover › Cast to Screen to get started.")
                        .font(Typography.body)
                        .foregroundStyle(.roadMuted)
                }
            }
            .multilineTextAlignment(.center)
            .padding(Spacing.lg)
        }
    }
#endif
