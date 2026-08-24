//
//  PushWebSheet.swift
//  Alpha Academy
//
//  Where a tapped funnel push lands on a native-mode install.
//
//  Native mode has no web shell, so there is nothing to navigate. Handing the
//  URL to Safari would work and is worse: the page would arrive with none of
//  the app's cookies, no `window.__native.device_id`, and no way to report the
//  click against a session it has never established. `SFSafariViewController`
//  has the same cookie problem and cannot be injected into at all.
//
//  So the sheet hosts a plain WKWebView with the same persistent data store
//  and the same native bridge the shell uses — deliberately without the shell's
//  watchdogs and, above all, without its address bookkeeping: nothing here may
//  ever write `WebModeStore.destination`.
//

import SwiftUI
import WebKit

struct PushDestination: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct PushWebSheet: View {
    let url: URL
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Theme.bg.ignoresSafeArea()

            PushWebView(url: url)
                .padding(.top, 44)
                .ignoresSafeArea(edges: .bottom)

            HStack {
                Spacer()
                Button(action: onClose) {
                    Text("Close")
                        .font(AppFont.cardHeading)
                        .foregroundStyle(Theme.blueBright)
                        .padding(.horizontal, Theme.Space.l)
                        .padding(.vertical, Theme.Space.s)
                }
            }
            .frame(height: 44)
            .background(Theme.bg)
        }
        .preferredColorScheme(.dark)
    }
}

private struct PushWebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        // The same store the shell would use, so a session established here is
        // not thrown away.
        config.websiteDataStore = .default()
        if let deviceID = DeviceIdentity.current() {
            WebNativeBridge.install(on: config.userContentController, deviceID: deviceID)
        }

        let view = WKWebView(frame: .zero, configuration: config)
        view.allowsBackForwardNavigationGestures = true
        view.backgroundColor = UIColor(Theme.bg)
        view.isOpaque = false
        view.scrollView.backgroundColor = UIColor(Theme.bg)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        guard context.coordinator.lastRequested != url else { return }
        context.coordinator.lastRequested = url
        view.load(URLRequest(url: url))
    }

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        WebNativeBridge.remove(from: view.configuration.userContentController)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {

        var lastRequested: URL?

        /// Same rule as the shell: ours stays inside, everything else is the
        /// system's. Without it the cashier opens inside a sheet with no
        /// address bar, which is the problem this whole change is about.
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
                UIApplication.shared.open(url)
                return
            }

            // Sub-frames and requested windows are decided elsewhere, exactly
            // as in the shell.
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
            } else {
                decisionHandler(.cancel)
                UIApplication.shared.open(url)
            }
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard let url = navigationAction.request.url,
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https"
            else { return nil }

            if WebHostPolicy.isFirstParty(url) {
                webView.load(URLRequest(url: url))
            } else {
                UIApplication.shared.open(url)
            }
            return nil
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            pushDeviceID(to: webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            pushDeviceID(to: webView)
        }

        private func pushDeviceID(to webView: WKWebView) {
            guard let deviceID = DeviceIdentity.current() else { return }
            WebNativeBridge.push(to: webView, deviceID: deviceID) { result in
                #if DEBUG
                print("WEB bridge: device_id \(result)")
                #endif
            }
        }
    }
}
