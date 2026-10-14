import SwiftUI

/// "Unlock Roadivo Pro". Shown once after onboarding (closable) and whenever a
/// free user reaches a Pro feature. Always dark, like the night-road hero.
struct PaywallView: View {
    @State var viewModel: PaywallViewModel
    let onClose: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var isShowingPrivacy = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            background
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    header
                    features
                    plans
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, 60)
                .padding(.bottom, Spacing.lg)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            closeButton
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .task { await viewModel.load() }
        // Pro can arrive while this is open (Ask to Buy approved, or entitlements loading late).
        .onChange(of: viewModel.isPro) { _, isPro in
            if isPro {
                onClose()
            }
        }
        .onChange(of: viewModel.message) { _, message in
            if let message {
                AccessibilityNotification.Announcement(message).post()
            }
        }
        .sheet(isPresented: $isShowingPrivacy) {
            NavigationStack {
                PrivacyPolicyView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { isShowingPrivacy = false }
                        }
                    }
            }
        }
        .accessibilityElement(children: .contain)
    }

    #if DEBUG
        private static let developerNote = "Developer note: prices come from StoreKit/Roadivo.storekit only when "
            + "Xcode launches the Roadivo scheme. Elsewhere they come from App Store Connect."
    #endif

    /// "Unlock Roadivo Pro" as one translatable sentence, with the brand name
    /// picked out in the theme's accent wherever the translation puts it.
    private static var title: AttributedString {
        var title = AttributedString(appLocalized: "Unlock Roadivo Pro")
        if let range = title.range(of: "Roadivo") {
            title[range].foregroundColor = Color.roadAccent
        }
        return title
    }

    private var background: some View {
        ZStack(alignment: .top) {
            Color.roadAsphalt
            // Sky only: the road would run behind the title and tiles.
            RoadScene(time: .night, horizon: 0.96)
                .frame(height: 230)
                .overlay(LinearGradient(colors: [.clear, Color.roadAsphalt], startPoint: .center, endPoint: .bottom))
        }
        .ignoresSafeArea()
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.body.weight(.bold))
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.14), in: Circle())
        }
        .accessibilityLabel(Text("Close"))
        .accessibilityIdentifier("paywall.close")
        .padding(Spacing.md)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(Self.title)
                .font(Typography.hero)
                .accessibilityAddTraits(.isHeader)
            Text(app: viewModel.reason.subtitle)
                .font(Typography.body)
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    /// A 2×2 grid, so the three plans and the buy button fit one iPhone screen.
    private var features: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.sm), GridItem(.flexible())], spacing: Spacing.sm) {
            ForEach(PaywallFeature.all) { feature in
                HStack(spacing: Spacing.xs) {
                    Image(systemName: feature.symbol)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.roadAccent)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(app: feature.title)
                            .font(Typography.cardTitle)
                        Text(app: feature.detail)
                            .font(Typography.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .frame(minHeight: 48)
                .background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// The three plans always show: shimmering while prices load, and without prices (not
    /// selectable) if the App Store can't be reached.
    @ViewBuilder private var plans: some View {
        switch viewModel.phase {
        case .loading:
            planCards(ProPlan.allCases.map(PlanOffer.placeholder), selectable: false)
                .redacted(reason: .placeholder)
        case let .failed(message):
            VStack(spacing: Spacing.sm) {
                planCards(ProPlan.allCases.map(PlanOffer.placeholder), selectable: false)
                    .opacity(0.55)
                Label(message, systemImage: "wifi.exclamationmark")
                    .font(Typography.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("paywall.unavailable")
                #if DEBUG
                    // A String value, not a literal: debug-only, so kept out of the catalog.
                    Text(Self.developerNote)
                        .font(Typography.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                #endif
                PrimaryButton(title: "Try Again", systemImage: "arrow.clockwise", isCompact: true) {
                    Task { await viewModel.load() }
                }
            }
        case .loaded:
            planCards(viewModel.offers, selectable: true)
        }
    }

    private func planCards(_ offers: [PlanOffer], selectable: Bool) -> some View {
        VStack(spacing: Spacing.sm) {
            ForEach(offers) { offer in
                PlanCard(offer: offer, isSelected: viewModel.selected == offer.plan) {
                    viewModel.selected = offer.plan
                }
                .disabled(!selectable)
            }
        }
    }

    /// The renewal terms and any message sit right above Buy, so they're never scrolled away.
    private var bottomBar: some View {
        VStack(spacing: Spacing.sm) {
            if let message = viewModel.message {
                Text(message)
                    .font(Typography.secondary)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("paywall.message")
            }
            if viewModel.phase == .loaded {
                Text(viewModel.terms)
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("paywall.terms")
            }
            PrimaryButton(
                text: Text(viewModel.buyTitle),
                systemImage: "chevron.right.2",
                isLoading: viewModel.isPurchasing
            ) {
                Task {
                    if await viewModel.buy() {
                        onClose()
                    }
                }
            }
            .disabled(viewModel.selectedOffer == nil)
            .accessibilityIdentifier("paywall.buy")
            HStack(spacing: Spacing.md) {
                Button("Terms") {
                    if let url = LegalLinks.terms {
                        openURL(url)
                    }
                }
                Divider().frame(height: 16).overlay(.white.opacity(0.3))
                Button("Privacy") { isShowingPrivacy = true }
                Divider().frame(height: 16).overlay(.white.opacity(0.3))
                Button("Restore") {
                    Task {
                        if await viewModel.restore() {
                            onClose()
                        }
                    }
                }
                .accessibilityIdentifier("paywall.restore")
            }
            .font(Typography.secondary)
            .foregroundStyle(.white.opacity(0.7))
            .frame(minHeight: 44)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(Color.roadAsphalt.opacity(0.96))
    }
}

#Preview("Intro") {
    PaywallView(
        viewModel: PaywallViewModel(access: ProAccess(client: FakeStoreClient()), reason: .intro),
        onClose: {}
    )
}

#Preview("Largest text") {
    PaywallView(
        viewModel: PaywallViewModel(access: ProAccess(client: FakeStoreClient()), reason: .sources),
        onClose: {}
    )
    .environment(\.dynamicTypeSize, .accessibility3)
}
