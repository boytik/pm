//
//  TrackingAuthorization.swift
//  Alpha Academy
//
//  App Tracking Transparency. The prompt must be shown — a build that links an
//  attribution SDK without ever asking is what gets pulled at review.
//

import Foundation
import AppTrackingTransparency
import UIKit

enum TrackingAuthorization {

    static var status: ATTrackingManager.AuthorizationStatus {
        ATTrackingManager.trackingAuthorizationStatus
    }

    /// Whether the prompt has been answered — either just now, or on an earlier
    /// launch. Exposed as a plain `Bool` so call sites that only need to know
    /// "has the learner decided?" do not have to import AppTrackingTransparency.
    static var isResolved: Bool { status != .notDetermined }

    /// Requests authorization exactly once per install.
    ///
    /// The system alert is only presented while the app is `.active`. Calling
    /// this any earlier does not queue the prompt — it resolves straight to
    /// `.denied` with nothing shown, and the one chance is gone. Hence the wait.
    static func requestIfNeeded() async {
        guard status == .notDetermined else { return }
        guard await waitUntilActive() else { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    /// Waits until the learner has answered the prompt, so AppsFlyer's first
    /// session can go out with the IDFA attached if it was granted. Bounded:
    /// a stuck prompt must not hold the SDK hostage forever.
    static func settle(timeout: TimeInterval = 30) async {
        guard status == .notDetermined else { return }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, status == .notDetermined {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
    }

    /// Polls for the active state rather than observing the notification: the
    /// call site is a splash-screen `.task`, so this is at most a few ticks.
    private static func waitUntilActive(timeout: TimeInterval = 5) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await MainActor.run(body: { UIApplication.shared.applicationState == .active }) {
                return true
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return false
    }
}
