import SwiftUI

/// Cast to Screen, as simple as CarTV's (owner, 2026-10-23): the whole iPhone on Roadivo's CarPlay window through
/// Screen Broadcast, with one button to start or end mirroring. The car shows it by itself; no address or Wi-Fi.
struct CastToScreenView: View {
    /// CarPlay is on, so the car's screen is there to show the iPhone.
    var isCarConnected = false
    /// Roadivo on the car's screen is showing this iPhone now.
    var isCarShowing = false

    @State private var picker = BroadcastPicker()
    @State private var broadcast = BroadcastStatus()
    @ScaledMetric(relativeTo: .largeTitle) private var displayWidth: CGFloat = 132

    private var state: CastScreenState {
        .make(isBroadcasting: broadcast.isBroadcasting, isCarConnected: isCarConnected, isCarShowing: isCarShowing)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                display
                status
                Divider()
                mirroring
                if state == .connected {
                    Label("Rotate your iPhone to watch full screen on the car's screen.", systemImage: "rotate.right")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .multilineTextAlignment(.center)
            .padding(Spacing.md)
            .padding(.top, Spacing.xl)
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
        .task { await broadcast.watch() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("broadcast.screen")
    }

    /// The car's screen in outline, with what it's doing: a check once it shows the iPhone.
    private var display: some View {
        let width = min(displayWidth, 180)
        return Image(systemName: symbol)
            .font(.largeTitle)
            .foregroundStyle(.roadAccent)
            .frame(width: width, height: width * 0.62)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(.roadAccent, lineWidth: 2)
            }
            .accessibilityHidden(true)
    }

    private var symbol: String {
        switch state {
        case .ready: "rectangle.on.rectangle"
        case .waitingForCar: "info.circle"
        case .connected: "checkmark"
        }
    }

    private var status: some View {
        VStack(spacing: Spacing.xs) {
            switch state {
            case .connected:
                Text("Display connected")
                    .font(Typography.sectionTitle)
                hint("Open any app to share your screen", symbol: "checkmark.circle")
            case let .waitingForCar(isCarConnected):
                carLine(isCarConnected)
                hint("Open Roadivo in CarPlay first", symbol: "info.circle")
            case let .ready(isCarConnected):
                carLine(isCarConnected)
                hint(
                    isCarConnected
                        ? "Tap Start mirroring to show this iPhone on the car's screen."
                        : "Connect to CarPlay and open Roadivo on the car's screen.",
                    symbol: "info.circle"
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cast.status")
    }

    private func carLine(_ isConnected: Bool) -> some View {
        Label(isConnected ? "Car connected" : "No car connected", systemImage: isConnected ? "car.fill" : "car")
            .font(Typography.cardTitle)
            .foregroundStyle(isConnected ? AnyShapeStyle(Color.roadAccent) : AnyShapeStyle(.secondary))
    }

    private func hint(_ text: LocalizedStringKey, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(Typography.secondary)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// One button, as in CarTV: Start Mirroring opens Apple's sheet; End Mirroring asks the broadcast to stop.
    private var mirroring: some View {
        VStack(spacing: Spacing.sm) {
            Label("Screen Mirroring", systemImage: "rectangle.on.rectangle")
                .font(Typography.sectionTitle)
                .labelStyle(.titleAndIcon)
            if state.isMirroring {
                Button(role: .destructive) {
                    BroadcastSignal.requestStop()
                } label: {
                    // Red set here: `PressableStyle` doesn't carry the destructive role's tint.
                    Label("End mirroring", systemImage: "stop.circle")
                        .font(Typography.cardTitle)
                        .foregroundStyle(.red)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("cast.end")
            } else {
                Button {
                    picker.show()
                } label: {
                    Label("Start mirroring", systemImage: "play.circle")
                        .font(Typography.cardTitle)
                        .foregroundStyle(.roadAccent)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityHint(Text("Opens Apple's Screen Broadcast; choose Roadivo, then Start Broadcast"))
                .accessibilityIdentifier("cast.start")
            }
        }
        .buttonStyle(PressableStyle())
    }
}

#Preview("Ready, car connected") {
    NavigationStack {
        CastToScreenView(isCarConnected: true)
    }
}

#Preview("Connected, dark, large text") {
    NavigationStack {
        CastToScreenView(isCarConnected: true, isCarShowing: true)
    }
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility2)
}
