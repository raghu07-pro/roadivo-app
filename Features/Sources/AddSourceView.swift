import SwiftUI

/// Add a Source, PlayCarTV's own way (DECISIONS 166): first how the channels come, a playlist or a media server, then
/// only that way's controls. `Help` is injected by the app, so this feature doesn't depend on Settings.
struct AddSourceView<Help: View>: View {
    @State var viewModel: AddSourceViewModel
    let onFinished: () -> Void
    @ViewBuilder let help: () -> Help

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isScanning = false
    @State private var way = Way.playlist
    @FocusState private var focusedField: Field?

    /// The two ways in: a playlist (link, text or QR code) or signing in to a media server.
    private enum Way { case playlist, server }
    private enum Field { case link }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text("How do you get your channels?")
                        .font(Typography.screenTitle)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    ways
                    switch way {
                    case .playlist: playlist
                    case .server: servers
                    }
                    disclaimer
                }
                .padding(Spacing.md)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
                .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: way)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(.roadCanvas)
            .navigationTitle("Add a Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // Not while adding: the download would finish later and slip past the free limit.
                    Button { dismiss() } label: { Label("Close", systemImage: "xmark") }
                        .disabled(viewModel.isWorking)
                        .accessibilityIdentifier("addSource.close")
                }
                ToolbarItem(placement: .primaryAction) {
                    // Behind a ?, as the app's other explanations (DECISIONS 128).
                    NavigationLink {
                        WhatIsASourceView(help: help)
                    } label: {
                        Label("What is a source?", systemImage: "questionmark")
                    }
                    .accessibilityIdentifier("addSource.whatIsSource")
                }
            }
            .toolbar {
                // Return adds a line in the box, so the keyboard needs its own way down to Add Source.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .navigationDestination(for: MediaServerKind.self) { kind in
                if kind == .plex {
                    PlexLoginView(viewModel: viewModel.makePlexLogin(), onFinished: onFinished)
                } else {
                    ServerLoginView(viewModel: viewModel.makeServerLogin(kind), onFinished: onFinished)
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isWorking)
        .fullScreenCover(isPresented: $isScanning) {
            QRScannerSheet { text in viewModel.useScanned(text) }
        }
    }

    // MARK: - The two ways in

    /// Side by side; stacked once larger text needs the width.
    private var ways: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Spacing.sm) { wayTiles }
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: Spacing.sm) { wayTiles }
        }
    }

    @ViewBuilder private var wayTiles: some View {
        wayTile(.playlist, symbol: "link", title: "Playlist", detail: "A link, M3U text or QR code")
        wayTile(.server, symbol: "server.rack", title: "Media servers", detail: "Jellyfin, Emby, Plex or Xtream")
    }

    /// The chosen way is outlined in the theme's gradient, its icon filled.
    private func wayTile(
        _ choice: Way,
        symbol: String,
        title: LocalizedStringKey,
        detail: LocalizedStringKey
    ) -> some View {
        let isChosen = way == choice
        let shape = RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
        return Button {
            focusedField = nil
            way = choice
        } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                IconTile(systemImage: symbol, style: isChosen ? .filled : .soft, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.sign)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(Typography.caption)
                        .foregroundStyle(.roadMuted)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.roadSurface, in: shape)
            .overlay {
                shape.strokeBorder(
                    isChosen ? AnyShapeStyle(.roadBrandGradient) : AnyShapeStyle(Color.primary.opacity(0.06)),
                    lineWidth: isChosen ? 2 : 1
                )
            }
            .contentShape(shape)
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isChosen ? .isSelected : [])
        .accessibilityIdentifier(choice == .playlist ? "addSource.way.playlist" : "addSource.way.server")
    }

    // MARK: - Playlist

    private var playlist: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            linkCard
            readiness
            if viewModel.showsUnusableWarning {
                unusableCard
            }
            if let message = viewModel.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(Typography.secondary)
                    .foregroundStyle(.roadLive)
                    .accessibilityIdentifier("addSource.error")
            }
            PrimaryButton(
                title: "Add Source",
                systemImage: "plus",
                isLoading: viewModel.isWorking,
                action: submit
            )
            .disabled(!viewModel.canSubmit)
            .accessibilityIdentifier("addSource.submit")
            .padding(.top, Spacing.xs)
        }
    }

    private var disclaimer: some View {
        Text("PlayCarTV doesn't provide, host or endorse any content. Add only sources you have the right to use.")
            .font(Typography.caption)
            .foregroundStyle(.roadMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    /// The link or M3U text, with Scan under it (no Paste button: DECISIONS 73); outlined in the accent while editing.
    private var linkCard: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            TextField("Paste a link or a whole M3U list", text: $viewModel.input, axis: .vertical)
                .lineLimit(3...8)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .link)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("addSource.link")
            HStack(spacing: Spacing.xs) {
                Button {
                    focusedField = nil
                    isScanning = true
                } label: {
                    Label("Scan QR code", systemImage: "qrcode.viewfinder")
                        .font(Typography.cardTitle)
                        .foregroundStyle(.roadAccent)
                        .padding(.horizontal, Spacing.sm)
                        .frame(minHeight: 44)
                        .background(Color.roadBrand.opacity(0.14), in: Capsule())
                        .contentShape(Capsule())
                }
                .accessibilityIdentifier("addSource.scan")
                Spacer(minLength: 0)
            }
        }
        .padding(Spacing.md)
        .background(.roadSurface, in: shape)
        .overlay {
            shape.strokeBorder(
                focusedField == nil ? AnyShapeStyle(Color.primary.opacity(0.06)) : AnyShapeStyle(.roadBrandGradient),
                lineWidth: focusedField == nil ? 1 : 1.5
            )
        }
        .animation(.snappy(duration: 0.2), value: focusedField)
    }

    /// What Add Source will add, before it's tapped: a link's site only, as the full link can hold a login.
    @ViewBuilder private var readiness: some View {
        switch viewModel.parsedInput {
        case let .link(url):
            ready(Text("Ready to add: \(url.host() ?? url.absoluteString)"))
        case .content:
            ready(Text("M3U list ready to add"))
        case .empty, .unusable:
            EmptyView()
        }
    }

    private func ready(_ text: Text) -> some View {
        Label {
            text
                .lineLimit(1)
                .truncationMode(.middle)
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.roadAccent)
        }
        .font(Typography.secondary.weight(.semibold))
        .accessibilityIdentifier("addSource.ready")
    }

    private var unusableCard: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("No usable link found").font(Typography.cardTitle)
                Text("Supports M3U/M3U8 links and pasted M3U content.")
                    .font(Typography.caption)
                    .foregroundStyle(.roadMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("addSource.unusable")
    }

    // MARK: - Media servers

    /// One list, as iOS Settings': each server's mark and name (owner's choice), then a sign-in.
    private var servers: some View {
        VStack(spacing: 0) {
            ForEach(Array(MediaServerKind.allCases.enumerated()), id: \.element) { index, kind in
                if index > 0 {
                    Divider().padding(.leading, ServerRow.dividerInset)
                }
                // VoiceOver also hears what signing in takes.
                NavigationLink(value: kind) { ServerRow(kind: kind) }
                    .buttonStyle(PressableStyle())
                    .accessibilityHint(Text(app: kind.subtitle))
                    .accessibilityIdentifier("addSource.server.\(kind.rawValue)")
            }
        }
        .cardStyle(padding: 0)
    }

    private func submit() {
        focusedField = nil
        Task {
            if await viewModel.submit() {
                onFinished()
            }
        }
    }
}
