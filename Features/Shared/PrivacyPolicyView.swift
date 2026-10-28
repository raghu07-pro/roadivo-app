import SwiftUI

/// The privacy policy: the same single-file page as the website (Docs/Website/roadivo-policy.html, bundled),
/// so the App Store link and the app always match. Keep it in step with PrivacyInfo.xcprivacy.
struct PrivacyPolicyView: View {
    static let pageURL = Bundle.main.url(forResource: "roadivo-policy", withExtension: "html")

    var body: some View {
        Group {
            // Always bundled; `PrivacyPolicyTests` fails the build's tests if it goes missing.
            if let page = Self.pageURL {
                HTMLPageView(fileURL: page)
                    .accessibilityIdentifier("privacy.page")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.roadCanvas)
        .clearsBottomAccessory()
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Light") {
    NavigationStack { PrivacyPolicyView() }
}

#Preview("Dark") {
    NavigationStack { PrivacyPolicyView() }
        .preferredColorScheme(.dark)
}
