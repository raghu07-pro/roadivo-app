import SwiftUI

/// Add a Source: a link or M3U text (typed, pasted or scanned), or a media server. `Help` is
/// injected by the app, so this feature doesn't depend on Settings.
struct AddSourceView<Help: View>: View {
    @State var viewModel: AddSourceViewModel
    let onFinished: () -> Void
    @ViewBuilder let help: () -> Help

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isScanning = false
    @FocusState private var focusedField: Field?

    private enum Field { case link }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    intro
                    playlistCard
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
                    servers
                    footer
                }
                .padding(Spacing.md)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
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

    private var intro: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Paste a subscription link or M3U content, or tap the scan icon to read a QR code.")
                .font(Typography.secondary)
                .foregroundStyle(.roadMuted)
            NavigationLink {
                WhatIsASourceView()
            } label: {
                Text("What is a source?").font(Typography.secondary.weight(.semibold))
            }
            .accessibilityIdentifier("addSource.whatIsSource")
        }
    }

    /// The link or M3U text, with the scan button inside; outlined in the accent while editing.
    private var playlistCard: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
        return VStack(spacing: 0) {
            TextField("Paste a link or a whole M3U list", text: $viewModel.input, axis: .vertical)
                .lineLimit(4...8)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .link)
                .padding(.top, Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("addSource.link")
            HStack {
                Spacer()
                Button {
                    focusedField = nil
                    isScanning = true
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.roadAccent)
                        .frame(width: 44, height: 44)
                        .background(Color.roadBrand.opacity(0.14), in: Circle())
                }
                .accessibilityLabel(Text("Scan QR code"))
                .accessibilityIdentifier("addSource.scan")
            }
            .padding(.bottom, Spacing.sm)
        }
        .padding(.horizontal, Spacing.md)
        .background(.roadSurface, in: shape)
        .overlay {
            shape.strokeBorder(
                focusedField == nil ? AnyShapeStyle(Color.primary.opacity(0.06)) : AnyShapeStyle(.roadBrandGradient),
                lineWidth: focusedField == nil ? 1 : 1.5
            )
        }
        .animation(.snappy(duration: 0.2), value: focusedField)
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

    /// Two cards a row, one at accessibility text sizes so server names never cut off.
    private var serverColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 150), spacing: Spacing.sm)]
    }

    private var servers: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                VStack { Divider() }
                Text("Or connect a media server")
                    .font(Typography.caption)
                    .foregroundStyle(.roadMuted)
                    .fixedSize()
                VStack { Divider() }
            }
            LazyVGrid(columns: serverColumns, spacing: Spacing.sm) {
                ForEach(MediaServerKind.allCases) { kind in
                    NavigationLink(value: kind) { ServerCard(kind: kind) }
                        .buttonStyle(PressableStyle())
                        .accessibilityIdentifier("addSource.server.\(kind.rawValue)")
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: Spacing.sm) {
            NavigationLink {
                help()
            } label: {
                Label("Get Help", systemImage: "bubble.left.and.text.bubble.right.fill")
                    .font(Typography.cardTitle)
            }
            .accessibilityIdentifier("addSource.help")
            Text("Roadivo doesn't provide, host or endorse any content. Add only sources you have the right to use.")
                .font(Typography.caption)
                .foregroundStyle(.roadMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
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
