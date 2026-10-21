import SwiftUI

/// Where the iPhone is: a car in the theme's colours, Roadivo's own instead of Maps' blue dot.
struct CarMarker: View {
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 34

    var body: some View {
        Image(systemName: "car.fill")
            .font(.system(size: side * 0.45, weight: .semibold))
            .foregroundStyle(.roadOnBrand)
            .frame(width: side, height: side)
            .background(.roadBrandGradient, in: Circle())
            .overlay { Circle().strokeBorder(.white, lineWidth: 2.5) }
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            .accessibilityHidden(true) // The map reads the user's location itself.
    }
}

/// The chosen place: a chequered flag on a brand tile, pointing down at the spot.
struct DestinationMarker: View {
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 38

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "flag.checkered")
                .font(.system(size: side * 0.45, weight: .bold))
                .foregroundStyle(.roadOnBrand)
                .frame(width: side, height: side)
                .background(.roadBrandGradient, in: RoundedRectangle(cornerRadius: side * 0.3, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: side * 0.3, style: .continuous).strokeBorder(.white, lineWidth: 2.5)
                }
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: side * 0.3))
                .foregroundStyle(.roadBrandDeep)
                .offset(y: -side * 0.08)
        }
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        .accessibilityHidden(true) // The annotation's title names the place.
    }
}

#Preview {
    HStack(spacing: Spacing.xl) {
        CarMarker()
        DestinationMarker()
    }
    .padding()
    .background(.roadCanvas)
}
