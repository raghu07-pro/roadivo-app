import SwiftUI

/// The view from the driver's seat: the road through the windshield, the
/// dashboard in the foreground and the car's centre screen showing the
/// page's idea. Everything is drawn in code from the app's palette.
struct CockpitView: View {
    let time: RoadScene.TimeOfDay
    let content: DashScreenContent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack(alignment: .bottom) {
                RoadScene(time: time, horizon: 0.5, sunIsPlayButton: content == .brand)
                DashboardShape()
                    .fill(LinearGradient(
                        colors: [Color(white: 0.16), Color(white: 0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(height: height * 0.36)
                SteeringWheel()
                    .stroke(Color(white: 0.04), lineWidth: width * 0.05)
                    .frame(width: width * 0.62, height: width * 0.62)
                    .offset(x: -width * 0.42, y: height * 0.12)
                CentreScreen(content: content)
                    .frame(width: min(width * 0.62, 380), height: min(width * 0.62, 380) * 0.5)
                    .offset(y: -height * 0.07)
                    .scaleEffect(isShown || reduceMotion ? 1 : 0.92)
                    .opacity(isShown || reduceMotion ? 1 : 0)
            }
            .frame(width: width, height: height)
        }
        .clipped()
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.6, bounce: 0.25).delay(0.15)) { isShown = true }
        }
        .onDisappear { isShown = false }
        .accessibilityHidden(true)
    }
}

/// The dashboard's top edge: a gentle hump with the instrument hood on the left.
private struct DashboardShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.05))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.32),
            control1: CGPoint(x: rect.width * 0.35, y: rect.minY - rect.height * 0.12),
            control2: CGPoint(x: rect.width * 0.7, y: rect.minY + rect.height * 0.22)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// The top arc of a steering wheel at the bottom-left corner.
private struct SteeringWheel: Shape {
    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: rect)
    }
}

/// The infotainment screen, with content per page.
private struct CentreScreen: View {
    let content: DashScreenContent

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.black)
            screen
                .padding(Spacing.sm)
        }
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.6), radius: 18, y: 10)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder private var screen: some View {
        switch content {
        case .brand:
            HStack(spacing: Spacing.sm) {
                RoadScene(time: .goldenHour, horizon: 0.55, animated: false, sunIsPlayButton: true)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Roadivo").font(Typography.sectionTitle).foregroundStyle(.white)
                    Text(app: Brand.tagline).font(Typography.data).foregroundStyle(.roadAccent)
                }
            }
        case .nowPlaying:
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Palette.placeholderGradient(for: "Ocean Quest")
                    Image(systemName: "play.fill").font(.title2).foregroundStyle(.white)
                }
                .frame(width: 92)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("NOW PLAYING").font(Typography.badge).foregroundStyle(.roadAccent)
                    Text("Ocean Quest").font(Typography.sign).foregroundStyle(.white)
                    ProgressBar(fraction: 0.35)
                }
            }
        case .charging:
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Image(systemName: "bolt.car.fill").foregroundStyle(.roadAccent)
                    Text("Charging · 64%").font(Typography.sign).foregroundStyle(.white)
                }
                ProgressBar(fraction: 0.64)
                Label("Resume at 42:10", systemImage: "play.circle.fill")
                    .font(Typography.data)
                    .foregroundStyle(.roadAccent)
            }
        case .playlists:
            VStack(alignment: .leading, spacing: 6) {
                row("Movies", count: 24)
                row("Sports", count: 12)
                row("Travel", count: 8)
            }
        }
    }

    private func row(_ title: LocalizedStringKey, count: Int) -> some View {
        HStack {
            Text(title).font(Typography.cardTitle).foregroundStyle(.white)
            Spacer()
            Text("\(count)")
                .font(Typography.badge)
                .foregroundStyle(.roadOnBrand)
                .padding(.horizontal, 6)
                .background(.roadBrandGradient, in: RoundedRectangle(cornerRadius: 4))
        }
    }
}

/// A playback or charge bar that fills in when the page appears.
private struct ProgressBar: View {
    let fraction: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2))
                Capsule()
                    .fill(.roadBrandGradient)
                    .frame(width: proxy.size.width * (shown || reduceMotion ? fraction : 0))
            }
        }
        .frame(height: 6)
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 1.2).delay(0.4)) { shown = true }
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        CockpitView(time: .goldenHour, content: .brand)
        CockpitView(time: .dusk, content: .charging)
    }
    .ignoresSafeArea()
}
