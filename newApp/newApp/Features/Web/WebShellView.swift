import SwiftUI
import WebKit
import Combine

struct WebShellView: View {
    let destination: URL

    @State private var currentURL: URL
    @State private var didExhaustRecovery = false

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

        .ignoresSafeArea()

        .onReceive(route.$pendingURL.compactMap { $0 }) { url in
            log("push tap → \(url.absoluteString)")
            didExhaustRecovery = false
            currentURL = url
            route.consume()
        }
    }

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

    private func stall() {
        log("load stalled past \(Int(WebConfig.stallWatchdog))s → retry screen")
        didExhaustRecovery = true
    }

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

        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        config.websiteDataStore = .default()

        WebLeadBridge.install(
            on: config.userContentController,
            receiver: context.coordinator.leadReceiver
        )

        if let deviceID = DeviceIdentity.current() {
            WebNativeBridge.install(on: config.userContentController, deviceID: deviceID)
        }

        let view = WKWebView(frame: .zero, configuration: config)
        view.allowsBackForwardNavigationGestures = true
        view.backgroundColor = UIColor(Theme.bg)
        view.isOpaque = false
        view.scrollView.backgroundColor = UIColor(Theme.bg)

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

    func updateUIView(_ view: WKWebView, context: Context) {
        guard context.coordinator.lastRequested != url else { return }
        context.coordinator.load(url)
    }

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        WebLeadBridge.remove(from: view.configuration.userContentController)
        WebNativeBridge.remove(from: view.configuration.userContentController)
        coordinator.detach()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private(set) var lastRequested: URL?

        private weak var view: WKWebView?
        private var addressObservation: NSKeyValueObservation?
        private var progressObservation: NSKeyValueObservation?
        private var attributionObserver: NSObjectProtocol?
        private var watchdog: Task<Void, Never>?
        private var stallWatchdog: Task<Void, Never>?
        private var didReachPage = false
        private var didReportFailure = false

        private var provisionalInFlight = false
        private var didReportStall = false
        private var didSignalReady = false
        private var readyFallback: Task<Void, Never>?

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

            addressObservation = view.observe(\.url, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.noteAddress() }
            }

            progressObservation = view.observe(\.estimatedProgress, options: [.new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in self?.noteProgress() }
            }

            attributionObserver = NotificationCenter.default.addObserver(
                forName: .attributionDidUpdate,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, let view = self.view else { return }
                    self.log("attribution arrived — re-pushing to the page")
                    self.pushDeviceID(to: view)
                }
            }
        }

        func detach() {
            addressObservation?.invalidate()
            addressObservation = nil
            progressObservation?.invalidate()
            progressObservation = nil
            if let attributionObserver {
                NotificationCenter.default.removeObserver(attributionObserver)
            }
            attributionObserver = nil
            cancelWatchdog()
            cancelStallWatchdog()
            readyFallback?.cancel()
            readyFallback = nil
        }

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

        private func noteAddress() {
            guard let current = view?.url,
                  let scheme = current.scheme?.lowercased(),
                  scheme == "http" || scheme == "https",
                  current.absoluteString != WebModeStore.destination?.absoluteString
            else { return }

            guard WebHostPolicy.isFirstParty(current) else {
                log("address \(current.host ?? "-") is not ours — saved address left at "
                    + "\(WebModeStore.destination?.host ?? "none")")
                return
            }

            if PushRoute.shared.shouldSuppressAddressWrite() {
                log("address from a push tap — not saved")
                return
            }

            onAddressChange(current)
        }

        private func adoptChainDestination(_ committed: URL) {
            guard let started = lastRequested,
                  WebHostPolicy.isFirstParty(started),
                  !WebHostPolicy.isFirstParty(committed)
            else { return }
            log("chain from \(started.host ?? "-") landed on \(committed.host ?? "-") — adopting as ours")
            WebModeStore.destination = committed
        }

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

        func webView(
            _ webView: WKWebView,
            didStartProvisionalNavigation navigation: WKNavigation!
        ) {
            provisionalInFlight = true
            log("started \(webView.url?.absoluteString ?? "-")")
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            provisionalInFlight = false
            log("committed \(webView.url?.absoluteString ?? "-")")

            pushDeviceID(to: webView)

            guard !didReachPage,
                  let committed = webView.url,
                  let scheme = committed.scheme?.lowercased(),
                  scheme == "http" || scheme == "https"
            else { return }

            didReachPage = true
            cancelWatchdog()
            adoptChainDestination(committed)
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

            guard ns.code != NSURLErrorCancelled else { return }

            guard !(ns.domain == "WebKitErrorDomain" && ns.code == 102) else { return }
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

            if let target = navigationAction.targetFrame, !target.isMainFrame {
                decisionHandler(.allow)
                return
            }

            guard navigationAction.targetFrame != nil else {
                decisionHandler(.allow)
                return
            }

            if WebHostPolicy.isFirstParty(url) {
                decisionHandler(.allow)
                return
            }

            switch navigationAction.navigationType {
            case .linkActivated:
                decisionHandler(.cancel)
                openExternally(url, reason: "third-party link")

            case .formSubmitted, .formResubmitted:

                if navigationAction.request.httpMethod?.uppercased() == "GET" {
                    decisionHandler(.cancel)
                    openExternally(url, reason: "third-party GET form")
                } else {
                    log("third-party POST kept inside (body would be lost) — \(url.host ?? "-")")
                    decisionHandler(.allow)
                }

            case .backForward, .reload:

                log("third-party \(Self.describe(navigationAction.navigationType)) kept inside — \(url.host ?? "-")")
                decisionHandler(.allow)

            default:

                if isResolvingLoad {
                    log("third-party redirect kept inside (chain in flight) — \(url.host ?? "-")")
                    decisionHandler(.allow)
                } else {
                    decisionHandler(.cancel)
                    openExternally(url, reason: "third-party scripted navigation")
                }
            }
        }

        private func openExternally(_ url: URL, reason: String) {
            let target = AttributionLink.enrich(url)
            log("→ Safari (\(reason)): \(target.absoluteString)")
            UIApplication.shared.open(target, options: [:]) { [weak self] opened in
                guard !opened else { return }
                self?.log("→ Safari FAILED, nothing opened: \(target.absoluteString)")
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
