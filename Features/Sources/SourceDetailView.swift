import SwiftUI
import UniformTypeIdentifiers

/// A source's channels, pushed from Manage Sources: one group at a time under its chips, with
/// Refresh and a More menu (Rename, Copy Link, Delete).
struct SourceDetailView: View {
    @State var viewModel: SourceDetailViewModel
    let revision: Int
    let onPlay: (MediaItem, [MediaItem]) -> Void
    let onFavoriteChanged: (UUID, Bool) -> Void
    let onLibraryChanged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRenaming = false
    @State private var newName = ""
    @State private var isConfirmingDelete = false
    @State private var showsCopied = false
    @State private var showsHealth = false

    var body: some View {
        @Bindable var viewModel = viewModel
        ScrollViewReader { proxy in
            ScrollView {
                ChannelGrid(
                    items: viewModel.visible,
                    onPlay: { onPlay($0, viewModel.visible) },
                    onToggleFavorite: toggleFavorite
                )
                .padding(.vertical, Spacing.md)
                .id(viewModel.group)
            }
            .onChange(of: viewModel.group) { proxy.scrollTo(viewModel.group, anchor: .top) }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if viewModel.showsGroups {
                CategoryChips(
                    chips: viewModel.groups.map { .init(id: $0, title: $0) },
                    selection: $viewModel.group,
                    identifier: "group"
                )
                .padding(.bottom, Spacing.xxs)
                .background(.roadCanvas)
            }
        }
        .overlay {
            if viewModel.isLoaded, viewModel.items.isEmpty {
                ContentUnavailableView("No channels", systemImage: "play.square.stack")
            }
        }
        .overlay(alignment: .bottom) {
            if showsCopied {
                Label("Link copied", systemImage: "checkmark.circle.fill")
                    .font(Typography.secondary.weight(.semibold))
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, Spacing.lg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityIdentifier("source.copied")
            }
        }
        .background(.roadCanvas)
        .clearsBottomAccessory()
        .navigationTitle(viewModel.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .navigationDestination(isPresented: $showsHealth) {
            SourceHealthView(viewModel: viewModel.health(), onPlay: onPlay)
        }
        .alert("Rename Source", isPresented: $isRenaming) {
            TextField("Name", text: $newName)
            Button("Save") {
                if viewModel.rename(to: newName) {
                    onLibraryChanged()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert(Text("Delete \(viewModel.name)?"), isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.delete() {
                        onLibraryChanged()
                        dismiss()
                    }
                }
            }
            .accessibilityIdentifier("source.confirmDelete")
            Button("Cancel", role: .cancel) {}
        } message: {
            if viewModel.kind == .localVideos {
                Text("All your imported videos are removed from PlayCarTV. The originals stay in Photos or Files.")
            } else {
                Text("""
                Its channels, favorites and watch history are removed from PlayCarTV. To add it again, you'll need \
                its link or login.
                """)
            }
        }
        .alert(
            "Couldn't update the source",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: {
                    if !$0 {
                        viewModel.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task(id: revision) { viewModel.load() }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if viewModel.canRefresh {
                if viewModel.isRefreshing {
                    ProgressView()
                        .accessibilityLabel(Text("Refreshing"))
                } else {
                    Button {
                        Task {
                            if await viewModel.refresh() {
                                onLibraryChanged()
                            }
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .accessibilityIdentifier("source.refresh")
                }
            }
            Menu {
                Button {
                    newName = viewModel.name
                    isRenaming = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                if viewModel.hasHealthReport {
                    Button {
                        showsHealth = true
                    } label: {
                        Label("Source Health", systemImage: "stethoscope")
                    }
                    .accessibilityIdentifier("source.health")
                }
                if viewModel.canCopyLink {
                    Button(action: copyLink) {
                        Label("Copy Link", systemImage: "doc.on.doc")
                    }
                    .accessibilityIdentifier("source.copyLink")
                }
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    DestructiveLabel(title: "Delete Source", systemImage: "trash")
                }
                .accessibilityIdentifier("source.deleteSource")
            } label: {
                Label("More", systemImage: "ellipsis")
            }
            .accessibilityIdentifier("source.more")
        }
    }

    private func toggleFavorite(_ item: MediaItem) {
        if let isFavorite = viewModel.toggleFavorite(item) {
            onFavoriteChanged(item.id, isFavorite)
        }
    }

    /// The link usually holds the provider's login: kept off other devices and cleared after 10 minutes.
    private func copyLink() {
        guard let link = viewModel.link() else { return }
        UIPasteboard.general.setItems(
            [[UTType.utf8PlainText.identifier: link]],
            options: [.localOnly: true, .expirationDate: Date.now.addingTimeInterval(600)]
        )
        AccessibilityNotification.Announcement(String(appLocalized: "Link copied")).post()
        withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) { showsCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(2)) // Only delays hiding the note.
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { showsCopied = false }
        }
    }
}
