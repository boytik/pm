//
//  WebShellView.swift
//  Alpha Academy
//
//  The whole app once web mode is granted: one full-bleed WKWebView, no chrome.
//  There is deliberately no navigation bar — back is the edge swipe, reload is
//  pull-to-refresh — and deliberately no safe-area inset, so the page owns every
//  pixel including the strips behind the status bar and the home indicator.
//

import SwiftUI
import WebKit

struct WebShellView: View {
    let destination: URL

    @State private var currentURL: URL
    @State private var didExhaustRecovery = false
    /// One rescue per app session, on top of the lifetime request budget.
    @State private var didTryRescue = false

    init(destination: URL) {
        self.destination = destination
        _currentURL = State(initialValue: destination)
    }

    var body: some View {
        ZStack {
            Theme.bg

            if didExhaustRecovery {
                WebRetryView { retry() }
            } else {
                WebSurface(
                    url: currentURL,
                    onAddressChange: { WebModeStore.destination = $0 },
                    onFailure: recover
                )
            }
        }
        // No argument, so this covers `.keyboard` too. That matters: WKWebView
        // does its own keyboard avoidance, and SwiftUI's compounds with it into
        // a form whose focused field scrolls off the screen.
        .ignoresSafeArea()
    }

    /// Attempt 1 was the saved address. Attempt 2, once per install, is that
    /// address rebuilt from the captured `pathid`. After that the learner gets a
    /// retry button rather than a silent demotion to the native trainer — web
    /// mode is permanent, so failing back would break the promise.
    private func recover() {
        guard !didTryRescue,
              WebModeStore.mayRequestHub,
              let rescue = WebGate.rebuiltURL(),
              rescue.absoluteString != currentURL.absoluteString
        else {
            log("recovery exhausted → retry screen")
            didExhaustRecovery = true
            return
        }

        didTryRescue = true
        WebModeStore.noteHubRequest()
        WebModeStore.destination = rescue
        log("rescue via \(WebConfig.pathParameterName) → \(rescue.absoluteString)")
        currentURL = rescue
    }

    private func retry() {
        didExhaustRecovery = false
        currentURL = WebModeStore.destination ?? destination
    }

    private func log(_ message: String) {
        #if DEBUG
        print("WEB shell: \(message)")
        #endif
    }
}

// MARK: - The web view

private struct WebSurface: UIViewRepresentable {
    let url: URL
    let onAddressChange: (URL) -> Void
    let onFailure: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onAddressChange: onAddressChange, onFailure: onFailure)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        // The default, persistent store: a funnel login has to survive relaunch.
        config.websiteDataStore = .default()

        let view = WKWebView(frame: .zero, configuration: config)
        view.allowsBackForwardNavigationGestures = true
        view.backgroundColor = UIColor(Theme.bg)
        view.isOpaque = false
        view.scrollView.backgroundColor = UIColor(Theme.bg)
        // The shell already ignores the safe area; letting WebKit add its own
        // inset on top would push the page down by the status bar twice over.
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator

        let refresh = UIRefreshControl()
        refresh.tintColor = UIColor(Theme.blueBright)
        refresh.addTarget(
            context.coordinator,
            action: #selector(Coordinator.handleRefresh(_:)),
            for: .valueChanged
        )
        view.scrollView.refreshControl = refresh

        context.coordinator.attach(to: view)
        context.coordinator.load(url)
        return view
    }

    /// Gated on what was last *requested*, not on `view.url`. Comparing against
    /// `view.url` looks equivalent but reloads the page in a loop the moment it
    /// navigates itself.
    func updateUIView(_ view: WKWebView, context: Context) {
        guard context.coordinator.lastRequested != url else { return }
        context.coordinator.load(url)
    }

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {

        private(set) var lastRequested: URL?

        private weak var view: WKWebView?
        private var addressObservation: NSKeyValueObservation?
        private var watchdog: Task<Void, Never>?
        private var didReachPage = false
        private var didReportFailure = false

        private let onAddressChange: (URL) -> Void
        private let onFailure: () -> Void

        init(onAddressChange: @escaping (URL) -> Void, onFailure: @escaping () -> Void) {
            self.onAddressChange = onAddressChange
            self.onFailure = onFailure
            super.init()
        }

        func attach(to view: WKWebView) {
            self.view = view
            // A funnel SPA moves through `pushState` without firing `didFinish`,
            // so this observation is the only thing that keeps the saved address
            // current. Written only on a real change, never per scroll.
            addressObservation = view.observe(\.url, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.noteAddress() }
            }
        }

        func detach() {
            addressObservation?.invalidate()
            addressObservation = nil
            cancelWatchdog()
        }

        func load(_ url: URL) {
            lastRequested = url
            didReachPage = false
            didReportFailure = false
            startWatchdog()
            view?.load(URLRequest(url: url))
        }

        @objc func handleRefresh(_ sender: UIRefreshControl) {
            view?.reload()
        }

        // MARK: Address tracking

        private func noteAddress() {
            guard let current = view?.url,
                  let scheme = current.scheme?.lowercased(),
                  scheme == "http" || scheme == "https",
                  current.absoluteString != WebModeStore.destination?.absoluteString
            else { return }
            onAddressChange(current)
        }

        // MARK: Watchdog

        private func startWatchdog() {
            cancelWatchdog()
            watchdog = Task { [weak self] in
                try? await Task.sleep(
                    nanoseconds: UInt64(WebConfig.loadWatchdog * 1_000_000_000)
                )
                guard !Task.isCancelled else { return }
                self?.reportFailure()
            }
        }

        private func cancelWatchdog() {
            watchdog?.cancel()
            watchdog = nil
        }

        private func reportFailure() {
            guard !didReachPage, !didReportFailure else { return }
            didReportFailure = true
            cancelWatchdog()
            view?.scrollView.refreshControl?.endRefreshing()
            onFailure()
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.scrollView.refreshControl?.endRefreshing()

            guard !didReachPage,
                  let scheme = webView.url?.scheme?.lowercased(),
                  scheme == "http" || scheme == "https"
            else { return }

            didReachPage = true
            cancelWatchdog()
            noteAddress()
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            handle(error)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            handle(error)
        }

        private func handle(_ error: Error) {
            // A cancellation is usually the page redirecting over itself.
            guard (error as NSError).code != NSURLErrorCancelled else { return }
            guard !didReachPage else { return }
            reportFailure()
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url,
                  let scheme = url.scheme?.lowercased()
            else {
                decisionHandler(.allow)
                return
            }

            switch scheme {
            case "http", "https", "about", "blob", "data":
                decisionHandler(.allow)
            default:
                // `open` rather than `canOpenURL`: the latter needs every scheme
                // declared in LSApplicationQueriesSchemes, this needs nothing.
                decisionHandler(.cancel)
                UIApplication.shared.open(url)
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            if navigationResponse.isForMainFrame,
               !didReachPage,
               let http = navigationResponse.response as? HTTPURLResponse,
               (400...599).contains(http.statusCode) {
                decisionHandler(.cancel)
                reportFailure()
                return
            }
            decisionHandler(.allow)
        }

        // MARK: WKUIDelegate

        /// `target=_blank` has nowhere else to go without a navigation bar.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        // WKUIDelegate has no default implementation for these, so without them
        // `window.alert` is a silent no-op and a page that validates a form
        // through it becomes a dead end with nothing on screen to explain why.

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completionHandler()
            })
            present(alert, from: webView) { completionHandler() }
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                completionHandler(false)
            })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completionHandler(true)
            })
            present(alert, from: webView) { completionHandler(false) }
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (String?) -> Void
        ) {
            let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
            alert.addTextField { $0.text = defaultText }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                completionHandler(nil)
            })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak alert] _ in
                completionHandler(alert?.textFields?.first?.text)
            })
            present(alert, from: webView) { completionHandler(nil) }
        }

        /// The completion handler must be called exactly once, so a web view
        /// with no view controller to present from still resolves the panel.
        private func present(
            _ alert: UIAlertController,
            from webView: WKWebView,
            fallback: () -> Void
        ) {
            var responder: UIResponder? = webView
            while let next = responder?.next {
                if let controller = next as? UIViewController {
                    controller.present(alert, animated: true)
                    return
                }
                responder = next
            }
            fallback()
        }
    }
}
