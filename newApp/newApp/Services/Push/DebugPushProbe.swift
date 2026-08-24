//
//  DebugPushProbe.swift
//  Alpha Academy
//
//  `AA_PUSH_PROBE=1` — prints everything the push integration depends on, in
//  one place, without waiting for a real push:
//
//    SIMCTL_CHILD_AA_PUSH_PROBE=1 xcrun simctl launch --console-pty booted com.rainerhansen.globoton
//
//  `AA_PUSH_PROBE=2` additionally performs a live registration round trip and
//  prints what the server said. Compiled out of release entirely.
//

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
        print("PROBE ────────────────────────────────────────────")

        guard ProcessInfo.processInfo.environment["AA_PUSH_PROBE"] == "2" else { return }
        // Deliberately bypasses the throttle: this is a diagnostic the operator
        // asked for, not a scheduled call.
        DeviceRegistrationStore.lastRegisterAt = nil
        await DeviceRegistrar.registerLaunch(reason: .launch)
    }
}
#endif
