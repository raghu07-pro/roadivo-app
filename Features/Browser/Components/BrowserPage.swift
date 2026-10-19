import SwiftUI

/// An open page: the page under a thin loading line, and Roadivo's bar at the bottom with back, forward,
/// the address and reload, plus "Play in Roadivo" when the page has a video Roadivo can take.
struct BrowserPage: View {
    let viewModel: BrowserViewModel
    let onPlay: (MediaItem) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        WebView(controller: viewModel.web)
            .accessibilityIdentifier("browser.web")
            .overlay(alignment: .top) { loadingLine }
            // The bar first, then the mini player's space, so the bar sits just above the mini player.
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            .clearsBottomAccessory()
            .animation(reduceMotion ? nil : .snappy, value: viewModel.foundVideo)
    }

    @ViewBuilder private var loadingLine: some View {
        if let page = viewModel.page, page.isLoading {
            ProgressView(value: max(page.progress, 0.05))
                .progressViewStyle(.linear)
                .tint(.roadAccent)
                .accessibilityLabel(Text("Loading"))
        }
    }

    private var bottomBar: some View {
        VStack(spacing: Spacing.sm) {
            if viewModel.foundVideo != nil {
                FoundVideoBanner(onPlay: play, onDismiss: viewModel.dismissVideo)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
            HStack(spacing: Spacing.xxs) {
                barButton(
                    "chevron.backward",
                    label: "Back",
                    isEnabled: viewModel.page?.canGoBack == true,
                    identifier: "browser.back",
                    action: viewModel.goBack
                )
                barButton(
                    "chevron.forward",
                    label: "Forward",
                    isEnabled: viewModel.page?.canGoForward == true,
                    identifier: "browser.forward",
                    action: viewModel.goForward
                )
                AddressField(viewModel: viewModel, isOnStartPage: false)
                let isLoading = viewModel.page?.isLoading == true
                barButton(
                    isLoading ? "xmark" : "arrow.clockwise",
                    label: isLoading ? "Stop" : "Reload",
                    isEnabled: true,
                    identifier: "browser.reload",
                    action: viewModel.reloadOrStop
                )
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(.bar)
    }

    private func barButton(
        _ symbol: String,
        label: LocalizedStringKey,
        isEnabled: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .disabled(!isEnabled)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(identifier)
    }

    private func play() {
        if let item = viewModel.takeVideo() {
            onPlay(item)
        }
    }
}

/// "Video on this page": plays it in Roadivo's player, where Car Mode, Picture in Picture and AirPlay work.
private struct FoundVideoBanner: View {
    let onPlay: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                IconTile(systemImage: "play.rectangle.fill", style: .soft, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Video on this page")
                        .font(Typography.cardTitle)
                    Text("Play it in Roadivo for Car Mode, Picture in Picture and AirPlay.")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text("Close"))
                .accessibilityIdentifier("browser.video.close")
            }
            PrimaryButton(title: "Play in Roadivo", systemImage: "play.fill", action: onPlay)
                .accessibilityIdentifier("browser.video.play")
        }
        .padding(Spacing.sm)
        .background(.roadSurface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("browser.video")
    }
}
