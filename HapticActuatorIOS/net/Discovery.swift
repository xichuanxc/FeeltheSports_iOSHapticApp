import Network

final class Discovery {
    private var browser: NWBrowser?
    private let onFound: (NWEndpoint, String) -> Void

    init(onFound: @escaping (NWEndpoint, String) -> Void) {
        self.onFound = onFound
    }

    func start() {
        guard browser == nil else { return }
        let b = NWBrowser(for: .bonjour(type: "_haptics._tcp", domain: "local."), using: .tcp)
        browser = b
        b.browseResultsChangedHandler = { [weak self] (results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) in
            for change in changes {
                if case .added(let result) = change {
                    // Extract just the human-readable service name, e.g. "haptic-laptop"
                    let name: String
                    if case .service(let svcName, _, _, _) = result.endpoint {
                        name = svcName
                    } else {
                        name = result.endpoint.debugDescription
                    }
                    self?.onFound(result.endpoint, name)
                }
            }
        }
        b.start(queue: DispatchQueue.main)
    }

    func stop() {
        browser?.cancel()
        browser = nil
    }
}
