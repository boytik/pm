//
//  PushBackgroundRefresh.swift
//  Alpha Academy
//
//  BGAppRefreshTask plumbing. Registration itself is handled by the SwiftUI
//  `.backgroundTask(.appRefresh(_:))` modifier on the Scene — this type only
//  owns the identifier and the resubmission.
//
//  OPEN QUESTION (17.08.2026): background polling is still under review — see
//  "Open questions" in CLAUDE.md. If it is dropped, delete this file along with
//  UIBackgroundModes/BGTaskSchedulerPermittedIdentifiers in Info.plist and the
//  `.backgroundTask` modifier in newAppApp.swift. Nothing else depends on it:
//  foreground polling stands on its own.
//

import Foundation
import BackgroundTasks

enum PushBackgroundRefresh {

    /// Must match BGTaskSchedulerPermittedIdentifiers in Info.plist.
    nonisolated static let identifier = "j.newApp.push.refresh"

    /// Submit on entering the background and again at the end of every run —
    /// a BGAppRefreshTask is one-shot, it does not repeat by itself.
    ///
    /// §5 of the spec is honest about the payoff: iOS decides when to wake a
    /// rarely-opened app, and that can be a handful of times a day. This is a
    /// best-effort supplement to foreground polling, not a schedule.
    nonisolated static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = PushStore.nextPollAllowedAt ?? Date().addingTimeInterval(900)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Throws in the simulator and when the user has disabled background
            // refresh. Neither is actionable.
            #if DEBUG
            print("PUSH background schedule failed — \(error)")
            #endif
        }
    }
}
