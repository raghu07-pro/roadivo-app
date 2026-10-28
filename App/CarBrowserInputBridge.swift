import UIKit
import WebKit

/// Measures the native/DOM input boundary and routes actual taps on any text box or dropdown to a car-side editor.
@MainActor
final class CarBrowserInputBridge: NSObject, WKScriptMessageHandler, UIGestureRecognizerDelegate {
    struct Option: Equatable {
        let title: String
        let isSelected: Bool
        let isEnabled: Bool
    }

    struct Request {
        let documentID: String
        let fieldID: String
        let label: String
        let isSearch: Bool
        /// The page's site, for the editor's title when the field has no label.
        let host: String
        let frame: WKFrameInfo
        /// A dropdown's choices; empty for a text field.
        let options: [Option]
        /// What the field already holds, to edit; always empty for a password, which never leaves the page.
        let value: String
        /// A password: shown as dots while it's typed on the car's screen.
        let isSecure: Bool
        /// A number or phone field: the keyboard opens on its numbers.
        let isNumeric: Bool
    }

    struct Diagnostics {
        var ready = 0
        var nativeTaps = 0
        var webpageTaps = 0
        var editors = 0
        var applied = 0
    }

    var onEdit: ((Request) -> Void)?
    var isEnabled = false {
        didSet {
            if !isEnabled {
                invalidate()
            }
        }
    }

    private(set) var diagnostics = Diagnostics()
    private weak var webView: WKWebView?
    private var pending: Request?
    private static let world = WKContentWorld.world(name: "PlayCarTVCarInput")

    /// The page side of the bridge, for a car tab that sets its scripts again (`CarBrowserSession.Tab`).
    static var userScripts: [WKUserScript] {
        #if DEBUG
            [WKUserScript(
                source: CarBrowserInputScript.source,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false,
                in: world
            )]
        #else
            []
        #endif
    }

    init(webView: WKWebView) {
        self.webView = webView
        super.init()
        #if DEBUG
            let content = webView.configuration.userContentController
            content.add(self, contentWorld: Self.world, name: "playcartvCarInput")
            Self.userScripts.forEach(content.addUserScript)
            let tap = UITapGestureRecognizer(target: self, action: #selector(nativeTap))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            webView.addGestureRecognizer(tap)
        #endif
    }

    func invalidate() {
        pending = nil
    }

    func resetDiagnostics() {
        invalidate()
        diagnostics = Diagnostics()
    }

    @objc
    private func nativeTap() {
        if isEnabled {
            diagnostics.nativeTaps += 1
        }
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard isEnabled, message.webView === webView, let body = message.body as? [String: Any],
              let kind = body["kind"] as? String else { return }
        switch kind {
        case "ready": diagnostics.ready += 1
        case "pointer": diagnostics.webpageTaps += 1
        case "edit", "choose":
            guard let documentID = body["documentID"] as? String, let fieldID = body["requestID"] as? String,
                  let label = body["label"] as? String else { return }
            let request = Request(
                documentID: documentID,
                fieldID: fieldID,
                label: label,
                isSearch: body["search"] as? Bool ?? false,
                host: message.frameInfo.securityOrigin.host,
                frame: message.frameInfo,
                options: Self.options(from: body["options"]),
                value: String((body["value"] as? String ?? "").prefix(4096)),
                isSecure: body["secure"] as? Bool ?? false,
                isNumeric: body["numeric"] as? Bool ?? false
            )
            pending = request
            diagnostics.editors += 1
            onEdit?(request)
        default: break
        }
    }

    func apply(_ value: String, to request: Request, submit: Bool, completion: @escaping (Bool) -> Void) {
        guard isEnabled, value.utf16.count <= 4096, matchesPending(request) else { return completion(false) }
        pending = nil
        let arguments: [String: Any] = [
            "documentToken": request.documentID,
            "fieldToken": request.fieldID,
            "value": value,
            "submit": submit && request.isSearch
        ]
        finish(CarBrowserInputScript.apply, arguments, frame: request.frame, completion: completion)
    }

    func choose(_ index: Int, for request: Request, completion: @escaping (Bool) -> Void) {
        guard isEnabled, request.options.indices.contains(index), matchesPending(request) else {
            return completion(false)
        }
        pending = nil
        let arguments: [String: Any] = [
            "documentToken": request.documentID,
            "fieldToken": request.fieldID,
            "index": index
        ]
        finish(CarBrowserInputScript.choose, arguments, frame: request.frame, completion: completion)
    }

    private func matchesPending(_ request: Request) -> Bool {
        pending?.documentID == request.documentID && pending?.fieldID == request.fieldID
    }

    private func finish(
        _ script: String,
        _ arguments: [String: Any],
        frame: WKFrameInfo,
        completion: @escaping (Bool) -> Void
    ) {
        guard let webView else { return completion(false) }
        webView.callAsyncJavaScript(script, arguments: arguments, in: frame, in: Self.world) { [weak self] result in
            let success = (try? result.get()) as? Bool == true // A failed call means the page moved on.
            if success {
                self?.diagnostics.applied += 1
            }
            completion(success)
        }
    }

    private static func options(from value: Any?) -> [Option] {
        (value as? [[String: Any]] ?? []).map { option in
            Option(
                title: option["title"] as? String ?? "",
                isSelected: option["selected"] as? Bool ?? false,
                isEnabled: !(option["disabled"] as? Bool ?? false)
            )
        }
    }
}
