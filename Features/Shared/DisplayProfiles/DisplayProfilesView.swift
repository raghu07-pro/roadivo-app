import SwiftUI

/// Settings › Car & Display Profiles: This iPhone's settings, each saved car or display, and saving
/// the one connected now (DECISIONS 110).
struct DisplayProfilesView: View {
    let viewModel: DisplayProfilesViewModel
    let isPro: Bool

    /// A profile just saved for the connected screen, opened straight away.
    @State private var created: UUID?

    var body: some View {
        List {
            if let receiver = viewModel.unsavedReceiver {
                Section {
                    Button {
                        created = viewModel.saveCurrentReceiver()
                    } label: {
                        // In the accent with a +, so it reads as the action it is.
                        HStack {
                            Label {
                                Text("Save a Profile for \(receiver.name)").foregroundStyle(.roadAccent)
                            } icon: {
                                IconTile(systemImage: receiver.kind.symbol)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.roadAccent)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityIdentifier("profiles.saveCurrent")
                }
            }
            Section {
                NavigationLink(value: DisplayProfileRoute(id: viewModel.thisIPhone.id)) {
                    row(
                        title: Text("This iPhone"),
                        detail: Text("Used when no saved car or display is connected."),
                        symbol: "iphone",
                        isActive: viewModel.activeID == viewModel.thisIPhone.id
                    )
                }
                .accessibilityIdentifier("profiles.thisIPhone")
            }
            // No empty "Cars & Displays" header before the first is saved.
            if !viewModel.saved.isEmpty {
                savedSection
            }
            // A plain row, not a footer: the list didn't re-measure this footer at larger text sizes,
            // so the Dynamic Type audit found it clipped.
            Section {
                explanation
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: Spacing.md, bottom: 0, trailing: Spacing.md))
            }
        }
        .scrollContentBackground(.hidden)
        .background(.roadCanvas)
        .clearsBottomAccessory()
        .navigationTitle("Car & Display Profiles")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: DisplayProfileRoute.self) { route in
            editor(route.id)
        }
        .navigationDestination(item: $created) { id in
            editor(id)
        }
    }

    private var savedSection: some View {
        Section {
            ForEach(viewModel.saved) { profile in
                NavigationLink(value: DisplayProfileRoute(id: profile.id)) {
                    row(
                        title: Text(profile.displayName),
                        detail: Text(app: profile.receiver?.kind.title ?? "AirPlay"),
                        symbol: profile.receiver?.kind.symbol ?? "tv",
                        isActive: viewModel.activeID == profile.id
                    )
                }
                .accessibilityIdentifier("profiles.row.\(profile.displayName)")
                .swipeActions {
                    Button(role: .destructive) {
                        viewModel.delete(profile.id)
                    } label: {
                        DestructiveLabel(title: "Delete", systemImage: "trash")
                    }
                }
            }
        } header: {
            SectionHeader("Cars & Displays")
        }
    }

    private var explanation: some View {
        SectionFooter("""
        Connect to a car or an AirPlay display to save a profile for it. Roadivo switches to it \
        whenever that screen connects.
        """)
    }

    @ViewBuilder
    private func editor(_ id: UUID) -> some View {
        if let editor = viewModel.editor(for: id) {
            DisplayProfileEditorView(viewModel: editor, isPro: isPro)
        }
    }

    private func row(title: Text, detail: Text, symbol: String, isActive: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            IconTile(systemImage: symbol)
            // The badge sits under the name, so large text never squeezes it off the row.
            VStack(alignment: .leading, spacing: 2) {
                title.foregroundStyle(Color.primary)
                detail.font(Typography.caption).foregroundStyle(.roadMuted)
                if isActive {
                    // Not a Label: in a list row it gets the row's wide icon column.
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "checkmark.circle.fill").accessibilityHidden(true)
                        Text("In Use")
                    }
                    .font(Typography.caption)
                    .foregroundStyle(.roadAccent)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// A profile's own screen, from Settings.
struct DisplayProfileRoute: Hashable {
    let id: UUID
}
