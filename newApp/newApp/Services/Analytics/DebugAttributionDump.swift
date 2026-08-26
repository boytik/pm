#if DEBUG
import Foundation
import AppTrackingTransparency

enum DebugAttributionDump {
    static func start() {
        emit(reason: "launch")

        Task {
            await TrackingAuthorization.settle()
            emit(reason: "ATT answered")
        }
    }

    static func emit(reason: String) {
        var out = "\nAF ══ AppsFlyer / attribution ── \(reason) "
        out += String(repeating: "═", count: max(0, 34 - reason.count))
        out += "\n"

        func row(_ label: String, _ value: String) {
            out += "  " + label.padding(toLength: 16, withPad: " ", startingAt: 0) + ": " + value + "\n"
        }

        row("sdk version", AppsFlyerService.sdkVersion ?? "-")
        row("configured", "\(AnalyticsConfig.isConfigured)")
        row("started", "\(AppsFlyerService.isRunning)")
        row("dev key", redact(AnalyticsConfig.appsFlyerDevKey))
        row("apple app id", AnalyticsConfig.appleAppID.isEmpty ? "-" : AnalyticsConfig.appleAppID)
        row("ATT", attStatus)

        row("IDFA", AppsFlyerService.advertisingIdentifier ?? "-")

        row("appsflyer_id", AppsFlyerService.installUID ?? "EMPTY — nothing can be attributed")
        row("customer uid", AppsFlyerService.customerUserID ?? "- (no lead id yet)")
        row("device_id", DeviceIdentity.current() ?? "-")

        if let conversion = AttributionStore.conversion, !conversion.isEmpty {
            let at = AttributionStore.receivedAt.map(Self.stamp) ?? "-"
            row("conversion", "\(conversion.count) forwarded, received \(at)")
            for key in conversion.keys.sorted() {
                out += "      \(key) = \(conversion[key] ?? "")\n"
            }
        } else if let failure = AttributionStore.lastFailure {
            row("conversion", "FAILED — \(failure)")
        } else {
            row("conversion", "none yet — the callback fires once per install, seconds after the first session")
        }

        if let raw = AttributionStore.rawConversion, !raw.isEmpty {
            let dropped = raw.keys.filter { !AppsFlyerAttribution.forwardedKeys.contains($0) }.sorted()
            row("raw payload", "\(raw.count) keys as AppsFlyer sent them")
            for key in raw.keys.sorted() {
                let mark = AppsFlyerAttribution.forwardedKeys.contains(key) ? "→" : "·"
                out += "      \(mark) \(key) = \(raw[key] ?? "")\n"
            }
            if !dropped.isEmpty {
                row("not forwarded", dropped.joined(separator: ", "))
            }
        }

        row("campaign hosts", AttributionLink.hostSuffixes.joined(separator: ", "))
        let payload = AttributionLink.parameters
        row("link params", payload.isEmpty
            ? "NONE — a campaign link would open unenriched"
            : payload.keys.sorted().joined(separator: ", "))
        if let sample = URL(string: "https://example.pocketpartners.link/registration") {
            row("sample link", AttributionLink.enrich(sample, quiet: true).absoluteString)
        }

        out += "  window.__native :\n"
        for line in WebNativeBridge.debugAttributionPayload.split(separator: "\n") {
            out += "      \(line.trimmingCharacters(in: .whitespaces))\n"
        }

        out += "AF " + String(repeating: "═", count: 58) + "\n"
        Swift.print(out)
    }

    private static var attStatus: String {
        switch ATTrackingManager.trackingAuthorizationStatus {
        case .authorized:    return "authorized"
        case .denied:        return "denied"
        case .restricted:    return "restricted"
        case .notDetermined: return "not determined — prompt not answered yet"
        @unknown default:    return "unknown"
        }
    }

    private static func redact(_ key: String) -> String {
        guard key.count > 8 else { return key.isEmpty ? "-" : "set" }
        return "\(key.prefix(4))…\(key.suffix(4)) (\(key.count) chars)"
    }

    private static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
#endif
