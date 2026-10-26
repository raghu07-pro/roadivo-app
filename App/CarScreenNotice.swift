#if DEBUG
    import SwiftUI

    /// Why there's no picture, on CarPlay's wallpaper rather than Roadivo's road (owner, 2026-10-26; DECISIONS 163):
    /// watching needs Pro, video is off while driving, or Location is off. The same words as the CarPlay window's
    /// card, with what's playing above them.
    struct CarScreenNotice: View {
        let model: CarScreenModel
        /// What's playing; none for Pro or the iPhone's screen.
        var title: String?

        var body: some View {
            let content = CarWindowCard.Content(state: model.state, title: title)
            VStack(spacing: Spacing.sm) {
                if let title = content.title {
                    Text(title)
                        .font(.title2.bold())
                        .lineLimit(2)
                }
                if let message = content.message {
                    Text(message)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.center)
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { CarScreenWallpaper() }
        }
    }
#endif
