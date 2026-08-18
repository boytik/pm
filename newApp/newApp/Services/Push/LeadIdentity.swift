//
//  LeadIdentity.swift
//  Alpha Academy
//
//  The single place that decides what `user_id` means. Everything downstream
//  asks this type and does not care where the value came from.
//

import Foundation
import UserNotifications

enum LeadIdentity {

    /// Prefix for every notification raised from the funnel, so it can be told
    /// apart from the `drill.*` practice reminders.
    static let notificationPrefix = "push."

    /// The identifier sent to `/userapi/user/{user_id}/push/pending`.
    ///
    /// BLOCKED (17.08.2026) — the AppsFlyer UID cannot serve as `user_id`.
    /// §6 of Pocket_Alpha_iOS_Push_API.md says `user_id` is the LEAD id minted by
    /// the backend in the `/pocket/auth/register` response, to be read from the
    /// web layer's `localStorage["tw-app-user-id"]` or obtained by logging in
    /// natively. Probing prod settles it: the path segment is parsed as an
    /// integer, so `/userapi/user/1/...` returns 200 while an AppsFlyer-shaped
    /// id returns 422 `int_parsing`. `getAppsFlyerUID()` is a hyphenated string
    /// and will never be accepted.
    ///
    /// The source stays isolated here — swapping in the web-layer bridge or a
    /// native login is a one-line change once that layer exists.
    static var rawUserID: String? {
        if let override = ProcessInfo.processInfo.environment["AA_LEAD_ID"], !override.isEmpty {
            return override
        }
        // The web layer, via `WebLeadBridge` — the only source that yields an
        // id the backend will accept. Absent until the learner has reached the
        // page and registered.
        if let bridged = WebModeStore.leadUserID, !bridged.isEmpty {
            return bridged
        }
        // Kept as the tail so `reconcile()` still has something to compare
        // against before the bridge fires. It never passes `userID`'s integer
        // check, so it disables polling rather than enabling a bad request.
        return AppsFlyerService.installUID
    }

    /// Only an integer-shaped id is worth a request. Anything else is a
    /// guaranteed 422, so it is dropped loudly here rather than turned into a
    /// steady trickle of rejected traffic against prod.
    static var userID: String? {
        guard let raw = rawUserID else { return nil }
        guard Int64(raw) != nil else {
            #if DEBUG
            print("PUSH lead id '\(raw)' is not an integer — the backend parses "
                  + "user_id as Int and would answer 422. Polling disabled.")
            #endif
            return nil
        }
        return raw
    }

    /// `X-App-Session` (§3). There is no auth layer yet, so this is nil and the
    /// header is simply omitted — prod runs the check in shadow mode today.
    /// Wire this up together with the WebView bridge or a native login.
    static var session: String? { nil }

    /// §4.5 — a changed lead means any push fetched for the previous one is
    /// stale. Drop it rather than showing someone else's funnel step.
    static func reconcile() {
        // Compares the raw value: swapping one unusable id for another is still
        // an account change, and the stale funnel push has to go either way.
        let current = rawUserID
        guard current != PushStore.lastKnownUserID else { return }

        clearFunnelNotifications()
        PushStore.clearThrottle()
        PushStore.lastKnownUserID = current

        if let current {
            AppsFlyerService.setCustomerUserID(current)
        }
    }

    static func clearFunnelNotifications() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(notificationPrefix) }
            if !ids.isEmpty { center.removePendingNotificationRequests(withIdentifiers: ids) }
        }
        center.getDeliveredNotifications { notifications in
            let ids = notifications.map(\.request.identifier)
                .filter { $0.hasPrefix(notificationPrefix) }
            if !ids.isEmpty { center.removeDeliveredNotifications(withIdentifiers: ids) }
        }
    }
}
