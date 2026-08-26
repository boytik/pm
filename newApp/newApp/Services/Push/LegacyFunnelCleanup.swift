import Foundation
import UserNotifications

enum LegacyFunnelCleanup {
    private static let legacyPrefix = "push."

    static func runOnce() {
        guard !DeviceRegistrationStore.didPurgeLegacyNotifications else { return }
        DeviceRegistrationStore.didPurgeLegacyNotifications = true

        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(legacyPrefix) }
            guard !ids.isEmpty else { return }
            center.removePendingNotificationRequests(withIdentifiers: ids)
            #if DEBUG
            print("PUSH device: removed \(ids.count) pending legacy push.* notification(s)")
            #endif
        }
        center.getDeliveredNotifications { notifications in
            let ids = notifications.map(\.request.identifier).filter { $0.hasPrefix(legacyPrefix) }
            guard !ids.isEmpty else { return }
            center.removeDeliveredNotifications(withIdentifiers: ids)
            #if DEBUG
            print("PUSH device: removed \(ids.count) delivered legacy push.* notification(s)")
            #endif
        }
    }
}
