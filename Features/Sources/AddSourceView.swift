import SwiftUI
import UniformTypeIdentifiers

/// "Add a Source": one box for a link or M3U text (pasted or scanned), an M3U
/// file, or a media server. `Help` is the Help & FAQ screen, injected by the
/// app so this feature doesn't depend on Settings.
struct AddSourceView<Help: View>: View {
    @State var viewModel: AddSourceViewModel
    let onFinished: () -> Void
    @ViewBuilder let help: () -> Help

    @Environment(\.dismiss) private var dismiss
    @State private var isPickingPlaylist = false
    @State private var isScanning = false
    @FocusState private var focusedField: Field?

    private enum Field { case name, link }

    private static var playlistTypes: [UTType] {
        [.m3uPlaylist, .plainText, UTType(filenameExtension: "m3u8")].compactMap(\.self)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    intro
                    nameField
                    inputBox
                    if viewModel.showsUnusableWarning {
                        unusableCard
                    }
                    if let message = viewModel.errorMessage {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(Typography.secondary)
                            .foregroundStyle(.roadLive)
                            .accessibilityIdentifier("addSource.error")
                    }
                    Button {
                        isPickingPlaylist = true
                    } label: {
                        Label("Import an M3U File", systemImage: "doc.badge.plus")
                            .font(Typography.cardTitle)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("addSource.file")

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
                    Button { dismiss() } label: { Label("Close", systemImage: "xmark") }
                        .accessibilityIdentifier("addSource.close")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isWorking {
                        ProgressView()
                    } else {
                        Button("Add", action: submit)
                            .fontWeight(.semibold)
                            .disabled(!viewModel.canSubmit)
                            .accessibilityIdentifier("addSource.submit")
                    }
                }
            }
            .navigationDestination(for: MediaServerKind.self) { kind in
                ServerLoginView(viewModel: viewModel.makeServerLogin(kind), onFinished: onFinished)
            }
            .fileImporter(isPresented: $isPickingPlaylist, allowedContentTypes: Self.playlistTypes) { result in
                Task {
                    if await viewModel.importPlaylistFile(result) {
                        onFinished()
                    }
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
                .foregroundStyle(.secondary)
            NavigationLink {
                help()
            } label: {
                Text("What is a source?").font(Typography.secondary.weight(.semibold))
            }
            .accessibilityIdentifier("addSource.whatIsSource")
        }
    }

    private var nameField: some View {
        TextField("Name (optional)", text: $viewModel.name)
            .textInputAutocapitalization(.words)
            .focused($focusedField, equals: .name)
            .submitLabel(.next)
            .onSubmit { focusedField = .link }
            .padding(.horizontal, Spacing.sm)
            .frame(minHeight: 48)
            .background(.roadSurface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .accessibilityIdentifier("addSource.name")
    }

    private var inputBox: some View {
        VStack(alignment: .trailing, spacing: Spacing.xs) {
            TextField("Paste a link or a whole M3U list", text: $viewModel.input, axis: .vertical)
                .lineLimit(4...8)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .link)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("addSource.link")
            HStack(spacing: Spacing.xs) {
                PasteButton(payloadType: String.self) { strings in
                    if let first = strings.first {
                        viewModel.input = first
                    }
                }
                .labelStyle(.iconOnly)
                .buttonBorderShape(.capsule)
                Button {
                    focusedField = nil
                    isScanning = true
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text("Scan QR code"))
                .accessibilityIdentifier("addSource.scan")
            }
        }
        .padding(Spacing.sm)
        .background(.roadSurface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    private var unusableCard: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("No usable link found").font(Typography.cardTitle)
                Text("Supports M3U/M3U8 links, M3U files and pasted M3U content.")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("addSource.unusable")
    }

    private var servers: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                VStack { Divider() }
                Text("Or connect a media server")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                VStack { Divider() }
            }
            .padding(.top, Spacing.xs)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.sm) { chips }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) { chips }
                }
            }
        }
    }

    private var chips: some View {
        ForEach(MediaServerKind.allCases) { kind in
            NavigationLink(value: kind) { ServerChip(kind: kind) }
                .buttonStyle(PressableStyle())
                .accessibilityIdentifier("addSource.server.\(kind.rawValue)")
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
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xs)
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
