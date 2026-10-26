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
                mirroring
                if state == .connected {
                    Text("Rotate your iPhone to watch full screen on the car's screen.")
                        .font(Typography.caption)
                        .foregroundStyle(.roadMuted)
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
        case .waitingForCar: "car.fill"
        case .connected: "checkmark"
        }
    }

    private var status: some View {
        VStack(spacing: Spacing.xs) {
            switch state {
            case .connected:
                Text("Display connected")
                    .font(Typography.sectionTitle)
                hint("Open any app to share your screen")
            case let .waitingForCar(isCarConnected):
                carLine(isCarConnected)
                hint("Open Roadivo in CarPlay first")
            case let .ready(isCarConnected):
                carLine(isCarConnected)
                hint(
                    isCarConnected
                        ? "Tap Start mirroring to show this iPhone on the car's screen."
                        : "Connect to CarPlay and open Roadivo on the car's screen."
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cast.status")
    }

    private func carLine(_ isConnected: Bool) -> some View {
        Label(isConnected ? "Car connected" : "No car connected", systemImage: isConnected ? "car.fill" : "car")
            .font(Typography.cardTitle)
            .foregroundStyle(isConnected ? AnyShapeStyle(Color.roadAccent) : AnyShapeStyle(.roadMuted))
    }

    /// Plain centred text: a label's icon pulled wrapped lines off the centre.
    private func hint(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(Typography.secondary)
            .foregroundStyle(.roadMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// One button, the screen's main action: Start mirroring opens Apple's sheet; End mirroring stops the broadcast.
    @ViewBuilder private var mirroring: some View {
        if state.isMirroring {
            Button(role: .destructive) {
                BroadcastSignal.requestStop()
            } label: {
                Label("End mirroring", systemImage: "stop.circle.fill")
                    .font(Typography.button)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(.roadLive)
            .accessibilityIdentifier("cast.end")
        } else {
            PrimaryButton(title: "Start mirroring", systemImage: "rectangle.on.rectangle") {
                picker.show()
            }
            .accessibilityHint(Text("Opens Apple's Screen Broadcast; choose Roadivo, then Start Broadcast"))
            .accessibilityIdentifier("cast.start")
        }
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
