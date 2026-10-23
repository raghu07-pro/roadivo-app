import UIKit
import WebKit

/// Measures the native/DOM input boundary and routes actual field clicks to a car-side editor.
@MainActor
final class CarBrowserInputBridge: NSObject, WKScriptMessageHandler, UIGestureRecognizerDelegate {
    struct Request {
        let documentID: String
        let fieldID: String
        let label: String
        let isSearch: Bool
        let frame: WKFrameInfo
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
        didSet { if !isEnabled { invalidate() } }
    }
    private(set) var diagnostics = Diagnostics()
    private weak var webView: WKWebView?
    private var pending: Request?
    private static let world = WKContentWorld.world(name: "RoadivoCarInput")

    init(webView: WKWebView) {
        self.webView = webView
        super.init()
        #if DEBUG
            let content = webView.configuration.userContentController
            content.add(self, contentWorld: Self.world, name: "roadivoCarInput")
            content.addUserScript(WKUserScript(
                source: CarBrowserInputScript.source, injectionTime: .atDocumentStart,
                forMainFrameOnly: false, in: Self.world
            ))
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

    @objc private func nativeTap() {
        if isEnabled { diagnostics.nativeTaps += 1 }
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
        case "edit":
            guard let documentID = body["documentID"] as? String, let fieldID = body["requestID"] as? String,
                  let label = body["label"] as? String, let search = body["search"] as? Bool else { return }
            let request = Request(documentID: documentID, fieldID: fieldID, label: label,
                                  isSearch: search, frame: message.frameInfo)
            pending = request
            diagnostics.editors += 1
            onEdit?(request)
        default: break
        }
    }

    func apply(_ value: String, to request: Request, submit: Bool, completion: @escaping (Bool) -> Void) {
        guard isEnabled, let webView, value.utf16.count <= 4096,
              pending?.documentID == request.documentID, pending?.fieldID == request.fieldID else {
            return completion(false)
        }
        pending = nil
        webView.callAsyncJavaScript(
            CarBrowserInputScript.apply,
            arguments: ["documentToken": request.documentID, "fieldToken": request.fieldID,
                        "value": value, "submit": submit && request.isSearch],
            in: request.frame, in: Self.world
        ) { [weak self] result in
            let success = (try? result.get()) as? Bool == true
            if success { self?.diagnostics.applied += 1 }
            completion(success)
        }
    }
}
