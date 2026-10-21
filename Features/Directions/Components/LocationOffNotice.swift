import SwiftUI

/// Location is off for Roadivo, so routes have no start; Settings is where it's turned back on.
struct LocationOffNotice: View {
    /// On its own under the search field; inside the route card it drops its own card.
    var isCard = true

    @Environment(\.openURL) private var openURL

    var body: some View {
        let notice = VStack(alignment: .leading, spacing: Spacing.xs) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Location is off for Roadivo")
                        .font(Typography.cardTitle)
                    Text("Turn on Location in Settings to see routes from where you are.")
                        .font(Typography.secondary)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "location.slash.fill")
                    .foregroundStyle(.roadAccent)
            }
            Button {
                if let settings = URL(string: UIApplication.openSettingsURLString) {
                    openURL(settings)
                }
            } label: {
                Text("Open Settings")
                    .font(Typography.cardTitle)
                    .foregroundStyle(.roadAccent)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityIdentifier("directions.openSettings")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("directions.locationOff")

        if isCard {
            notice.cardStyle()
        } else {
            notice
        }
    }
}
