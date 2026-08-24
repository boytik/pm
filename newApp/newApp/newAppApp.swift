//
//  newAppApp.swift
//  Alpha Academy
//

import SwiftUI
import UserNotifications

@main
struct newAppApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Before `AppRouter.init()` reads the saved address to pick the launch
        // phase, and that happens while the scene body is composed. An install
        // that wandered off-site under the old code would otherwise relaunch
        // straight into someone else's page.
        WebModeStore.migrateHostPolicyIfNeeded()
        #if DEBUG
        DeviceIdentity.applyQAOverrides()
        WebModeStore.applyQAOverrides()
        APNSEnvironment.logState()
        #endif
        // The notification delegate has to be in place before launch finishes,
        // otherwise a tap that cold-starts the app is delivered to nobody.
        PushNotificationDelegate.install()
        // Warms the Keychain read off the path of `WebShellView.makeUIView`,
        // which runs on the main actor while the web shell is being built.
        DeviceIdentity.current()
        // MUST stay ahead of the first `/device/register`: `appsflyer_id` is
        // only readable after `initialize`, and the launch that carries it is
        // precisely the one that matters for install attribution. The ordering
        // is guaranteed by the lifecycle — `init()` runs before
        // `didFinishLaunchingWithOptions` — not by these two lines being
        // neighbours. Do not "tidy" this into the delegate.
        AppsFlyerService.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                // AppsFlyer starts itself through its session-ready listener,
                // once per foreground cycle — nothing to do for it here.
                // The registrar throttles itself and only re-sends when the
                // last success has gone stale.
                Task { await DeviceRegistrar.registerLaunch(reason: .foreground) }
            default:
                break
            }
        }
    }
}
