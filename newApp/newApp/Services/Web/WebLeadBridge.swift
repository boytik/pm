import Foundation
import WebKit

enum WebLeadBridge {
    static let handlerName = "alphaLead"

    private static let storageKey = "tw-app-user-id"

    private static let pollIntervalMs = 1000
    private static let burstWindowMs = 120_000
    private static let idleIntervalMs = 5000

    static func install(on controller: WKUserContentController, receiver: WebLeadReceiver) {
        controller.add(WeakHandlerProxy(receiver), name: handlerName)
        controller.addUserScript(
            WKUserScript(
                source: script,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
    }

    static func remove(from controller: WKUserContentController) {
        controller.removeScriptMessageHandler(forName: handlerName)
        controller.removeAllUserScripts()
    }

    private static var script: String {
        """
        (function () {
          var KEY = '\(storageKey)';
          var last = null;
          var first = true;
          function post() {
            var value = null;
            var keys = [];
            try {
              value = window.localStorage.getItem(KEY);
              for (var i = 0; i < window.localStorage.length; i++) {
                keys.push(window.localStorage.key(i));
              }
            } catch (e) { return; }
            if (value === last && !first) { return; }
            first = false;
            last = value;
            window.webkit.messageHandlers.\(handlerName).postMessage({
              id: value, keys: keys
            });
          }
          post();
          var elapsed = 0;
          var timer = setInterval(function () {
            elapsed += \(pollIntervalMs);
            post();
            if (elapsed >= \(burstWindowMs)) {
              clearInterval(timer);
              setInterval(post, \(idleIntervalMs));
            }
          }, \(pollIntervalMs));
        })();
        """
    }
}

final class WebLeadReceiver: NSObject, WKScriptMessageHandler {
    func userContentController(
        _ controller: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == WebLeadBridge.handlerName,
              let payload = message.body as? [String: Any]
        else { return }

        #if DEBUG

        if let keys = payload["keys"] as? [String] {
            print("WEB lead: localStorage keys \(keys.sorted())")
        }
        #endif

        let raw = (payload["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty else { return }
        guard raw != WebModeStore.leadUserID else { return }

        WebModeStore.leadUserID = raw

        AppsFlyerService.setCustomerUserID(raw)

        #if DEBUG
        print("WEB lead: captured user_id \(raw)")

        DebugAttributionDump.emit(reason: "lead id captured")
        #endif
    }
}

private final class WeakHandlerProxy: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) {
        self.target = target
        super.init()
    }

    func userContentController(
        _ controller: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        target?.userContentController(controller, didReceive: message)
    }
}
