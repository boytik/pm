//
//  PushInbox.swift
//  Alpha Academy
//
//  Polls /push/pending and turns whatever comes back into a local notification.
//  Contract: Pocket_Alpha_iOS_Push_API.md §4.
//

import Foundation
import UserNotifications

@MainActor
final class PushInbox {

    static let shared = PushInbox()

    enum Trigger: String {
        case foreground
        case backgroundRefresh
    }

    /// The banner is a few lines tall; the body can be ~1000 characters. §2 puts
    /// the trimming on our side.
    private static let bodyLimit = 300

    private var isPolling = false

    private init() {}

    /// Returns `true` when a push was shown — the background task uses that to
    /// report whether the wake-up was worth anything.
    @discardableResult
    func pollIfDue(reason: Trigger, force: Bool = false) async -> Bool {
        guard !isPolling else { return false }
        guard force || PushStore.isPollDue else { return false }
        guard let userID = LeadIdentity.userID else { return false }

        // No point spending a network round trip on a push we cannot display.
        // The server counts a handed-out push as delivered (§5), so asking
        // without permission would silently burn funnel steps.
        guard await NotificationService.currentStatus() == .authorized else { return false }

        isPolling = true
        defer { isPolling = false }

        do {
            let response = try await PushAPI.fetchPending(
                userID: userID,
                session: LeadIdentity.session
            )
            // Written on every response, push or not (§2).
            PushStore.noteResponse(nextPollAfterSec: response.nextPollAfterSec)

            guard response.hasPush, let push = response.push else {
                log("\(reason.rawValue): no push (reason=\(response.reason ?? "-")), next in \(response.nextPollAfterSec)s")
                return false
            }

            await present(push)
            log("\(reason.rawValue): shown post=\(push.postID) delivery=\(push.deliveryID)")
            return true
        } catch {
            // Leave the throttle untouched so the next foreground retries.
            log("\(reason.rawValue): poll failed — \(error)")
            return false
        }
    }

    /// No client-side de-duplication: §4 states the server hands out each push
    /// exactly once, and a lead is served by exactly one channel.
    private func present(_ push: PushPayload) async {
        let content = UNMutableNotificationContent()
        content.title = push.title
        content.body = Self.trim(push.body)
        content.sound = .default
        content.userInfo = [
            "delivery_id": push.deliveryID,
            "post_id": push.postID,
            "url": push.action?.url ?? ""
        ]

        let request = UNNotificationRequest(
            identifier: LeadIdentity.notificationPrefix + push.deliveryID,
            content: content,
            trigger: nil // immediately
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    private static func trim(_ body: String) -> String {
        guard body.count > bodyLimit else { return body }
        return String(body.prefix(bodyLimit)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private func log(_ message: String) {
        #if DEBUG
        print("PUSH \(message)")
        #endif
    }
}
