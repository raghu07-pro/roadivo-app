import CarPlay
import UIKit

/// Lets the player's rotation lock and full-screen button decide which way the app turns, and hands the car's
/// screen to `CarPlaySceneDelegate`.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationLock.shared.supported
    }

    /// Named here, not only in Info.plist: on iOS 27 the CarPlay scene connected without it and stayed blank
    /// (DECISIONS 138). Every other scene keeps SwiftUI's own setup.
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let role = connectingSceneSession.role
        CarPlayTrace.write("scene asked for: \(role.rawValue)")
        let configuration = UISceneConfiguration(name: nil, sessionRole: role)
        if role == .carTemplateApplication {
            configuration.sceneClass = CPTemplateApplicationScene.self
            configuration.delegateClass = CarPlaySceneDelegate.self
        }
        return configuration
    }
}
