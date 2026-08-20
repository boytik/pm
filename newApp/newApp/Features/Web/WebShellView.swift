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
                    onPageReady: askForNotificationsIfNeeded,
                    onFailure: recover,
                    onStall: stall
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

    /// A page that committed and then stopped downloading is a different
    /// failure from one that never answered: the address is fine, the bytes
    /// stopped. Rebuilding it from `pathid` would spend the one rescue on a
    /// problem it cannot fix, so this goes straight to the retry screen —
    /// whose button reloads the same address from scratch.
    private func stall() {
        log("load stalled past \(Int(WebConfig.stallWatchdog))s → retry screen")
        didExhaustRecovery = true
    }

    /// Asked here because native onboarding — where the app normally asks —
    /// never runs in web mode, and `PushInbox` will not poll without it. Held
    /// until the page has actually rendered, so it does not stack on top of a
    /// modal the page may raise itself.
    private func askForNotificationsIfNeeded() {
        guard !WebModeStore.didAskPush else { return }
        WebModeStore.didAskPush = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            let granted = await NotificationService.requestAuthorization()
            log("notification permission \(granted ? "granted" : "refused")")
            if granted { await PushInbox.shared.pollIfDue(reason: .foreground, force: true) }
        }
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
    let onPageReady: () -> Void
    let onFailure: () -> Void
    let onStall: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onAddressChange: onAddressChange,
            onPageReady: onPageReady,
            onFailure: onFailure,
            onStall: onStall
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        // The default, persistent store: a funnel login has to survive relaunch.
        config.websiteDataStore = .default()
        // Lifts `localStorage["tw-app-user-id"]` out of the page — the only
        // source of a `user_id` the push backend accepts (§6 of the push spec).
        WebLeadBridge.install(
            on: config.userContentController,
            receiver: context.coordinator.leadReceiver
        )

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
        WebLeadBridge.remove(from: view.configuration.userContentController)
        coordinator.detach()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {

        private(set) var lastRequested: URL?

        private weak var view: WKWebView?
        private var addressObservation: NSKeyValueObservation?
        private var progressObservation: NSKeyValueObservation?
        private var watchdog: Task<Void, Never>?
        private var stallWatchdog: Task<Void, Never>?
        private var didReachPage = false
        private var didReportFailure = false
        private var didReportStall = false
        private var didSignalReady = false
        private var readyFallback: Task<Void, Never>?

        /// Held here so its lifetime matches the page's; the content
        /// controller only holds a weak proxy to it.
        let leadReceiver = WebLeadReceiver()

        private let onAddressChange: (URL) -> Void
        private let onPageReady: () -> Void
        private let onFailure: () -> Void
        private let onStall: () -> Void

        init(
            onAddressChange: @escaping (URL) -> Void,
            onPageReady: @escaping () -> Void,
            onFailure: @escaping () -> Void,
            onStall: @escaping () -> Void
        ) {
            self.onAddressChange = onAddressChange
            self.onPageReady = onPageReady
            self.onFailure = onFailure
            self.onStall = onStall
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
            // Every byte that lands moves this, so it is the one signal that
            // separates "slow" from "stopped". The commit watchdog cannot tell
            // them apart — it is cancelled before the bundle even starts.
            progressObservation = view.observe(\.estimatedProgress, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.noteProgress() }
            }
        }

        func detach() {
            addressObservation?.invalidate()
            addressObservation = nil
            progressObservation?.invalidate()
            progressObservation = nil
            cancelWatchdog()
            cancelStallWatchdog()
            readyFallback?.cancel()
            readyFallback = nil
        }

        func load(_ url: URL) {
            lastRequested = url
            didReachPage = false
            didReportFailure = false
            didReportStall = false
            startWatchdog()
            log("loading \(url.absoluteString)")
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
                self?.log("watchdog fired after \(WebConfig.loadWatchdog)s")
                self?.reportFailure()
            }
        }

        private func cancelWatchdog() {
            watchdog?.cancel()
            watchdog = nil
        }

        // MARK: Stall watchdog

        /// Armed at the commit and pushed forward by every progress tick, so it
        /// only ever fires on a load that has genuinely stopped — not on the
        /// merely slow one the destination serves from a cold cache.
        private func noteProgress() {
            guard didReachPage, !didReportStall else { return }
            guard let progress = view?.estimatedProgress else { return }
            if progress >= 1 {
                cancelStallWatchdog()
            } else {
                startStallWatchdog()
            }
        }

        private func startStallWatchdog() {
            stallWatchdog?.cancel()
            stallWatchdog = Task { [weak self] in
                try? await Task.sleep(
                    nanoseconds: UInt64(WebConfig.stallWatchdog * 1_000_000_000)
                )
                guard !Task.isCancelled else { return }
                self?.reportStall()
            }
        }

        private func cancelStallWatchdog() {
            stallWatchdog?.cancel()
            stallWatchdog = nil
        }

        /// `estimatedProgress` stopping is necessary but not sufficient: a page
        /// that has finished parsing and then holds a connection open — polling,
        /// a socket, an analytics beacon — looks identical from the outside and
        /// is perfectly healthy. The document's own view of itself is the tie
        /// breaker, so the verdict is only reached once it says it is still
        /// loading. A web view that cannot answer at all is a stall by default.
        private func reportStall() {
            guard !didReportStall, !didReportFailure else { return }
            let progress = view?.estimatedProgress ?? 0
            guard let view else { return }
            view.evaluateJavaScript("document.readyState") { [weak self] state, _ in
                Task { @MainActor [weak self] in
                    guard let self, !self.didReportStall, !self.didReportFailure else { return }
                    if let state = state as? String, state == "complete" {
                        self.log("progress idle at \(progress) but document is complete — not a stall")
                        self.cancelStallWatchdog()
                        return
                    }
                    self.didReportStall = true
                    self.cancelStallWatchdog()
                    self.log("stalled at \(progress) for \(WebConfig.stallWatchdog)s")
                    view.scrollView.refreshControl?.endRefreshing()
                    self.onStall()
                }
            }
        }

        private func log(_ message: String) {
            #if DEBUG
            print("WEB nav: \(message)")
            #endif
        }

        /// `onPageReady` gates the notification prompt, so it wants a page the
        /// learner is actually looking at — normally `didFinish`. But an app that
        /// never finishes would never ask, so a commit arms a fallback.
        private func startReadyFallback() {
            readyFallback?.cancel()
            readyFallback = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                guard !Task.isCancelled else { return }
                self?.signalReady()
            }
        }

        private func signalReady() {
            guard !didSignalReady else { return }
            didSignalReady = true
            readyFallback?.cancel()
            readyFallback = nil
            onPageReady()
        }

        private func reportFailure() {
            guard !didReachPage, !didReportFailure else { return }
            didReportFailure = true
            cancelWatchdog()
            cancelStallWatchdog()
            view?.scrollView.refreshControl?.endRefreshing()
            onFailure()
        }

        // MARK: WKNavigationDelegate

        func webView(
            _ webView: WKWebView,
            didStartProvisionalNavigation navigation: WKNavigation!
        ) {
            log("started \(webView.url?.absoluteString ?? "-")")
        }

        /// The load is judged here, not at `didFinish`. A commit means the server
        /// answered and the document is being parsed — the page is alive. A
        /// single-page app then keeps fetching for a long time, and can hold the
        /// connection open indefinitely, so `didFinish` is not a deadline
        /// anything can be held to: the real destination commits in under a
        /// second and finishes well past ten.
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            log("committed \(webView.url?.absoluteString ?? "-")")

            guard !didReachPage,
                  let scheme = webView.url?.scheme?.lowercased(),
                  scheme == "http" || scheme == "https"
            else { return }

            didReachPage = true
            cancelWatchdog()
            noteAddress()
            startReadyFallback()
            startStallWatchdog()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            log("finished \(webView.url?.absoluteString ?? "-")")
            cancelStallWatchdog()
            webView.scrollView.refreshControl?.endRefreshing()
            noteAddress()
            signalReady()
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
            let ns = error as NSError
            log("failed \(ns.code) \(ns.domain) — \(ns.localizedDescription)")
            // A cancellation is usually the page redirecting over itself.
            guard ns.code != NSURLErrorCancelled else { return }
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
               let http = navigationResponse.response as? HTTPURLResponse {
                log("main-frame status \(http.statusCode) \(http.url?.absoluteString ?? "-")")
            }
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
