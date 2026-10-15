import SwiftUI

struct PlanCard: View {
    let offer: PlanOffer
    let isSelected: Bool
    var isCurrent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.roadAccent : Color.white.opacity(0.5))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app: offer.plan.title).font(Typography.button)
                    Text(app: offer.plan.subtitle)
                        .font(Typography.caption)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(2)
                }
                Spacer(minLength: Spacing.xs)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(offer.displayPrice).font(Typography.button)
                    if let intro = offer.introPrice {
                        Text("First week \(intro)")
                            .font(Typography.caption)
                            .foregroundStyle(.roadAccent)
                    } else if let perWeek = offer.perWeekPrice {
                        Text("\(perWeek) / week")
                            .font(Typography.caption)
                            .foregroundStyle(.white.opacity(0.65))
                    } else if !offer.plan.isSubscription, offer.price > 0 {
                        Text("One-time")
                            .font(Typography.caption)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                .multilineTextAlignment(.trailing)
            }
            .foregroundStyle(.white)
            .padding(Spacing.md)
            .background(
                isSelected ? AnyShapeStyle(Color(white: 0.18)) : AnyShapeStyle(Color(white: 0.12)),
                in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(isSelected ? AnyShapeStyle(.roadBrandGradient) : AnyShapeStyle(.clear), lineWidth: 2)
            }
            .overlay(alignment: .topTrailing) {
                if isCurrent || offer.plan == .lifetime {
                    Text(isCurrent ? "Current plan" : "Best value")
                        .font(Typography.badge)
                        .foregroundStyle(.roadOnBrand)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 3)
                        .background(.roadBrandGradient, in: Capsule())
                        .offset(x: -Spacing.sm, y: -10)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("paywall.plan.\(offer.plan.rawValue)")
    }
}
