import SwiftUI
import WebKit

/// A web page bundled with the app, drawn by WebKit. Its own section links stay in the page; other
/// sites and email links open outside the app. Light or dark follows the app.
struct HTMLPageView: UIViewRepresentable {
    let fileURL: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.dataDetectorTypes = []
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = .clear
        view.allowsLinkPreview = false
        view.loadFileURL(fileURL, allowingReadAccessTo: fileURL)
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        view.overrideUserInterfaceStyle = context.environment.colorScheme == .dark ? .dark : .light
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url, !url.isFileURL else { return .allow }
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return .cancel
        }
    }
}
