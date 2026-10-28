import SwiftUI

/// Sign in to Jellyfin, Emby or Xtream: the service's badge, one grouped form (address and login)
/// and Connect. Plex has its own code-based screen.
struct ServerLoginView: View {
    @State var viewModel: ServerLoginViewModel
    let onFinished: () -> Void

    @FocusState private var field: Field?
    @State private var showsPassword = false

    private enum Field { case address, username, password }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                form
                if let message = viewModel.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(Typography.secondary)
                        .foregroundStyle(.roadLive)
                        .accessibilityIdentifier("server.error")
                }
                PrimaryButton(title: "Connect", systemImage: "link", isLoading: viewModel.isConnecting, action: connect)
                    .disabled(!viewModel.canConnect)
                    .accessibilityIdentifier("server.connect")
                Label {
                    Text(footnote)
                } icon: {
                    Image(systemName: "lock.fill")
                }
                .font(Typography.caption)
                .foregroundStyle(.roadMuted)
            }
            .padding(Spacing.md)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(.roadCanvas)
        .navigationTitle(Text("Connect to \(viewModel.kind.title)"))
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(viewModel.isConnecting)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            ServerBadge(kind: viewModel.kind, size: 52)
            Text(intro)
                .font(Typography.secondary)
                .foregroundStyle(.roadMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var form: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
        return VStack(spacing: 0) {
            row("Server address") {
                TextField(viewModel.kind.addressPlaceholder, text: $viewModel.address)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($field, equals: .address)
                    .submitLabel(.next)
                    .onSubmit { field = .username }
                    .accessibilityIdentifier("server.address")
            }
            Divider()
            row("Username") {
                TextField("Required", text: $viewModel.username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($field, equals: .username)
                    .submitLabel(.next)
                    .onSubmit { field = .password }
                    .accessibilityIdentifier("server.username")
            }
            Divider()
            row("Password") {
                HStack(spacing: Spacing.xs) {
                    Group {
                        if showsPassword {
                            TextField(passwordPrompt, text: $viewModel.password)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            SecureField(passwordPrompt, text: $viewModel.password)
                        }
                    }
                    .textContentType(.password)
                    .focused($field, equals: .password)
                    .submitLabel(.go)
                    .onSubmit(connect)
                    .accessibilityIdentifier("server.password")
                    Button {
                        showsPassword.toggle()
                    } label: {
                        Image(systemName: showsPassword ? "eye.slash" : "eye")
                            .foregroundStyle(.roadMuted)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(showsPassword ? Text("Hide password") : Text("Show password"))
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .background(.roadSurface, in: shape)
        .overlay {
            shape.strokeBorder(
                field == nil ? AnyShapeStyle(Color.primary.opacity(0.06)) : AnyShapeStyle(.roadBrandGradient),
                lineWidth: field == nil ? 1 : 1.5
            )
        }
        .animation(.snappy(duration: 0.2), value: field)
    }

    /// A field with its label above it, so long labels and large text never squeeze the field.
    private func row(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Typography.caption)
                .foregroundStyle(.roadMuted)
            content()
                .frame(minHeight: 36)
        }
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var passwordPrompt: LocalizedStringKey {
        viewModel.kind == .xtream ? "Required" : "Optional"
    }

    private var intro: LocalizedStringKey {
        switch viewModel.kind {
        case .xtream: "Enter the server, username and password your IPTV provider gave you."
        case .jellyfin, .emby, .plex: "Sign in to your own server to watch its movies and shows."
        }
    }

    private var footnote: LocalizedStringKey {
        switch viewModel.kind {
        case .xtream: "Your login is kept in this iPhone's Keychain and sent only to that server."
        case .jellyfin, .emby, .plex:
            "Your password is used once to sign in. PlayCarTV keeps only the server's access token, in the Keychain."
        }
    }

    private func connect() {
        field = nil
        Task {
            if await viewModel.connect() {
                onFinished()
            }
        }
    }
}
