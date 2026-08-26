import Foundation
import UserNotifications
import UIKit

final class PushNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PushNotificationDelegate()

    private override init() { super.init() }

    static func install() {
        let center = UNUserNotificationCenter.current()
        guard center.delegate !== shared else { return }
        center.delegate = shared
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.notification.request.trigger is UNPushNotificationTrigger else { return }

        let info = response.notification.request.content.userInfo
        let pid = info["pid"] as? String

        #if DEBUG
        print("PUSH tap: pid=\(pid ?? "-") post_id=\(info["post_id"] ?? "-") url=\(info["url"] ?? "-")")
        #endif

        guard let raw = info["url"] as? String,
              let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http"
        else { return }

        if !WebModeStore.isWebMode, let pid {
            await PushClickReporter.report(pid: pid)
        }

        await MainActor.run {
            PushRoute.shared.request(url)
        }
    }
}
