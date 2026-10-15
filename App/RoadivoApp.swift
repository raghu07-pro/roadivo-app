import SwiftUI
import UIKit

@main
struct RoadivoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var environment = AppEnvironment.live(arguments: ProcessInfo.processInfo.arguments)
    @State private var language = AppLanguage.shared

    init() {
        Typography.applyUIKitFonts()
    }

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
                // The chosen language: SwiftUI text resolves in this locale, and
                // the new identity rebuilds every screen when it changes.
                .environment(\.locale, language.locale)
                .id(language.code ?? "system")
                // Navigation-bar fonts come from UIKit appearance, which doesn't
                // follow Dynamic Type on its own; re-scale them when it changes.
                .onReceive(NotificationCenter.default
                    .publisher(for: UIContentSizeCategory.didChangeNotification)) { _ in
                        Typography.applyUIKitFonts()
                }
        }
    }
}
