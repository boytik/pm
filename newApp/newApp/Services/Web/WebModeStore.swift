//
//  WebModeStore.swift
//  Alpha Academy
//
//  Where the web-mode decision lives. A namespace over
//  UserDefaults, one key per fact, no observable state — the decision is read
//  once per launch, in `AppRouter.init()`, before the first frame is composed.
//

import Foundation

enum WebDecision: String {
    case web
    case native
}

enum WebModeStore {

    // UserDefaults is not marked Sendable but is documented as thread-safe.
    nonisolated(unsafe) private static let defaults = UserDefaults.standard

    nonisolated private static let decisionKey = "com.alphaacademy.web.decision"
    nonisolated private static let destinationKey = "com.alphaacademy.web.destination"
    nonisolated private static let pathIDKey = "com.alphaacademy.web.pathID"
    nonisolated private static let hubRequestsKey = "com.alphaacademy.web.hubRequests"
    nonisolated private static let lastHubAtKey = "com.alphaacademy.web.lastHubAt"
    nonisolated private static let leadUserIDKey = "com.alphaacademy.web.leadUserID"
    nonisolated private static let didAskPushKey = "com.alphaacademy.web.didAskPush"
    nonisolated private static let hostPolicyMigratedKey = "com.alphaacademy.web.hostPolicyMigrated"

    // MARK: - The decision

    /// `nil` until the gate has run. Once set it is never cleared outside of
    /// `reset()`, which only exists in DEBUG — hence "forever".
    nonisolated static var decision: WebDecision? {
        defaults.string(forKey: decisionKey).flatMap(WebDecision.init(rawValue:))
    }

    /// The address the shell loads: the final URL the destination redirected to,
    /// kept fresh as the page navigates itself.
    nonisolated static var destination: URL? {
        get {
            guard let raw = defaults.string(forKey: destinationKey) else { return nil }
            return URL(string: raw)
        }
        set {
            if let newValue {
                defaults.set(newValue.absoluteString, forKey: destinationKey)
                log("saved address updated: \(newValue.absoluteString)")
            } else {
                defaults.removeObject(forKey: destinationKey)
                log("saved address cleared")
            }
        }
    }

    nonisolated static var pathID: String? {
        get { defaults.string(forKey: pathIDKey) }
        set { defaults.set(newValue, forKey: pathIDKey) }
    }

    /// The lead id lifted out of the web layer by `WebLeadBridge`, and the only
    /// source of a `user_id` the push backend will accept. Survives the page,
    /// so the funnel keeps polling on launches that never reach the web view.
    nonisolated static var leadUserID: String? {
        get { defaults.string(forKey: leadUserIDKey) }
        set {
            defaults.set(newValue, forKey: leadUserIDKey)
            log("lead user_id: \(newValue ?? "cleared")")
        }
    }

    /// Notification permission is asked at the end of native onboarding, which
    /// a web-mode learner never sees. Without it an APNs alert cannot be
    /// displayed, so the shell asks once instead — this is the flag that keeps
    /// it to once.
    nonisolated static var didAskPush: Bool {
        get { defaults.bool(forKey: didAskPushKey) }
        set { defaults.set(newValue, forKey: didAskPushKey) }
    }

    nonisolated static var isWebMode: Bool {
        decision == .web && destination != nil
    }

    nonisolated static func commitWeb(destination url: URL, pathID id: String?) {
        destination = url
        if let id, !id.isEmpty { pathID = id }
        defaults.set(WebDecision.web.rawValue, forKey: decisionKey)
        log("decision committed: WEB")
        log("  saved address: \(url.absoluteString)")
        log("  saved \(WebConfig.pathParameterName): \(pathID ?? "none")")
    }

    nonisolated static func commitNative() {
        defaults.set(WebDecision.native.rawValue, forKey: decisionKey)
        log("decision committed: NATIVE — this install stays native")
    }

    // MARK: - The request budget

    /// Hard-capped at `WebConfig.maxHubRequests` for the lifetime of the install.
    nonisolated static var hubRequests: Int {
        defaults.integer(forKey: hubRequestsKey)
    }

    nonisolated static var mayRequestHub: Bool {
        guard hubRequests < WebConfig.maxHubRequests else { return false }
        guard let last = defaults.object(forKey: lastHubAtKey) as? Date else { return true }
        return Date().timeIntervalSince(last) >= WebConfig.retryCooldown
    }

    /// Counted before the request goes out, not after: a request that times out
    /// still spent the budget.
    nonisolated static func noteHubRequest(now: Date = Date()) {
        defaults.set(hubRequests + 1, forKey: hubRequestsKey)
        defaults.set(now, forKey: lastHubAtKey)
    }

    // MARK: - Host policy migration

    /// One-time, on the first launch after `WebHostPolicy` shipped.
    ///
    /// Until then `noteAddress()` wrote down whatever the page navigated to,
    /// and `createWebViewWith` loaded `target="_blank"` links over the top of
    /// the shell. So a learner who tapped "Deposit" left the funnel in the main
    /// frame, the cashier's address was saved here, and `AppRouter.init()` has
    /// been launching that install straight into someone else's checkout ever
    /// since — before the first frame, permanently.
    ///
    /// Left alone, such an address would also seed the allowlist and disable
    /// the very bounce that fixes it.
    ///
    /// Conditional rather than blanket: the ordinary cases (an address on the
    /// funnel, the raw configured address) are already correct and are not
    /// disturbed. Re-derived to the configured seed rather than to nothing,
    /// because the next load then runs the redirect chain and the shell relearns
    /// the real funnel host on that same launch. Costs one chain and spends no
    /// hub request — that budget governs `URLSession` probes, not page loads.
    nonisolated static func migrateHostPolicyIfNeeded() {
        guard !defaults.bool(forKey: hostPolicyMigratedKey) else { return }
        defaults.set(true, forKey: hostPolicyMigratedKey)

        guard decision == .web, let saved = destination else { return }
        // Deliberately `isConfiguredFirstParty`, not `isFirstParty`: the full
        // allowlist is built partly *from* the saved address, so asking it
        // whether the saved address is ours always answers yes. That circularity
        // is exactly what let a Pocket address entrench itself.
        guard !WebHostPolicy.isConfiguredFirstParty(saved) else { return }

        let rederived = WebGate.rebuiltURL() ?? WebConfig.destinationURL
        log("saved address \(saved.host ?? "-") is outside the allowlist — re-derived")
        destination = rederived
    }

    // MARK: - QA

    nonisolated private static func log(_ message: String) {
        #if DEBUG
        print("WEB store: \(message)")
        #endif
    }

    #if DEBUG
    /// Printed once per launch, before anything acts on it, so the console shows
    /// which branch the app is about to take and what it will load.
    nonisolated static func logState() {
        print("WEB store ── state at launch ─────────────────────")
        print("  decision   : \(decision?.rawValue.uppercased() ?? "undecided")")
        print("  address    : \(destination?.absoluteString ?? "none")")
        print("  \(WebConfig.pathParameterName)     : \(pathID ?? "none")")
        print("  requests   : \(hubRequests)/\(WebConfig.maxHubRequests) spent")
        print("  lead id    : \(leadUserID ?? "none")")
        print("  configured : \(WebConfig.destinationURL?.absoluteString ?? "no destination")")
        print("  allowlist  : \(WebHostPolicy.allowedHosts.joined(separator: ", "))")
        print("WEB store ────────────────────────────────────────")
    }

    nonisolated static func reset() {
        for key in [decisionKey, destinationKey, pathIDKey, hubRequestsKey, lastHubAtKey, leadUserIDKey, didAskPushKey, hostPolicyMigratedKey] {
            defaults.removeObject(forKey: key)
        }
        log("reset")
    }

    /// Called from `newAppApp.init()`, which is the last moment before
    /// `AppRouter.init()` reads the decision to pick the launch phase.
    nonisolated static func applyQAOverrides() {
        let env = ProcessInfo.processInfo.environment
        if env["AA_WEB_RESET"] == "1" { reset() }

        switch env["AA_WEB_FORCE"] {
        case "web":
            if let url = WebConfig.destinationURL {
                commitWeb(destination: url, pathID: nil)
                log("forced web → \(url.absoluteString)")
            } else {
                log("AA_WEB_FORCE=web ignored — no AA_WEB_URL")
            }
        case "native":
            commitNative()
            log("forced native")
        default:
            break
        }

        logState()
    }
    #endif
}
