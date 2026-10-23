import CarPlay

/// A website field opens native car text entry; only the chosen field receives the completed value.
@MainActor
final class CarBrowserFieldEditor: NSObject, CPSearchTemplateDelegate {
    private weak var interface: CPInterfaceController?
    private weak var bridge: CarBrowserInputBridge?
    private var request: CarBrowserInputBridge.Request?
    private var template: CPSearchTemplate?
    private var submissionID = UUID()
    private var enteredText = ""
    private var isApplying = false

    private struct Entry {
        let text: String
        let submit: Bool
    }

    init(interface: CPInterfaceController) {
        self.interface = interface
    }

    func present(bridge: CarBrowserInputBridge, request: CarBrowserInputBridge.Request) {
        if let template, interface?.templates.contains(where: { $0 === template }) == true { return }
        submissionID = UUID()
        enteredText = ""
        isApplying = false
        self.bridge = bridge
        self.request = request
        let search = CPSearchTemplate()
        search.delegate = self
        template = search
        interface?.pushTemplate(search, animated: true) { accepted, _ in
            CarPlayTrace.write("input editor accepted: \(accepted)")
        }
    }

    func cancel() {
        submissionID = UUID()
        isApplying = false
        bridge?.invalidate()
        bridge = nil
        request = nil
        if let template, interface?.templates.contains(where: { $0 === template }) == true {
            interface?.popToRootTemplate(animated: false, completion: nil)
        }
        template = nil
    }

    func searchTemplate(
        _ searchTemplate: CPSearchTemplate, updatedSearchText searchText: String,
        completionHandler: @escaping ([CPListItem]) -> Void
    ) {
        guard searchTemplate === template, let request, bridge?.isEnabled == true else {
            return completionHandler([])
        }
        enteredText = searchText
        let title = request.isSearch ? String(appLocalized: "Submit search") : String(appLocalized: "Done")
        let context = [request.frame.securityOrigin.host, request.label, searchText].filter { !$0.isEmpty }
        let row = CPListItem(text: title, detailText: context.joined(separator: " · "),
                             image: UIImage(systemName: "arrow.turn.down.left"))
        row.userInfo = Entry(text: searchText, submit: request.isSearch)
        row.isEnabled = searchText.utf16.count <= 4096
        completionHandler([row])
    }

    func searchTemplate(
        _ searchTemplate: CPSearchTemplate, selectedResult item: CPListItem,
        completionHandler: @escaping () -> Void
    ) {
        guard searchTemplate === template, let request, let bridge, let entry = item.userInfo as? Entry else {
            return completionHandler()
        }
        apply(entry, request: request, bridge: bridge, completion: completionHandler)
    }

    func searchTemplateSearchButtonPressed(_ searchTemplate: CPSearchTemplate) {
        guard searchTemplate === template, let request, let bridge else { return }
        apply(Entry(text: enteredText, submit: request.isSearch), request: request, bridge: bridge, completion: {})
    }

    private func apply(
        _ entry: Entry, request: CarBrowserInputBridge.Request, bridge: CarBrowserInputBridge,
        completion: @escaping () -> Void
    ) {
        guard !isApplying else { return completion() }
        isApplying = true
        let submission = submissionID
        bridge.apply(entry.text, to: request, submit: entry.submit) { [weak self] success in
            completion()
            guard let self, self.submissionID == submission else { return }
            self.cancel()
            if !success { self.showFailure() }
        }
    }

    private func showFailure() {
        let done = CPAlertAction(title: String(appLocalized: "OK"), style: .cancel) { [weak self] _ in
            MainActor.assumeIsolated { self?.interface?.dismissTemplate(animated: true, completion: nil) }
        }
        interface?.presentTemplate(CPAlertTemplate(
            titleVariants: [String(appLocalized: "The page changed or this field could not be submitted. Try again.")],
            actions: [done]
        ), animated: true, completion: nil)
    }
}
