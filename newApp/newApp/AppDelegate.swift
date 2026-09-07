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

    // The plist declares portrait only, but a plist is advisory: a modal, a
    // media player or any UIViewController that overrides
    // supportedInterfaceOrientations can still rotate the window. This is the
    // authoritative answer for every window the app owns.
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        .portrait
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
