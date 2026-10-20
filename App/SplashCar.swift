import SwiftUI

/// The logo's car on the splash's road, seen from behind (owner, 2026-10-20; DECISIONS 130): a dark body, red
/// taillights at the corners, an amber plate. Drawn in code, so it's sharp at any size; it fills its frame.
struct SplashCar: View {
    private static let shell = Color(red: 0.2, green: 0.21, blue: 0.3)
    private static let shellLow = Color(red: 0.1, green: 0.11, blue: 0.17)
    private static let tailLight = Color(red: 1.0, green: 0.18, blue: 0.28)

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                Ellipse()
                    .fill(.black.opacity(0.45))
                    .frame(width: width * 1.06, height: height * 0.14)
                    .blur(radius: 5)
                    .position(x: width / 2, y: height * 0.95)
                wheel(width: width, height: height).position(x: width * 0.17, y: height * 0.86)
                wheel(width: width, height: height).position(x: width * 0.83, y: height * 0.86)
                Cabin()
                    .fill(LinearGradient(colors: [Self.shell, Self.shellLow], startPoint: .top, endPoint: .bottom))
                    .frame(width: width * 0.78, height: height * 0.44)
                    .position(x: width / 2, y: height * 0.27)
                Cabin()
                    .fill(Color(red: 0.05, green: 0.06, blue: 0.11))
                    .overlay(
                        LinearGradient(
                            colors: [.white.opacity(0.14), .clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                        .clipShape(Cabin())
                    )
                    .frame(width: width * 0.62, height: height * 0.3)
                    .position(x: width / 2, y: height * 0.31)
                RoundedRectangle(cornerRadius: height * 0.12, style: .continuous)
                    .fill(LinearGradient(colors: [Self.shell, Self.shellLow], startPoint: .top, endPoint: .bottom))
                    .frame(width: width, height: height * 0.46)
                    .position(x: width / 2, y: height * 0.66)
                Capsule()
                    .fill(Self.tailLight.opacity(0.7))
                    .frame(width: width * 0.56, height: height * 0.025)
                    .position(x: width / 2, y: height * 0.52)
                ForEach([0.19, 0.81], id: \.self) { across in
                    Capsule()
                        .fill(Self.tailLight)
                        .frame(width: width * 0.22, height: height * 0.075)
                        .shadow(color: Self.tailLight.opacity(0.8), radius: 8)
                        .position(x: width * across, y: height * 0.52)
                }
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.72, blue: 0.28))
                    .frame(width: width * 0.2, height: height * 0.1)
                    .position(x: width / 2, y: height * 0.7)
            }
        }
    }

    private func wheel(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: height * 0.05, style: .continuous)
            .fill(Color(red: 0.03, green: 0.03, blue: 0.05))
            .frame(width: width * 0.15, height: height * 0.2)
    }
}

/// The cabin and rear window: narrower at the roof, with rounded top corners.
private struct Cabin: Shape {
    func path(in rect: CGRect) -> Path {
        let inset = rect.width * 0.13
        let corner = rect.height * 0.22
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + inset, y: rect.minY + corner))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + inset + corner, y: rect.minY),
            control: CGPoint(x: rect.minX + inset, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - inset - corner, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - inset, y: rect.minY + corner),
            control: CGPoint(x: rect.maxX - inset, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    SplashCar()
        .frame(width: 160, height: 100)
        .padding()
        .background(Color("LaunchBackground"))
}
