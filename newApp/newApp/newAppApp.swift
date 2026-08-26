import SwiftUI
import UserNotifications

@main
struct newAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        WebModeStore.migrateHostPolicyIfNeeded()
        #if DEBUG
        DeviceIdentity.applyQAOverrides()
        WebModeStore.applyQAOverrides()
        AttributionStore.applyQAOverrides()
        APNSEnvironment.logState()
        #endif

        PushNotificationDelegate.install()

        DeviceIdentity.current()

        AppsFlyerService.configure()
        #if DEBUG

        DebugAttributionDump.start()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:

                Task { await DeviceRegistrar.registerLaunch(reason: .foreground) }
            default:
                break
            }
        }
    }
}
