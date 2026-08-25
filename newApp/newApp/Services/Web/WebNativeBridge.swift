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
            \(attributionAssignments())
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
          \(attributionAssignments())
          if (n.__delivered === ID) { return 'already'; }
          if (typeof window.twSetNativeDeviceId !== 'function') { return 'absent'; }
          n.__delivered = ID;
          try { window.twSetNativeDeviceId(ID); } catch (e) { return 'threw: ' + e; }
          return 'called';
        })()
        """
    }

    // MARK: - Attribution

    /// The AppsFlyer half of `window.__native`, so the front end can build the
    /// Pocket campaign link itself — step 4 of the tracking manual.
    ///
    /// The native side appends the same parameters in `AttributionLink` on the
    /// way out, and a parameter the page has already set wins there, so the two
    /// paths compose instead of fighting. This one exists because only the page
    /// knows which of its links is the campaign link.
    ///
    /// Emitted as assignments rather than one `Object.assign`, so an absent
    /// value leaves any earlier one in place rather than replacing it with
    /// `undefined`: `install()` runs at document start, when the conversion
    /// callback has usually not fired yet, and `push()` runs again later when
    /// it has. Overwriting on every push would make a page that read the value
    /// early see it disappear.
    private static func attributionAssignments() -> String {
        var lines: [String] = []
        if let id = AttributionLink.appsFlyerID, !id.isEmpty {
            lines.append("n.appsflyer_id = \(jsLiteral(id));")
        }
        if let conversion = AttributionStore.conversion, !conversion.isEmpty,
           let json = jsonObjectLiteral(conversion) {
            lines.append("n.conversion_data = \(json);")
            lines.append("n.attribution_ready = true;")
        }
        // Nothing to say yet — but the key must exist, or a page cannot tell
        // "no native wrapper" from "wrapper present, data not in yet".
        if lines.isEmpty {
            lines.append("if (n.attribution_ready !== true) { n.attribution_ready = false; }")
        }
        return lines.joined(separator: "\n    ")
    }

    #if DEBUG
    /// Exactly what `install()` and `push()` assign onto `window.__native`,
    /// verbatim. Printed rather than described: a dump that paraphrases the
    /// injected script is a dump that can disagree with it.
    static var debugAttributionPayload: String { attributionAssignments() }
    #endif

    private static func jsonObjectLiteral(_ value: [String: String]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        else { return nil }
        return String(data: data, encoding: .utf8)
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
