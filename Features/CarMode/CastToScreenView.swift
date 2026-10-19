import SwiftUI

/// Cast to Screen, as in CarTV (owner, 2026-10-19; DECISIONS 124): Screen Broadcast puts the whole iPhone, any
/// app, on a car screen with a web browser, over the same Wi-Fi or this iPhone's Personal Hotspot. AirPlay screens
/// use iOS's own Screen Mirroring, linked below.
struct CastToScreenView: View {
    let isPro: Bool

    @State private var picker = BroadcastPicker()
    @State private var address = BroadcastAddress.current()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                hero
                PrimaryButton(title: "Start Broadcast", systemImage: "record.circle") {
                    LocalNetworkAccess.request()
                    picker.show()
                }
                .accessibilityHint(Text("Opens Apple's Screen Broadcast; choose Roadivo, then Start Broadcast"))
                .accessibilityIdentifier("broadcast.start")
                addressCard
                SectionHeader("How It Works")
                VStack(alignment: .leading, spacing: Spacing.md) {
                    GuideStep(number: 1, text: Self.stepConnect)
                    GuideStep(number: 2, text: "Tap Start Broadcast, then Start Broadcast again.")
                    GuideStep(number: 3, text: "On the car's screen, open its web browser and go to the address above.")
                    GuideStep(number: 4, text: Self.stepStop)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("broadcast.steps")
                Text(Self.notes)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                SectionHeader("AirPlay Screens")
                mirroringLink
            }
            .padding(Spacing.md)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(alignment: .topLeading) {
            BroadcastPickerHost(picker: picker)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .accessibilityHidden(true)
        }
        .background(.roadCanvas)
        .clearsBottomAccessory()
        .navigationTitle("Cast to Screen")
        .navigationBarTitleDisplayMode(.inline)
        // The address changes with the network: joining the car's Wi-Fi or turning on the hotspot.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                address = BroadcastAddress.current()
            }
        }
        .accessibilityIdentifier("broadcast.screen")
    }

    private static let stepConnect: LocalizedStringResource =
        "Join the car's screen to the same Wi‑Fi as this iPhone, or to this iPhone's Personal Hotspot."
    private static let stepStop: LocalizedStringResource =
        "To stop, tap the red indicator at the top of the screen, or Start Broadcast, and choose Stop."
    private static let notes: LocalizedStringResource = """
    Everything on your iPhone shows, including notifications. Apps that protect their videos, like most paid \
    streaming apps, show black. Sound stays on your iPhone. For passengers, or while parked.
    """

    /// The iPhone, a stream, the car's screen.
    private var hero: some View {
        HStack(spacing: Spacing.lg) {
            endpoint("iphone", label: "iPhone")
            Image(systemName: "dot.radiowaves.right")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.roadAccent)
                .accessibilityHidden(true)
            endpoint("tv", label: "Car screen")
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func endpoint(_ symbol: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: symbol)
                .font(.largeTitle)
                .foregroundStyle(.roadAccent)
                .frame(width: 88, height: 88)
                .background(.roadSurface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            Text(label)
                .font(Typography.secondary)
                .foregroundStyle(.roadMuted)
        }
    }

    /// What to type on the car's screen, or what to do first when there's no Wi-Fi or hotspot.
    private var addressCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("On the car's screen, open")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
            if let address {
                HStack(spacing: Spacing.sm) {
                    Text(address) // An address reads the same in every language.
                        .font(Typography.sectionTitle.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        UIPasteboard.general.string = address
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .labelStyle(.iconOnly)
                            .font(.body.weight(.semibold))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityIdentifier("broadcast.copy")
                }
            } else {
                Text("Join a Wi‑Fi network or turn on Personal Hotspot first.")
                    .font(Typography.cardTitle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("broadcast.address")
    }

    private var mirroringLink: some View {
        NavigationLink {
            ConnectGuideView(
                guide: ConnectGuide(hasCarPlay: CarPlayAvailability.isEnabled),
                isPro: isPro,
                focusedSection: "mirroring"
            )
        } label: {
            HStack(spacing: Spacing.sm) {
                IconTile(systemImage: "airplayvideo", style: .soft, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Screen Mirroring")
                        .font(Typography.cardTitle)
                        .foregroundStyle(.primary)
                    Text("For a car display or adapter with AirPlay")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .cardStyle()
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier("broadcast.mirroring")
    }
}
