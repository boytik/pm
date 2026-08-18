//
//  WebLeadBridge.swift
//  Alpha Academy
//
//  Carries the lead id out of the web layer and into `LeadIdentity`, which is
//  what the Pocket Alpha push funnel needs and has never had.
//
//  Contract: Pocket_Alpha_iOS_Push_API.md §6 — `user_id` is minted by the
//  backend and the native shell reads it from `localStorage["tw-app-user-id"]`.
//  The backend parses the path segment as an integer, so nothing else will do:
//  the AppsFlyer UID is hyphenated and answers 422.
//

import Foundation
import WebKit

enum WebLeadBridge {

    static let handlerName = "alphaLead"

    /// The key the web layer stores the lead id under. Named in §6, and again in
    /// the backend's own description of `/userapi/user/attach-subid`:
    /// "tgId for bot flow, tw-app-user-id for PWA flow".
    private static let storageKey = "tw-app-user-id"

    /// Reading once is not enough: the id is minted by `/pocket/auth/register`,
    /// which the page calls after it has loaded. So the script reads, then
    /// watches — cheaply, and only for as long as it is plausible the learner is
    /// still registering.
    ///
    /// Injected at document *start*, not end. The real destination is a
    /// single-page app that holds its document open — `didFinish` never arrives
    /// and `.atDocumentEnd` scripts never run. Nothing here touches the DOM
    /// anyway: `localStorage` and `setInterval` are both available immediately.
    private static let pollIntervalMs = 1000
    private static let pollWindowMs = 120_000

    static func install(on controller: WKUserContentController, receiver: WebLeadReceiver) {
        // WKUserContentController retains message handlers strongly, and a
        // handler that reaches the web view takes the whole web content process
        // down with it. The receiver is held by the coordinator; this side holds
        // it weakly.
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
            // The first report always goes out, even with nothing stored, so
            // the key dump shows up for a page that has not registered yet.
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
            if (elapsed >= \(pollWindowMs)) { clearInterval(timer); }
            post();
          }, \(pollIntervalMs));
        })();
        """
    }
}

/// Owned by the web view's coordinator, so its lifetime matches the page's.
final class WebLeadReceiver: NSObject, WKScriptMessageHandler {

    func userContentController(
        _ controller: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == WebLeadBridge.handlerName,
              let payload = message.body as? [String: Any]
        else { return }

        #if DEBUG
        // Printed once per change, so when the real destination arrives we can
        // see exactly what the web layer stores rather than guessing — the
        // session token for `X-App-Session` is still unaccounted for.
        if let keys = payload["keys"] as? [String] {
            print("WEB lead: localStorage keys \(keys.sorted())")
        }
        #endif

        let raw = (payload["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty else { return }
        guard raw != WebModeStore.leadUserID else { return }

        WebModeStore.leadUserID = raw
        // §4.5 — a changed lead invalidates anything fetched for the previous
        // one, and this is also what hands the id to AppsFlyer.
        LeadIdentity.reconcile()

        #if DEBUG
        print("WEB lead: captured user_id \(raw)\(Int64(raw) == nil ? "  ← NOT an integer, polling stays off" : "")")
        #endif
    }
}

/// Breaks the retain cycle `WKUserContentController → handler → web view`.
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
