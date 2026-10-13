import SwiftUI

/// The privacy policy, in the app. Shared by Settings and the paywall.
/// Keep it in step with PrivacyInfo.xcprivacy and the App Store privacy label.
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Roadivo Privacy Policy")
                        .font(Typography.screenTitle)
                        .accessibilityAddTraits(.isHeader)
                    Text("Last updated: 13 October 2026")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Roadivo is a media player. You bring your own playlists, media servers and videos.")
                Text("Roadivo plays them. This policy explains what happens to your data.")
                ForEach(PrivacySection.all) { section in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(app: section.title)
                            .font(Typography.sectionTitle)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(section.points.indices, id: \.self) { index in
                            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                                Text("•").accessibilityHidden(true)
                                Text(app: section.points[index])
                            }
                        }
                    }
                }
            }
            .font(Typography.body)
            .padding(Spacing.md)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(.roadCanvas)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrivacySection: Identifiable {
    let id: Int
    let title: LocalizedStringResource
    let points: [LocalizedStringResource]

    // Policy text reads as prose; wrapping it mid-sentence hurts more than it helps.
    // swiftlint:disable line_length
    static let all: [PrivacySection] = [
        PrivacySection(id: 0, title: "The short version", points: [
            "Your playlists, media servers, sign-in details and videos stay on your iPhone. We don't record what you watch.",
            "Roadivo has no analytics, no ads and no tracking. It never asks to track you.",
            "There are no accounts, and we never sell or share personal information."
        ]),
        PrivacySection(id: 1, title: "Data stored on your iPhone", points: [
            "Playlist links, Xtream logins and media-server access tokens are kept in the iOS Keychain.",
            "Channel lists, favourites and watch history are kept in the app's private storage.",
            "Videos you import from Photos or Files are copied into the app and deleted when you remove them."
        ]),
        PrivacySection(id: 2, title: "Network connections", points: [
            "Roadivo connects only to the playlist links, IPTV providers and media servers you add, and to the stream addresses they list. Those services have their own privacy policies.",
            "AirPlay sends video only to the screen you pick."
        ]),
        PrivacySection(id: 3, title: "Camera and Photos", points: [
            "The camera is used only while you scan a QR code, and nothing is recorded.",
            "Roadivo sees only the photos and videos you pick."
        ]),
        PrivacySection(id: 4, title: "Purchases", points: [
            "Roadivo Pro is sold through the App Store. Apple handles payment; we never see your card or Apple Account details."
        ]),
        PrivacySection(id: 5, title: "Deleting your data", points: [
            "Delete a source in Settings › Manage Sources, or delete the app to remove everything it stored."
        ]),
        PrivacySection(id: 6, title: "Contact", points: [
            "Questions about this policy? Reach us through Roadivo's App Store page."
        ])
    ]
    // swiftlint:enable line_length
}

#Preview {
    NavigationStack { PrivacyPolicyView() }
}
