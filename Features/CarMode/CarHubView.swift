import SwiftUI

/// Cast to Car, with live status for the three real routes: Roadivo's CarPlay app (video when
/// parked, sound while driving), AirPlay to a car display or adapter, and Car Mode.
struct CarHubView: View {
    let viewModel: CarHubViewModel
    let playback: PlaybackController
    let connection: CarConnection
    let isPro: Bool
    let revision: Int
    let onStartCarMode: (MediaItem?) -> Void
    let onUpgrade: () -> Void
    let onBrowse: () -> Void
    /// Off until Apple grants the CarPlay entitlement, so the tab never promises it.
    var showsCarPlay = CarPlayAvailability.isEnabled

    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if isConnected {
                    connectedContent
                } else {
                    notConnectedContent
                }
            }
            .background(.roadCanvas)
            .clearsBottomAccessory()
            .navigationTitle("Cast to Car")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Not before a car connects: the page's own How to Connect link is there (owner, 2026-10-16).
                if isConnected {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink(value: Route.guide) {
                            Label("How to Connect", systemImage: "questionmark.circle")
                        }
                        .accessibilityIdentifier("cast.guide")
                    }
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .guide:
                    ConnectGuideView(guide: ConnectGuide(hasCarPlay: showsCarPlay), isPro: isPro)
                case let .profile(id):
                    if let editor = viewModel.profileEditor(for: id) {
                        DisplayProfileEditorView(viewModel: editor, isPro: isPro)
                    }
                }
            }
        }
        .task(id: revision) { viewModel.load() }
    }

    private enum Route: Hashable {
        case guide
        case profile(UUID)
    }

    private var connectedContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                dashboard
                if showsCarPlay {
                    carPlayCard
                }
                carModeCard
                airPlayCard
                // After the ways to the car: a setting, not a first step.
                if let receiver = connection.receiver {
                    profileCard(receiver)
                }
                safetyNote
            }
            .padding(Spacing.md)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }

    /// Simple and centred (the owner's reference): how to connect, and nothing to tap until a car
    /// is connected (the owner's call, 2026-10-15). Connected, Car Mode and AirPlay appear.
    private var notConnectedContent: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: Spacing.md) {
                        notConnected
                        NavigationLink(value: Route.guide) {
                            Label("How to Connect", systemImage: "questionmark.circle")
                                .font(Typography.cardTitle)
                                .foregroundStyle(.roadAccent)
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("cast.guide.link")
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            // The status in the middle, the safety note resting at the bottom (owner's layout).
            safetyNote
                .frame(maxWidth: 520)
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.sm)
        }
    }

    private var safetyNote: some View {
        Label {
            Text("For passengers, or while parked. Never watch video while driving.")
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.roadAccent)
        }
        .font(Typography.caption)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.roadSurface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cast.safety")
    }

    // MARK: Dashboard

    private var isConnected: Bool {
        connection.isCarPlayConnected || connection.airPlayDestination != nil || connection.isCarAudio
            || connection.receiver != nil // A wired display, too.
    }

    /// Before a car is connected: Roadivo → the car's screen, and how to get there. Deliberately no
    /// "any app" promise: Roadivo shows its own video only (App Review 2.3.1).
    private var notConnected: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.lg) {
                endpoint(symbol: "play.rectangle.fill", label: Text("Roadivo"), isActive: true)
                Image(systemName: "arrow.right")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                endpoint(symbol: "car.fill", label: Text("Car screen"), isActive: false)
            }
            Text("Not connected to a car")
                .font(Typography.screenTitle)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("""
            Connect your iPhone to the car with CarPlay, or pick the car's screen for AirPlay in Control \
            Center. Car Mode and AirPlay appear here once you're connected.
            """)
            .font(Typography.body)
            .foregroundStyle(.roadMuted)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cast.status")
    }

    private func endpoint(symbol: String, label: Text, isActive: Bool) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: symbol)
                .font(.largeTitle)
                .foregroundStyle(isActive ? AnyShapeStyle(.roadAccent) : AnyShapeStyle(.tertiary))
                .frame(width: 88, height: 88)
                .background(.roadSurface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            label
                .font(Typography.secondary)
                .foregroundStyle(isActive ? AnyShapeStyle(.roadMuted) : AnyShapeStyle(.tertiary))
        }
    }

    private var dashboard: some View {
        RoadScene(time: .night, horizon: 0.42)
            .frame(height: 210)
            .overlay {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: connection.isCarPlayConnected ? "car.side.fill" : "car.side")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(connection.isCarPlayConnected ? Color.roadAccent : .white.opacity(0.75))
                        .symbolEffect(.pulse, isActive: connection.isCarPlayConnected)
                    Text(statusTitle)
                        .font(Typography.sectionTitle)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(statusDetail)
                        .font(Typography.data)
                        .textCase(.uppercase)
                        .foregroundStyle(.roadAccent)
                        .multilineTextAlignment(.center)
                }
                .padding(Spacing.lg)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .padding(Spacing.md)
                // Always on the night scene: the accent's bright variant.
                .environment(\.colorScheme, .dark)
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("cast.status")
    }

    private var statusTitle: LocalizedStringKey {
        if connection.isCarPlayConnected {
            return "Roadivo is on your car's screen"
        }
        if connection.airPlayDestination != nil {
            return "Casting with AirPlay"
        }
        if connection.isCarAudio {
            return "Connected to your car"
        }
        return "Not connected to a car"
    }

    private var statusDetail: String {
        if connection.isCarPlayConnected {
            return String(appLocalized: "CarPlay connected")
        }
        if let destination = connection.airPlayDestination {
            return destination
        }
        if connection.isCarAudio {
            return String(appLocalized: "Car audio connected")
        }
        return showsCarPlay
            ? String(appLocalized: "Connect CarPlay or AirPlay")
            : String(appLocalized: "Connect AirPlay, or use Car Mode")
    }

    // MARK: Routes

    private var carPlayCard: some View {
        card(
            title: "CarPlay",
            symbol: "car.front.waves.up",
            status: isPro ? carPlayStatus : String(appLocalized: "Included with Roadivo Pro"),
            state: isPro ? (connection.isCarPlayConnected ? .active : .idle) : .locked
        ) {
            Text(
                "Connect CarPlay, then open Roadivo on the car's screen to pick from Favorites, Recent and Library."
            )
            .font(Typography.secondary)
            Text(
                "Video plays on the car's display while parked, in cars with CarPlay video. Driving? Sound only."
            )
            .font(Typography.caption)
            .foregroundStyle(.secondary)
            if !isPro {
                Button(action: onUpgrade) {
                    Label("Unlock with Roadivo Pro", systemImage: "crown.fill").font(Typography.cardTitle)
                }
                .accessibilityIdentifier("cast.upgrade")
            }
        }
    }

    private var airPlayCard: some View {
        card(
            title: "AirPlay",
            symbol: "airplayvideo",
            status: connection.airPlayDestination ?? String(appLocalized: "Ready when you are"),
            state: connection.airPlayDestination == nil ? .idle : .active
        ) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Text("Send video to an AirPlay car display, a wireless adapter or a TV.")
                    .font(Typography.secondary)
                Spacer(minLength: 0)
                RoutePickerButton(tint: .label)
                    .frame(width: 48, height: 48)
                    .background(.roadSurfaceElevated, in: Circle())
                    .accessibilityIdentifier("cast.airplay")
            }
        }
    }

    private var carModeCard: some View {
        card(
            title: "Car Mode",
            symbol: "iphone.landscape",
            status: isPro ? String(appLocalized: "Ready") : String(appLocalized: "Included with Roadivo Pro"),
            state: isPro ? .idle : .locked
        ) {
            Text("No car screen? Mount your iPhone: landscape, oversized controls, screen kept awake.")
                .font(Typography.secondary)
            if playback.isActive || viewModel.resumeItem != nil {
                PrimaryButton(title: "Start Car Mode", systemImage: "car.fill") {
                    onStartCarMode(playback.isActive ? nil : viewModel.resumeItem)
                }
                .accessibilityIdentifier("car.start")
                Text("Plays \(playback.current?.title ?? viewModel.resumeItem?.title ?? "")")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            } else {
                PrimaryButton(title: "Pick Something to Watch", systemImage: "play.square.stack", action: onBrowse)
                    .accessibilityIdentifier("car.browse")
            }
        }
    }

    private var carPlayStatus: String {
        connection.isCarPlayConnected ? String(appLocalized: "Connected") : String(appLocalized: "Not connected")
    }

    private func card(
        title: LocalizedStringKey,
        symbol: String,
        status: String,
        state: CardHeader.Status,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            CardHeader(title: title, systemImage: symbol, status: status, state: state)
            Divider()
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - Display profile

extension CarHubView {
    /// The connected screen's display profile: in use, or offered to save (DECISIONS 110).
    private func profileCard(_ receiver: Receiver) -> some View {
        let profile = viewModel.profile(for: receiver)
        return card(
            title: "Display Profile",
            symbol: "slider.horizontal.below.rectangle",
            status: profile
                .map { String(appLocalized: "Using \($0.displayName)") } ?? String(appLocalized: "Not saved"),
            state: profile == nil ? .idle : .active
        ) {
            Text("Keep this screen's aspect ratio, subtitles and playback; Roadivo uses them each time it connects.")
                .font(Typography.secondary)
            if let profile {
                Button {
                    path.append(.profile(profile.id))
                } label: {
                    Label("Edit Profile", systemImage: "slider.horizontal.3")
                        .font(Typography.cardTitle)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("cast.profile.edit")
            } else {
                PrimaryButton(title: "Save a Profile for \(receiver.name)", systemImage: "plus") {
                    path.append(.profile(viewModel.saveProfile(for: receiver)))
                }
                .accessibilityIdentifier("cast.profile.save")
            }
        }
        // A container, so the Save and Edit buttons keep their own identifiers.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cast.profile")
    }
}
