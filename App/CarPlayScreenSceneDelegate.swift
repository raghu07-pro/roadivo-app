#if DEBUG
    import UIKit

    /// The Debug car browser experiment's car window (DECISIONS 161): a plain window scene under CarPlay's
    /// undocumented window role. Unlike the template scene's `CPWindow`, its views get the car's taps, as in the
    /// open-source Cafari Lite. iOS offers the role only to a build signed with CarPlay Audio + Video.
    final class CarPlayScreenSceneDelegate: UIResponder, UIWindowSceneDelegate {
        /// UIKit has no Swift name for this role; the built Info.plist declares it (`carScreenScene` in Project.swift).
        static let role = UISceneSession.Role(rawValue: "UIWindowSceneSessionRoleCarPlay")

        var window: UIWindow?
        private var screen: CarScreenController?

        func scene(
            _ scene: UIScene,
            willConnectTo session: UISceneSession,
            options connectionOptions: UIScene.ConnectionOptions
        ) {
            guard let windowScene = scene as? UIWindowScene else { return }
            let size = windowScene.coordinateSpace.bounds.size
            CarPlayTrace.write("screen connect: \(session.role.rawValue), \(Int(size.width))×\(Int(size.height))")
            AppEnvironment.current?.carConnection.isCarPlayConnected = true
            AppEnvironment.current?.parking.start()
            let screen = CarScreenController()
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = screen
            window.makeKeyAndVisible()
            self.screen = screen
            self.window = window
            screen.connect()
        }

        func sceneDidDisconnect(_ scene: UIScene) {
            CarPlayTrace.write("screen disconnect")
            screen?.close()
            screen = nil
            window = nil
            AppEnvironment.current?.parking.stop()
            AppEnvironment.current?.carConnection.isCarPlayConnected = false
        }
    }
#endif
