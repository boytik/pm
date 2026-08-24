//
//  WebWindowPolicy.swift
//  Alpha Academy
//
//  What happens when the page asks for a second window — `target="_blank"` or
//  `window.open`. This is how the front end opens the Pocket cashier, so it is
//  the path that matters most, and it has three shapes that fail in three
//  different ways:
//
//    1. `window.open(url)` inside the tap        — arrives with a URL
//    2. `window.open(url)` after awaiting the    — WebKit's popup blocker eats
//       server                                     it unless
//                                                  `javaScriptCanOpenWindowsAutomatically`
//                                                  is on, and the delegate is
//                                                  never called at all
//    3. `var w = window.open('', '_blank')`      — arrives with NO URL; the page
//       …then `w.location.href = url`              fills it in later, and
//                                                  returning nil makes
//                                                  `window.open` evaluate to
//                                                  `null` so the page's next
//                                                  line throws
//
//  In every one of those the learner taps "Deposit" and *nothing happens*,
//  which is indistinguishable from having no `WKUIDelegate` at all — the exact
//  symptom this whole change exists to remove. So all three are handled here,
//  once, and both the shell and the push sheet route through it.
//

import Foundation
import WebKit

@MainActor
enum WebWindowPolicy {

    /// Call from `WKUIDelegate.createWebViewWith`. Returns a web view only for
    /// case 3, and that one exists purely to catch the address.
    static func newWindow(
        parent: WKWebView,
        configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        log: @escaping (String) -> Void,
        openExternally: @escaping (URL, String) -> Void
    ) -> WKWebView? {

        // A window request from an ad, a chat widget or an analytics frame is
        // not the learner asking for anything. With the popup blocker now off
        // this is the guard that keeps a third-party frame from throwing the
        // learner into Safari unprompted.
        guard navigationAction.sourceFrame.isMainFrame else {
            log("window requested by a sub-frame — ignored")
            return nil
        }

        if let url = navigationAction.request.url,
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            if WebHostPolicy.isFirstParty(url) {
                // Ours. There is no navigation bar to give a second window, so
                // it loads over the top of this one.
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

        // Case 3: no address yet. Hand back a real web view so `window.open`
        // returns something the page can assign to, and bounce whatever it
        // eventually navigates to.
        log("window reserved with no address — waiting for the page to fill it in")
        return DeferredWindow.make(
            parent: parent,
            configuration: configuration,
            log: log,
            openExternally: openExternally
        )
    }
}

/// A throwaway web view that exists only until the page tells it where to go.
///
/// It is added to the hierarchy at zero size rather than left detached —
/// WebKit is not obliged to run navigation for a view that is in no window —
/// and it retains itself, because nothing else has any reason to hold it. Both
/// halves are released the moment it has served its one purpose.
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
        // The configuration handed to `createWebViewWith` must be the one used,
        // or the new view is not related to the opener and `window.opener`
        // breaks.
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.isHidden = true
        view.navigationDelegate = owner
        view.uiDelegate = owner
        parent.addSubview(view)

        owner.view = view
        owner.retained = owner
        // A page that reserves a window and then never uses it would otherwise
        // leak one web view per tap.
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
