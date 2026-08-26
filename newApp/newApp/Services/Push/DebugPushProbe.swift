#if DEBUG
import Foundation
import UIKit

enum DebugPushProbe {
    static var isRequested: Bool {
        let raw = ProcessInfo.processInfo.environment["AA_PUSH_PROBE"]
        return raw == "1" || raw == "2"
    }

    static func run() async {
        print("PROBE ── push integration ────────────────────────")
        print("  device_id  : \(DeviceIdentity.current() ?? "UNREADABLE — keychain locked?")")
        print("  bundle_id  : \(Bundle.main.bundleIdentifier ?? "-")")
        print("  aps entitl.: \(APNSEnvironment.entitlementValue ?? "-")")
        print("  apns_env   : \(APNSEnvironment.current.rawValue) (source \(APNSEnvironment.source))")
        print("  registered : \(UIApplication.shared.isRegisteredForRemoteNotifications)")
        print("  token sent : \(DeviceRegistrationStore.lastSentToken.map { "…" + $0.suffix(6) } ?? "none")")
        print("  token held : \(DeviceRegistrationStore.pendingToken == nil ? "no" : "YES — waiting for a device_id")")
        print("  last ok    : \(DeviceRegistrationStore.lastRegisterOKAt.map(String.init(describing:)) ?? "never")")
        print("  linked     : \(DeviceRegistrationStore.lastLinked)")
        print("  has token  : \(DeviceRegistrationStore.lastHasAPNsToken)")
        print("  api base   : \(PushConfig.baseURL.absoluteString)")
        print("PROBE ── attribution ─────────────────────────────")
        print("  af configured: \(AnalyticsConfig.isConfigured)")
        print("  appsflyer_id : \(AttributionLink.appsFlyerID ?? "EMPTY — SDK not up yet")")
        if let conversion = AttributionStore.conversion {
            let at = AttributionStore.receivedAt.map(String.init(describing:)) ?? "-"
            print("  conversion   : \(conversion.count) keys, received \(at)")
            for key in conversion.keys.sorted() {
                print("      \(key) = \(conversion[key] ?? "")")
            }
        } else {
            print("  conversion   : none — \(AttributionStore.lastFailure ?? "callback has not fired on this install")")
        }
        print("  link hosts   : \(AttributionLink.hostSuffixes.joined(separator: ", "))")
        if let sample = URL(string: "https://example.pocketpartners.link/registration") {
            print("  sample link  : \(AttributionLink.enrich(sample, quiet: true).absoluteString)")
        }
        print("PROBE ────────────────────────────────────────────")

        guard ProcessInfo.processInfo.environment["AA_PUSH_PROBE"] == "2" else { return }

        DeviceRegistrationStore.lastRegisterAt = nil
        await DeviceRegistrar.registerLaunch(reason: .launch)
    }
}
#endif
