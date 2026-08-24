//
//  AppDelegate.swift
//  Alpha Academy
//
//  Exists for exactly one reason: `didRegisterForRemoteNotificationsWithDeviceToken`
//  has no SwiftUI equivalent. Everything else the app does at launch stays in
//  `newAppApp.init()`, which runs first.
//

import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        // Belt for the adaptor: `newAppApp.init()` has already done this, and
        // the call is idempotent. A tap that cold-starts the app is delivered
        // to whoever is the delegate when launch finishes.
        PushNotificationDelegate.install()

        // Before registering, not after: the token callback can arrive within
        // milliseconds and has nothing to send without an id. `newAppApp.init()`
        // has already warmed this, so it is a cache hit.
        let deviceID = DeviceIdentity.current()

        // Local notifications the old pull funnel left behind on upgraded
        // installs. Scoped to `push.*` — `drill.0…6` share this centre.
        LegacyFunnelCleanup.runOnce()

        // Unconditional, on every launch. This does NOT require notification
        // permission — permission governs whether an arriving alert is shown,
        // not whether a token is issued — and Apple does not guarantee the
        // token is stable across restores, OS updates or reinstalls. Gating it
        // on the permission prompt would be much worse than it sounds: in web
        // mode that prompt fires 4–34s after launch and only once per install,
        // and in native mode only at the end of onboarding.
        application.registerForRemoteNotifications()

        if deviceID != nil {
            Task { await DeviceRegistrar.registerLaunch(reason: .launch) }
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { await DeviceRegistrar.registerAPNsToken(deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        // The two you will actually see: a missing or stale `aps-environment`
        // entitlement (rebuild after regenerating the profile), and a network
        // error. iOS retries on its own schedule; a client-side loop here
        // achieves nothing.
        print("PUSH apns: registration failed — \(error.localizedDescription)")
        #endif
    }
}
