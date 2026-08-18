//
//  newAppApp.swift
//  Alpha Academy
//

import SwiftUI
import UserNotifications

@main
struct newAppApp: App {

    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        // Has to land before `AppRouter.init()` reads the decision to pick the
        // launch phase, and that happens while the scene body is composed.
        WebModeStore.applyQAOverrides()
        #endif
        // The notification delegate has to be in place before launch finishes,
        // otherwise a tap that cold-starts the app is delivered to nobody.
        UNUserNotificationCenter.current().delegate = PushNotificationDelegate.shared
        AppsFlyerService.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .backgroundTask(.appRefresh(PushBackgroundRefresh.identifier)) {
            await PushInbox.shared.pollIfDue(reason: .backgroundRefresh)
            // One-shot task: without this there is no next wake-up.
            PushBackgroundRefresh.schedule()
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                // AppsFlyer starts itself through its session-ready listener,
                // once per foreground cycle — nothing to do for it here.
                LeadIdentity.reconcile()
                Task { await PushInbox.shared.pollIfDue(reason: .foreground) }
            case .background:
                PushBackgroundRefresh.schedule()
            default:
                break
            }
        }
    }
}
