import SwiftUI

struct ServerLoginView: View {
    @State var viewModel: ServerLoginViewModel
    let onFinished: () -> Void

    @FocusState private var field: Field?

    private enum Field { case address, username, password, name }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label {
                    Text(intro)
                } icon: {
                    Image(systemName: viewModel.kind.symbol).foregroundStyle(ServerChip.tint(viewModel.kind))
                }
                .font(Typography.secondary)
                .foregroundStyle(.secondary)

                group(title: "Server address") {
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
                group(title: "Username") {
                    TextField("Username", text: $viewModel.username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($field, equals: .username)
                        .submitLabel(.next)
                        .onSubmit { field = .password }
                        .accessibilityIdentifier("server.username")
                }
                group(title: "Password") {
                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.password)
                        .focused($field, equals: .password)
                        .submitLabel(.next)
                        .onSubmit { field = .name }
                        .accessibilityIdentifier("server.password")
                }
                group(title: "Name (optional)") {
                    TextField("e.g. Living Room", text: $viewModel.name)
                        .focused($field, equals: .name)
                        .submitLabel(.go)
                        .onSubmit(connect)
                }

                if let message = viewModel.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(Typography.secondary)
                        .foregroundStyle(.roadLive)
                        .accessibilityIdentifier("server.error")
                }

                PrimaryButton(title: "Connect", systemImage: "link", isLoading: viewModel.isConnecting, action: connect)
                    .disabled(!viewModel.canConnect)
                    .accessibilityIdentifier("server.connect")

                Text(footnote)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(Spacing.md)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(.roadCanvas)
        .navigationTitle(viewModel.kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(viewModel.isConnecting)
    }

    private var intro: LocalizedStringKey {
        switch viewModel.kind {
        case .xtream: "Enter the server, username and password your IPTV provider gave you."
        case .jellyfin, .emby: "Sign in to your own server to watch its movies and shows."
        }
    }

    private var footnote: LocalizedStringKey {
        switch viewModel.kind {
        case .xtream: "Your login is kept in this iPhone's Keychain and sent only to that server."
        case .jellyfin, .emby:
            "Your password is used once to sign in. Roadivo keeps only the server's access token, in the Keychain."
        }
    }

    private func group(title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).font(Typography.caption).foregroundStyle(.secondary)
            content()
                .padding(.horizontal, Spacing.sm)
                .frame(minHeight: 48)
                .background(.roadSurface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
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
