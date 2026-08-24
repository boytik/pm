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
import Combine

struct WebShellView: View {
    let destination: URL

    @State private var currentURL: URL
    @State private var didExhaustRecovery = false
    /// One rescue per app session, on top of the lifetime request budget.
    @State private var didTryRescue = false

    @ObservedObject private var route = PushRoute.shared

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
        // A tapped push. `@Published` replays its current value to every new
        // subscriber, so this covers the cold-start tap — where the delegate
        // publishes before this view first appears — with the same one line as
        // the warm one. Reloading the live web view rather than rebuilding it
        // keeps the cookies, the content process and the boot the learner has
        // already paid for.
        .onReceive(route.$pendingURL.compactMap { $0 }) { url in
            log("push tap → \(url.absoluteString)")
            didExhaustRecovery = false      // a tap must escape the retry screen
            currentURL = url
            route.consume()
        }
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
    /// never runs in web mode, and an APNs alert cannot be displayed without
    /// it. Held until the page has actually rendered, so it does not stack on
    /// top of a modal the page may raise itself.
    ///
    /// The device is registered for remote notifications at launch regardless,
    /// so a learner who declines here still has a token on file — only the
    /// display is withheld.
    private func askForNotificationsIfNeeded() {
        guard !WebModeStore.didAskPush else { return }
        WebModeStore.didAskPush = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            let granted = await NotificationService.requestAuthorization()
            log("notification permission \(granted ? "granted" : "refused")")
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
        // Off by default, and that default is what made "Deposit" do nothing:
        // the front end opens the cashier with `window.open` AFTER a server
        // round trip, by which point the tap's gesture is spent and WebKit's
        // popup blocker discards the call without ever asking the UI delegate.
        // Turning it on does not mean the page gets to open windows — it means
        // the request reaches `createWebViewWith`, where we decide. Requests
        // from sub-frames are refused there, so an ad cannot use this.
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        // The default, persistent store: a funnel login has to survive relaunch.
        config.websiteDataStore = .default()
        // Lifts `localStorage["tw-app-user-id"]` out of the page — the only
        // source of a `user_id` the push backend accepts (§6 of the push spec).
        WebLeadBridge.install(
            on: config.userContentController,
            receiver: context.coordinator.leadReceiver
        )
        // Hands `window.__native.device_id` to the page — the only way the
        // backend can tell which lead owns this handset (§2 of the push spec).
        if let deviceID = DeviceIdentity.current() {
            WebNativeBridge.install(on: config.userContentController, deviceID: deviceID)
        }

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
        // Both call `removeAllUserScripts()`, so order does not matter — but
        // both are called, so neither is silently relied on to clean the other.
        WebLeadBridge.remove(from: view.configuration.userContentController)
        WebNativeBridge.remove(from: view.configuration.userContentController)
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
        /// True from the moment a main-frame load starts until it commits or
        /// fails. A policy decision that arrives inside that window is a hop in
        /// a redirect chain, not something the page decided to do on its own.
        private var provisionalInFlight = false
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

        /// The initial resolution of a load *we* asked for. `didReachPage` is
        /// only reset by `load(_:)`, so this is true exactly once per
        /// shell-initiated load and never again while the page navigates itself.
        private var isResolvingLoad: Bool { provisionalInFlight || !didReachPage }

        func load(_ url: URL) {
            lastRequested = url
            didReachPage = false
            didReportFailure = false
            didReportStall = false
            provisionalInFlight = true
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

            // The saved address is what the next cold launch opens *and* what
            // the allowlist is built from, so an address that is not already
            // ours can never be written here. Without this guard one visit to
            // the cashier makes the app relaunch into Pocket Option — and then
            // whitelists it, disabling the bounce that would have prevented it.
            guard WebHostPolicy.isFirstParty(current) else {
                log("address \(current.host ?? "-") is not ours — saved address left at "
                    + "\(WebModeStore.destination?.host ?? "none")")
                return
            }

            // A push URL carries `?pid=…`. Letting it become the saved address
            // would make every future cold launch look like a click on a stale
            // push, permanently.
            if PushRoute.shared.shouldSuppressAddressWrite() {
                log("address from a push tap — not saved")
                return
            }

            onAddressChange(current)
        }

        /// The allowlist grows in exactly one place: the end of a redirect
        /// chain that *we* started from an address that was already ours. This
        /// is the same trust `WebGate.decide()` extends when it follows the
        /// cloaker to the funnel and hands `http.url` to `commitWeb`.
        ///
        /// Without it, an install whose saved address is still the raw
        /// configured one — which is every install that has ever used the
        /// `pathid` rescue — would treat the funnel it lands on as third-party
        /// and throw the entire product out to Safari.
        private func adoptChainDestination(_ committed: URL) {
            guard let started = lastRequested,
                  WebHostPolicy.isFirstParty(started),
                  !WebHostPolicy.isFirstParty(committed)
            else { return }
            log("chain from \(started.host ?? "-") landed on \(committed.host ?? "-") — adopting as ours")
            WebModeStore.destination = committed
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
            provisionalInFlight = true
            log("started \(webView.url?.absoluteString ?? "-")")
        }

        /// The load is judged here, not at `didFinish`. A commit means the server
        /// answered and the document is being parsed — the page is alive. A
        /// single-page app then keeps fetching for a long time, and can hold the
        /// connection open indefinitely, so `didFinish` is not a deadline
        /// anything can be held to: the real destination commits in under a
        /// second and finishes well past ten.
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            provisionalInFlight = false
            log("committed \(webView.url?.absoluteString ?? "-")")

            // Not just at `didFinish`: this destination is a single-page app
            // that may never fire it.
            pushDeviceID(to: webView)

            guard !didReachPage,
                  let committed = webView.url,
                  let scheme = committed.scheme?.lowercased(),
                  scheme == "http" || scheme == "https"
            else { return }

            didReachPage = true
            cancelWatchdog()
            adoptChainDestination(committed)   // before noteAddress, which then no-ops
            noteAddress()
            startReadyFallback()
            startStallWatchdog()
        }

        private func pushDeviceID(to webView: WKWebView) {
            guard let deviceID = DeviceIdentity.current() else { return }
            WebNativeBridge.push(to: webView, deviceID: deviceID) { result in
                #if DEBUG
                print("WEB bridge: device_id \(result)")
                #endif
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            provisionalInFlight = false
            log("finished \(webView.url?.absoluteString ?? "-")")
            pushDeviceID(to: webView)
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
            provisionalInFlight = false
            let ns = error as NSError
            log("failed \(ns.code) \(ns.domain) — \(ns.localizedDescription)")
            // A cancellation is usually the page redirecting over itself.
            guard ns.code != NSURLErrorCancelled else { return }
            // And code 102 is how a `.cancel` policy decision surfaces. A link
            // bounced to Safari before the page committed is not a load
            // failure, and treating it as one would spend the one `pathid`
            // rescue on a page that is perfectly healthy.
            guard !(ns.domain == "WebKitErrorDomain" && ns.code == 102) else { return }
            guard !didReachPage else { return }
            reportFailure()
        }

        /// Our host stays inside; everything else goes to the system browser.
        ///
        /// The pages this exists for — the Pocket cashier, its registration —
        /// are laid out for a normal browser, and this shell has no address
        /// bar, no back button and no safe area, so a third-party header slides
        /// under the notch. Handing them to Safari also keeps the learner's
        /// existing Pocket session, autofill and password manager, which an
        /// in-app browser with its own cookie jar would not.
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

            // 1. Schemes a web view cannot load at all — tg:, mailto:, tel:.
            //    Decided before the frame checks on purpose: a `target="_blank"`
            //    link to `tg://` has to be cancelled here, or WebKit goes on to
            //    ask for a window that will never be used. about/blob/data are
            //    the page's own plumbing (`about:blank` is what WebKit hands
            //    `window.open`) and UIApplication can do nothing with either.
            switch scheme {
            case "http", "https":
                break
            case "about", "blob", "data", "file":
                decisionHandler(.allow)
                return
            default:
                decisionHandler(.cancel)
                openExternally(url, reason: "scheme \(scheme)")
                return
            }

            // 2. Sub-frames never bounce. An ad, a chat widget, a payment or
            //    captcha iframe is third-party by host and entirely legitimate;
            //    sending one to Safari empties the frame and opens a browser on
            //    a fragment of a page. `targetFrame`, not `sourceFrame`: a link
            //    inside an iframe with `target="_top"` aims at the main frame
            //    and has to be judged as a main-frame navigation.
            if let target = navigationAction.targetFrame, !target.isMainFrame {
                decisionHandler(.allow)
                return
            }

            // 3. A request for a new window — `target="_blank"` or
            //    `window.open`. Allowed only so WebKit goes on to ask
            //    `createWebViewWith`, which is the one place this case is
            //    decided. Deciding it here as well opens Safari twice.
            guard navigationAction.targetFrame != nil else {
                decisionHandler(.allow)
                return
            }

            // 4. Main frame, ours.
            if WebHostPolicy.isFirstParty(url) {
                decisionHandler(.allow)
                return
            }

            // 5. Main frame, someone else's.
            switch navigationAction.navigationType {
            case .linkActivated:
                decisionHandler(.cancel)
                openExternally(url, reason: "third-party link")

            case .formSubmitted, .formResubmitted:
                // Only a GET form survives being rebuilt as a URL. Bouncing a
                // POST drops the body and lands the learner on a page with no
                // idea what they filled in — worse than the notch.
                if navigationAction.request.httpMethod?.uppercased() == "GET" {
                    decisionHandler(.cancel)
                    openExternally(url, reason: "third-party GET form")
                } else {
                    log("third-party POST kept inside (body would be lost) — \(url.host ?? "-")")
                    decisionHandler(.allow)
                }

            case .backForward, .reload:
                // Revisiting something already reached. Bouncing here breaks the
                // edge swipe, which is the only back button this shell has.
                log("third-party \(Self.describe(navigationAction.navigationType)) kept inside — \(url.host ?? "-")")
                decisionHandler(.allow)

            default:
                // `.other`: a server 3xx, a meta refresh, or `location.href = …`.
                // While a load of ours is still resolving, this is the cloaking
                // chain — and the only way an install finds the funnel again
                // after it moves domain. Bouncing that would send the shell to
                // Safari on every launch and leave `WebRetryView` behind,
                // permanently. Once the page has settled the same type means the
                // page is acting, and it bounces.
                if isResolvingLoad {
                    log("third-party redirect kept inside (chain in flight) — \(url.host ?? "-")")
                    decisionHandler(.allow)
                } else {
                    decisionHandler(.cancel)
                    openExternally(url, reason: "third-party scripted navigation")
                }
            }
        }

        /// `UIApplication.shared.open` — the real Safari, not
        /// `SFSafariViewController`. The latter has its own storage, so a lead
        /// already signed in to Pocket in Safari arrives at the cashier logged
        /// out: one more step in the flow that matters most.
        ///
        /// `open` rather than `canOpenURL`: the latter needs every scheme
        /// declared in `LSApplicationQueriesSchemes`, this needs nothing. The
        /// completion handler is not decoration — `tg://` with Telegram absent
        /// returns false and does nothing at all, which is indistinguishable
        /// from the bug this whole change exists to fix.
        private func openExternally(_ url: URL, reason: String) {
            log("→ Safari (\(reason)): \(url.absoluteString)")
            UIApplication.shared.open(url, options: [:]) { [weak self] opened in
                guard !opened else { return }
                self?.log("→ Safari FAILED, nothing opened: \(url.absoluteString)")
            }
        }

        private static func describe(_ type: WKNavigationType) -> String {
            switch type {
            case .linkActivated:   return "linkActivated"
            case .formSubmitted:   return "formSubmitted"
            case .backForward:     return "backForward"
            case .reload:          return "reload"
            case .formResubmitted: return "formResubmitted"
            case .other:           return "other"
            @unknown default:      return "unknown(\(type.rawValue))"
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

        /// The one the front end actually uses: the cashier and the
        /// registration are opened with `target="_blank"`. WKWebView creates no
        /// window on its own, so without this method the learner taps "Deposit"
        /// and literally nothing happens. `WebWindowPolicy` covers the three
        /// shapes that request can take — see its header.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            WebWindowPolicy.newWindow(
                parent: webView,
                configuration: configuration,
                for: navigationAction,
                log: { [weak self] in self?.log($0) },
                openExternally: { [weak self] url, reason in
                    self?.openExternally(url, reason: reason)
                }
            )
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
