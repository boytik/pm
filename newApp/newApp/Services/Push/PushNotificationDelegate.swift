//
//  PushNotificationDelegate.swift
//  Alpha Academy
//
//  Foreground presentation and tap handling for the APNs funnel.
//
//  The two kinds of notification in this app share one centre: server-sent
//  funnel pushes, and the local `drill.*` practice reminders. They are told
//  apart by trigger type, not by identifier — a remote push's identifier is
//  whatever `apns-collapse-id` the server chose (`post-<id>` today) or an
//  opaque UUID when it chose none, and neither is ours to rely on.
//

import Foundation
import UserNotifications
import UIKit

final class PushNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    static let shared = PushNotificationDelegate()

    private override init() { super.init() }

    /// Idempotent, because it is called from both `newAppApp.init()` and
    /// `application(_:didFinishLaunchingWithOptions:)`. The requirement is only
    /// that it happen before launch finishes — a tap that cold-starts the app
    /// is otherwise delivered to nobody — and both sites are before that.
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
        // `drill.*` reminders carry a calendar trigger and have always done one
        // thing: open the app. Falling through preserves that exactly.
        guard response.notification.request.trigger is UNPushNotificationTrigger else { return }

        let info = response.notification.request.content.userInfo
        let pid = info["pid"] as? String

        #if DEBUG
        print("PUSH tap: pid=\(pid ?? "-") post_id=\(info["post_id"] ?? "-") url=\(info["url"] ?? "-")")
        #endif

        // A push with no action URL just opens the app.
        guard let raw = info["url"] as? String,
              let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http"
        else { return }

        // In web mode the URL already carries `pid` and the page reports the
        // click itself. In a native install the page has never run here, so
        // there is nothing to assume — report it ourselves. Idempotent either
        // way, so a duplicate costs nothing and a miss zeroes out the funnel.
        if !WebModeStore.isWebMode, let pid {
            await PushClickReporter.report(pid: pid)
        }

        await MainActor.run {
            PushRoute.shared.request(url)
        }
    }
}
