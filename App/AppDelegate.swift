import UIKit

/// Only here to let the player's rotation lock and full-screen button decide which way the app turns.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationLock.shared.supported
    }
}
