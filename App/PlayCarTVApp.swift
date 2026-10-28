import SwiftUI
import UIKit

@main
struct PlayCarTVApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var environment = AppEnvironment.live(arguments: ProcessInfo.processInfo.arguments)
    @State private var language = AppLanguage.shared
    @State private var showsSplash = SplashView.isWanted(
        arguments: ProcessInfo.processInfo.arguments,
        environment: ProcessInfo.processInfo.environment
    )

    init() {
        Typography.applyUIKitFonts()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
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
                // Over the app, which loads underneath while it plays (DECISIONS 130).
                if showsSplash {
                    SplashView { showsSplash = false }
                        .environment(\.locale, language.locale)
                }
            }
        }
    }
}
