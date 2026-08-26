import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        PushNotificationDelegate.install()

        let deviceID = DeviceIdentity.current()

        LegacyFunnelCleanup.runOnce()

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

        print("PUSH apns: registration failed — \(error.localizedDescription)")
        #endif
    }
}
