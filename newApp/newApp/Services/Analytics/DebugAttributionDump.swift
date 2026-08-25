//
//  DebugAttributionDump.swift
//  Alpha Academy
//
//  Everything the AppsFlyer → Pocket integration depends on, printed in one
//  block, on every DEBUG launch, without an environment variable to remember:
//
//    xcrun simctl launch --console-pty booted com.rainerhansen.globoton
//
//  It prints three times — at launch, once the ATT prompt has been answered,
//  and again the moment conversion data lands — because those are three
//  genuinely different states and the interesting failures live in the gaps
//  between them: an id that is empty at launch and populated later is healthy,
//  an id that is still empty after ATT is not.
//
//  Compiled out of release entirely. A conversion payload names the campaign
//  that bought the install, and that is not something to leave in a shipping
//  log.
//

#if DEBUG
import Foundation
import AppTrackingTransparency

enum DebugAttributionDump {

    /// The launch-time schedule. Called once from `newAppApp.init()`; the
    /// conversion callback calls `emit` directly when it fires.
    static func start() {
        emit(reason: "launch")

        Task {
            // Not a fixed sleep: the point is the transition, and ATT can be
            // answered in half a second or sit on screen for half a minute.
            // `settle` returns the moment it is answered, and gives up on its
            // own if nobody ever does.
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

        // ── SDK
        row("sdk version", AppsFlyerService.sdkVersion ?? "-")
        row("configured", "\(AnalyticsConfig.isConfigured)")
        row("started", "\(AppsFlyerService.isRunning)")
        row("dev key", redact(AnalyticsConfig.appsFlyerDevKey))
        row("apple app id", AnalyticsConfig.appleAppID.isEmpty ? "-" : AnalyticsConfig.appleAppID)
        row("ATT", attStatus)
        // All zeroes is the answer that matters here: it is the usual reason an
        // install that was bought reports as organic.
        row("IDFA", AppsFlyerService.advertisingIdentifier ?? "-")

        // ── Identity
        row("appsflyer_id", AppsFlyerService.installUID ?? "EMPTY — nothing can be attributed")
        row("customer uid", AppsFlyerService.customerUserID ?? "- (no lead id yet)")
        row("device_id", DeviceIdentity.current() ?? "-")

        // ── Conversion data
        if let conversion = AttributionStore.conversion, !conversion.isEmpty {
            let at = AttributionStore.receivedAt.map(Self.stamp) ?? "-"
            row("conversion", "\(conversion.count) forwarded, received \(at)")
            for key in conversion.keys.sorted() {
                out += "      \(key) = \(conversion[key] ?? "")\n"
            }
        } else if let failure = AttributionStore.lastFailure {
            row("conversion", "FAILED — \(failure)")
        } else {
            // Three states read identically as "no data", and only one is a
            // problem: the callback has not fired yet on this launch, it fired
            // on an earlier install lifetime and will never fire again, or it
            // genuinely failed. The wording has to keep them apart.
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

        // ── The link
        row("campaign hosts", AttributionLink.hostSuffixes.joined(separator: ", "))
        let payload = AttributionLink.parameters
        row("link params", payload.isEmpty
            ? "NONE — a campaign link would open unenriched"
            : payload.keys.sorted().joined(separator: ", "))
        if let sample = URL(string: "https://example.pocketpartners.link/registration") {
            // Built through the real `enrich`, not reassembled here: a sample
            // that takes its own path can agree with nothing.
            row("sample link", AttributionLink.enrich(sample, quiet: true).absoluteString)
        }

        // ── What the page is handed
        out += "  window.__native :\n"
        for line in WebNativeBridge.debugAttributionPayload.split(separator: "\n") {
            out += "      \(line.trimmingCharacters(in: .whitespaces))\n"
        }

        out += "AF " + String(repeating: "═", count: 58) + "\n"
        Swift.print(out)
    }

    // MARK: - Helpers

    private static var attStatus: String {
        switch ATTrackingManager.trackingAuthorizationStatus {
        case .authorized:    return "authorized"
        case .denied:        return "denied"
        case .restricted:    return "restricted"
        case .notDetermined: return "not determined — prompt not answered yet"
        @unknown default:    return "unknown"
        }
    }

    /// Enough of the key to tell two builds apart, never enough to reuse. The
    /// manual is explicit that the dev key must not reach a log.
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
