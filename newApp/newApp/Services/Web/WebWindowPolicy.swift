import Foundation
import WebKit

@MainActor
enum WebWindowPolicy {
    static func newWindow(
        parent: WKWebView,
        configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        log: @escaping (String) -> Void,
        openExternally: @escaping (URL, String) -> Void
    ) -> WKWebView? {
        guard navigationAction.sourceFrame.isMainFrame else {
            log("window requested by a sub-frame — ignored")
            return nil
        }

        if let url = navigationAction.request.url,
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            if WebHostPolicy.isFirstParty(url) {
                log("window (first-party) → same view: \(url.absoluteString)")
                parent.load(URLRequest(url: url))
            } else {
                openExternally(url, "window, third-party")
            }
            return nil
        }

        if let url = navigationAction.request.url,
           let scheme = url.scheme?.lowercased(),
           !scheme.isEmpty, scheme != "about", scheme != "blob", scheme != "data" {
            openExternally(url, "window, scheme \(scheme)")
            return nil
        }

        log("window reserved with no address — waiting for the page to fill it in")
        return DeferredWindow.make(
            parent: parent,
            configuration: configuration,
            log: log,
            openExternally: openExternally
        )
    }
}

@MainActor
private final class DeferredWindow: NSObject, WKNavigationDelegate, WKUIDelegate {
    private var view: WKWebView?
    private var retained: DeferredWindow?
    private weak var parent: WKWebView?
    private let log: (String) -> Void
    private let openExternally: (URL, String) -> Void
    private var didResolve = false

    static func make(
        parent: WKWebView,
        configuration: WKWebViewConfiguration,
        log: @escaping (String) -> Void,
        openExternally: @escaping (URL, String) -> Void
    ) -> WKWebView {
        let owner = DeferredWindow(parent: parent, log: log, openExternally: openExternally)

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.isHidden = true
        view.navigationDelegate = owner
        view.uiDelegate = owner
        parent.addSubview(view)

        owner.view = view
        owner.retained = owner

        owner.armTimeout()
        return view
    }

    private init(
        parent: WKWebView,
        log: @escaping (String) -> Void,
        openExternally: @escaping (URL, String) -> Void
    ) {
        self.parent = parent
        self.log = log
        self.openExternally = openExternally
        super.init()
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        decisionHandler(.cancel)

        guard !didResolve, let url = navigationAction.request.url else { return }
        guard let scheme = url.scheme?.lowercased(), scheme != "about" else { return }
        didResolve = true

        if scheme == "http" || scheme == "https", WebHostPolicy.isFirstParty(url) {
            log("reserved window (first-party) → same view: \(url.absoluteString)")
            parent?.load(URLRequest(url: url))
        } else {
            openExternally(url, "reserved window")
        }
        dispose()
    }

    func webViewDidClose(_ webView: WKWebView) {
        dispose()
    }

    private func armTimeout() {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard let self, !self.didResolve else { return }
            self.log("reserved window was never given an address — discarded")
            self.dispose()
        }
    }

    private func dispose() {
        view?.stopLoading()
        view?.navigationDelegate = nil
        view?.uiDelegate = nil
        view?.removeFromSuperview()
        view = nil
        retained = nil
    }
}
