import SwiftUI

/// "Cast to Car": how Roadivo reaches the car's screen, with live status.
/// Three routes, all real: Roadivo's own CarPlay app (video while parked in
/// cars that support it, sound while driving), AirPlay to a car display or
/// adapter, and Car Mode on a mounted iPhone.
struct CarHubView: View {
    let viewModel: CarHubViewModel
    let playback: PlaybackController
    let connection: CarConnection
    let isPro: Bool
    let revision: Int
    let onStartCarMode: (MediaItem?) -> Void
    let onUpgrade: () -> Void
    let onBrowse: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    dashboard
                    carPlayCard
                    airPlayCard
                    carModeCard
                    Label(
                        "For passengers, or while parked. Never watch video while driving.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(Spacing.md)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(.roadCanvas)
            .navigationTitle("Cast to Car")
        }
        .task(id: revision) { viewModel.load() }
    }

    // MARK: Dashboard

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
        return String(appLocalized: "Connect CarPlay or AirPlay")
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
