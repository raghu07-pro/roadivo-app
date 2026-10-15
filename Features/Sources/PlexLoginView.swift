import SwiftUI
import UIKit

/// Connect to Plex: a code to enter at plex.tv/link, then (with several servers) a choice of
/// server. Waits on its own; leaving the screen stops it.
struct PlexLoginView: View {
    @State var viewModel: PlexLoginViewModel
    let onFinished: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var copied = false
    @State private var attempt = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack(alignment: .center, spacing: Spacing.md) {
                    ServerBadge(kind: .plex, size: 52)
                    Text("Sign in with your Plex account to watch your servers' movies and shows.")
                        .font(Typography.secondary)
                        .foregroundStyle(.roadMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                content
                Label {
                    Text(
                        "Personal and shared Plex servers only. Plex's own Live TV and Movies & Shows aren't included."
                    )
                } icon: {
                    Image(systemName: "info.circle")
                }
                .font(Typography.caption)
                .foregroundStyle(.roadMuted)
            }
            .padding(Spacing.md)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(.roadCanvas)
        .navigationTitle(Text("Connect to \(MediaServerKind.plex.title)"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: attempt) {
            if await viewModel.start() {
                onFinished()
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.step {
        case .gettingCode:
            status("Getting a code…")
        case let .waiting(pin):
            codeCard(pin.code)
        case let .choosing(servers):
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let message = viewModel.errorMessage {
                    errorLabel(message)
                }
                serverList(servers)
            }
        case let .adding(name):
            status("Adding \(name)…")
        case let .failed(message):
            VStack(alignment: .leading, spacing: Spacing.md) {
                errorLabel(message)
                PrimaryButton(title: "Get a New Code", systemImage: "arrow.clockwise") { attempt += 1 }
                    .accessibilityIdentifier("plex.retry")
            }
        }
    }

    private func errorLabel(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(Typography.secondary)
            .foregroundStyle(.roadLive)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("plex.error")
    }

    private func codeCard(_ code: String) -> some View {
        VStack(spacing: Spacing.md) {
            Text(code)
                .font(.largeTitle.weight(.heavy).monospaced())
                .tracking(10)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .accessibilityLabel(Text(code.map(String.init).joined(separator: " ")))
                .accessibilityIdentifier("plex.code")
            Text("Enter this code at plex.tv/link, then come back to Roadivo.")
                .font(Typography.secondary)
                .foregroundStyle(.roadMuted)
                .multilineTextAlignment(.center)
            PrimaryButton(title: "Open plex.tv/link", systemImage: "safari") {
                if let page = PlexClient.linkPage {
                    openURL(page)
                }
            }
            .accessibilityIdentifier("plex.open")
            Button {
                UIPasteboard.general.string = code
                copied = true
            } label: {
                Label(copied ? "Copied" : "Copy Code", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .font(Typography.secondary.weight(.semibold))
                    .foregroundStyle(.roadAccent)
                    .frame(minHeight: 44)
            }
            .accessibilityIdentifier("plex.copy")
            HStack(spacing: Spacing.xs) {
                ProgressView()
                Text("Waiting for Plex…")
                    .font(Typography.caption)
                    .foregroundStyle(.roadMuted)
            }
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: Spacing.lg)
    }

    private func serverList(_ servers: [PlexServer]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Choose a Server")
                .font(Typography.cardTitle)
                .accessibilityAddTraits(.isHeader)
            ForEach(servers) { server in
                Button {
                    Task {
                        if await viewModel.add(server) {
                            onFinished()
                        }
                    }
                } label: {
                    HStack(spacing: Spacing.sm) {
                        IconTile(systemImage: "server.rack", style: .soft, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(server.name)
                                .font(Typography.cardTitle)
                                .foregroundStyle(.primary)
                            Text(server.isOwned ? "Your server" : "Shared with you")
                                .font(Typography.caption)
                                .foregroundStyle(.roadMuted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle(padding: Spacing.sm)
                }
                .buttonStyle(PressableStyle())
                .accessibilityIdentifier("plex.server.\(server.name)")
            }
        }
    }

    private func status(_ text: LocalizedStringKey) -> some View {
        HStack(spacing: Spacing.sm) {
            ProgressView()
            Text(text)
                .font(Typography.secondary)
                .foregroundStyle(.roadMuted)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: Spacing.lg)
        .accessibilityElement(children: .combine)
    }
}
