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

        config.websiteDataStore = .default()

        config.preferences.javaScriptCanOpenWindowsAutomatically = true
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
                Self.openExternally(url)
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
            } else {
                decisionHandler(.cancel)
                Self.openExternally(url)
            }
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
                log: { message in
                    #if DEBUG
                    print("WEB nav: \(message)")
                    #endif
                },
                openExternally: { url, reason in
                    #if DEBUG
                    print("WEB nav: → Safari (\(reason)): \(url.absoluteString)")
                    #endif
                    Self.openExternally(url)
                }
            )
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            pushDeviceID(to: webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            pushDeviceID(to: webView)
        }

        private static func openExternally(_ url: URL) {
            UIApplication.shared.open(AttributionLink.enrich(url))
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
