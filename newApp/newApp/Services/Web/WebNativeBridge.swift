import Foundation
import WebKit

enum WebNativeBridge {
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

    static func remove(from controller: WKUserContentController) {
        controller.removeAllUserScripts()
    }

    static func push(to webView: WKWebView, deviceID: String, completion: ((String) -> Void)? = nil) {
        guard DeviceIdentity.isValid(deviceID) else { return }
        webView.evaluateJavaScript(pushScript(deviceID: deviceID)) { value, error in
            let result = (value as? String) ?? error.map { "error: \($0.localizedDescription)" } ?? "-"
            completion?(result)
        }
    }

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

        if lines.isEmpty {
            lines.append("if (n.attribution_ready !== true) { n.attribution_ready = false; }")
        }
        return lines.joined(separator: "\n    ")
    }

    #if DEBUG

    static var debugAttributionPayload: String { attributionAssignments() }
    #endif

    private static func jsonObjectLiteral(_ value: [String: String]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func jsLiteral(_ value: String) -> String {
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
