//
//  PushStore.swift
//  Alpha Academy
//
//  Small bit of state for the push poller. Deliberately kept out of AppState:
//  none of this is learning progress, and putting it there would mean bumping
//  the schema version and writing a migration for a poll timestamp.
//
//  `nonisolated` throughout — the background refresh task reads this off the
//  main actor, and UserDefaults is thread-safe.
//

import Foundation

enum PushStore {

    // UserDefaults is not marked Sendable but is documented as thread-safe.
    nonisolated(unsafe) private static let defaults = UserDefaults.standard
    nonisolated private static let nextPollKey = "com.alphaacademy.push.nextPollAllowedAt"
    nonisolated private static let lastUserIDKey = "com.alphaacademy.push.lastKnownUserID"

    /// Earliest moment the server is willing to be asked again. Written from
    /// `next_poll_after_sec` on every response.
    nonisolated static var nextPollAllowedAt: Date? {
        get { defaults.object(forKey: nextPollKey) as? Date }
        set { defaults.set(newValue, forKey: nextPollKey) }
    }

    nonisolated static var lastKnownUserID: String? {
        get { defaults.string(forKey: lastUserIDKey) }
        set { defaults.set(newValue, forKey: lastUserIDKey) }
    }

    nonisolated static func noteResponse(nextPollAfterSec: Int, now: Date = Date()) {
        // Guard against a zero or negative value turning into a hot loop.
        let delay = max(60, nextPollAfterSec)
        nextPollAllowedAt = now.addingTimeInterval(TimeInterval(delay))
    }

    nonisolated static var isPollDue: Bool {
        guard let next = nextPollAllowedAt else { return true }
        return Date() >= next
    }

    nonisolated static func clearThrottle() {
        defaults.removeObject(forKey: nextPollKey)
    }
}
