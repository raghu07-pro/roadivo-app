import Observation
import UIKit

/// Which way the app may turn, for the player's rotation lock and full-screen button and for
/// Car Mode. `AppDelegate` hands `supported` to iOS.
@Observable
@MainActor
final class OrientationLock {
    static let shared = OrientationLock()

    private(set) var supported: UIInterfaceOrientationMask = .allButUpsideDown
    private(set) var isLocked = false

    /// Turns to `orientation` now. Locked, it stays there; unlocked, turning the iPhone turns it back.
    func rotate(to orientation: UIInterfaceOrientationMask) {
        supported = orientation
        refresh()
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
        }
        guard !isLocked else { return }
        Task {
            // Freed after the turn without asking iOS to re-check, which would turn straight back.
            try? await Task.sleep(for: .milliseconds(700)) // Never cancelled; a no-op if locked meanwhile.
            if !isLocked {
                supported = .allButUpsideDown
            }
        }
    }

    /// Turns to `orientation` and stays there until `reset()`, so a bump on a mount can't flip it.
    func hold(_ orientation: UIInterfaceOrientationMask) {
        isLocked = true
        rotate(to: orientation)
    }

    /// Locks to the way the screen faces now, or unlocks.
    func toggleLock(isLandscape: Bool) {
        isLocked.toggle()
        supported = isLocked ? (isLandscape ? .landscape : .portrait) : .allButUpsideDown
        refresh()
    }

    /// Back to free rotation when the player or Car Mode closes, turning to match how the iPhone is held.
    func reset() {
        isLocked = false
        supported = .allButUpsideDown
        refresh()
    }

    private func refresh() {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows {
                var controller = window.rootViewController
                while let current = controller {
                    current.setNeedsUpdateOfSupportedInterfaceOrientations()
                    controller = current.presentedViewController
                }
            }
        }
    }
}
