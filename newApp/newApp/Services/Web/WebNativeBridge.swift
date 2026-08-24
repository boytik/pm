//
//  WebNativeBridge.swift
//  Alpha Academy
//
//  Hands the native `device_id` to the page, which is how the backend learns
//  which lead owns this handset: the native layer knows the APNs token but not
//  the lead, the page knows the lead but nothing about the device, and
//  `device_id` is the only thing both can see.
//
//  There is deliberately no `WKScriptMessageHandler` here. This bridge only
//  pushes a constant, and `evaluateJavaScript`'s completion is a better
//  acknowledgement than a message would be — it distinguishes "the page never
//  defined the hook" from "the page defined it and ignored the value". If one
//  is ever added: `WKUserContentController` retains handlers STRONGLY, and a
//  handler that can reach the web view takes the whole web content process down
//  with it. Add it through a weak proxy.
//

import Foundation
import WebKit

enum WebNativeBridge {

    /// Injected at document *start*, main frame only.
    ///
    /// Start, because the id has to be readable before the page issues its
    /// first request — and because the real destination is a single-page app
    /// that holds its document open, so `.atDocumentEnd` scripts never run on
    /// it at all.
    ///
    /// Main frame only is a privacy decision, not a performance one: a
    /// `window.__native` inside a third-party iframe hands the device id to an
    /// ad network or a chat widget that has no business with it.
    ///
    /// A `WKUserScript` is injected by the engine rather than parsed out of the
    /// document, so the page's Content-Security-Policy cannot suppress it.
    static func install(on controller: WKUserContentController, deviceID: String) {
        guard DeviceIdentity.isValid(deviceID) else {
            log("device id is not contract-shaped — not injecting")
            return
        }
        controller.addUserScript(
            WKUserScript(
                source: documentStartScript(deviceID: deviceID),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
    }

    /// `removeAllUserScripts()` is the only removal WebKit offers, so this and
    /// any other bridge on the same controller come off together. Harmless at
    /// teardown; worth knowing before adding a third.
    static func remove(from controller: WKUserContentController) {
        controller.removeAllUserScripts()
    }

    /// Belt and braces for the second mechanism the spec offers,
    /// `window.twSetNativeDeviceId(id)`. At document start the page's own
    /// bundle has not run, so the function almost never exists yet — which is
    /// the whole reason this call is made again once the document is up.
    ///
    /// Idempotency is a marker on `window`, never a Swift flag: `window` is
    /// per-document, so a real navigation resets it and the next document
    /// legitimately gets its own call. A native flag would suppress every
    /// document after the first — the bug nobody notices until a lead registers
    /// on page two of the funnel.
    static func push(to webView: WKWebView, deviceID: String, completion: ((String) -> Void)? = nil) {
        guard DeviceIdentity.isValid(deviceID) else { return }
        webView.evaluateJavaScript(pushScript(deviceID: deviceID)) { value, error in
            let result = (value as? String) ?? error.map { "error: \($0.localizedDescription)" } ?? "-"
            completion?(result)
        }
    }

    // MARK: - Scripts

    private static func documentStartScript(deviceID: String) -> String {
        """
        (function () {
          var ID = \(jsLiteral(deviceID));
          try {
            var n = window.__native || (window.__native = {});
            n.device_id = ID;
            n.platform = 'ios';
          } catch (e) {}
          try {
            if (typeof window.twSetNativeDeviceId === 'function') {
              window.__native.__delivered = ID;
              window.twSetNativeDeviceId(ID);
            }
          } catch (e) {}
        })();
        """
    }

    private static func pushScript(deviceID: String) -> String {
        """
        (function () {
          var ID = \(jsLiteral(deviceID));
          var n = window.__native || (window.__native = {});
          n.device_id = ID;
          n.platform = 'ios';
          if (n.__delivered === ID) { return 'already'; }
          if (typeof window.twSetNativeDeviceId !== 'function') { return 'absent'; }
          n.__delivered = ID;
          try { window.twSetNativeDeviceId(ID); } catch (e) { return 'threw: ' + e; }
          return 'called';
        })()
        """
    }

    /// A real JS string literal, quotes included. `DeviceIdentity.isValid`
    /// already excludes quotes and backslashes, but hand-interpolation is the
    /// kind of assumption that outlives the format it was safe for.
    private static func jsLiteral(_ value: String) -> String {
        // Wrapped in an array because a top-level JSON string fragment is not
        // portable across Foundation versions.
        guard let data = try? JSONSerialization.data(withJSONObject: [value]),
              let json = String(data: data, encoding: .utf8),
              json.count >= 2
        else { return "\"\"" }
        return String(json.dropFirst().dropLast())
    }

    private static func log(_ message: String) {
        #if DEBUG
        print("WEB bridge: \(message)")
        #endif
    }
}
