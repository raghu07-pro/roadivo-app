#if DEBUG
    import SwiftUI

    /// Why there's no picture, on Roadivo's canvas (DECISIONS 163–164): watching needs Pro, video is off while
    /// driving, or Location is off, in the CarPlay window card's words under what's playing.
    struct CarScreenNotice: View {
        let model: CarScreenModel
        /// What's playing; none for Pro or the iPhone's screen.
        var title: String?

        var body: some View {
            let content = CarWindowCard.Content(state: model.state, title: title)
            VStack(spacing: Spacing.sm) {
                if let title = content.title {
                    Text(title)
                        .font(Typography.screenTitle)
                        .lineLimit(2)
                }
                if let message = content.message {
                    Text(message)
                        .font(.title3)
                        .foregroundStyle(.roadMuted)
                }
            }
            .multilineTextAlignment(.center)
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.roadCanvas.ignoresSafeArea())
        }
    }
#endif
