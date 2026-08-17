//
//  PushNotificationDelegate.swift
//  Alpha Academy
//
//  Foreground presentation and tap handling. Without a delegate, a funnel push
//  that lands while the app is open is dropped silently, and there is nowhere to
//  hang the click report.
//

import Foundation
import UserNotifications
import UIKit

final class PushNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    static let shared = PushNotificationDelegate()

    private override init() { super.init() }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let identifier = response.notification.request.identifier
        // `drill.*` reminders just open the app, as they always have.
        guard identifier.hasPrefix(LeadIdentity.notificationPrefix) else { return }

        let info = response.notification.request.content.userInfo
        guard let deliveryID = info["delivery_id"] as? String else { return }

        // §2.2: report before opening. Idempotent, and skipping it zeroes out
        // the effectiveness stats for the whole iOS channel.
        await PushAPI.reportClick(deliveryID: deliveryID)

        // `action` may be null — then the tap simply opens the app (§2).
        guard let urlString = info["url"] as? String,
              !urlString.isEmpty,
              let url = URL(string: urlString) else { return }

        await MainActor.run {
            UIApplication.shared.open(url)
        }
    }
}
