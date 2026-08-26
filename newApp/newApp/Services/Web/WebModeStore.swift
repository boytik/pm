import Foundation

enum WebDecision: String {
    case web
    case native
}

enum WebModeStore {
    nonisolated(unsafe) private static let defaults = UserDefaults.standard

    nonisolated private static let decisionKey = "com.alphaacademy.web.decision"
    nonisolated private static let destinationKey = "com.alphaacademy.web.destination"
    nonisolated private static let pathIDKey = "com.alphaacademy.web.pathID"
    nonisolated private static let hubRequestsKey = "com.alphaacademy.web.hubRequests"
    nonisolated private static let lastHubAtKey = "com.alphaacademy.web.lastHubAt"
    nonisolated private static let leadUserIDKey = "com.alphaacademy.web.leadUserID"
    nonisolated private static let didAskPushKey = "com.alphaacademy.web.didAskPush"
    nonisolated private static let hostPolicyMigratedKey = "com.alphaacademy.web.hostPolicyMigrated"

    nonisolated static var decision: WebDecision? {
        defaults.string(forKey: decisionKey).flatMap(WebDecision.init(rawValue:))
    }

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

    nonisolated static var leadUserID: String? {
        get { defaults.string(forKey: leadUserIDKey) }
        set {
            defaults.set(newValue, forKey: leadUserIDKey)
            log("lead user_id: \(newValue ?? "cleared")")
        }
    }

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

    nonisolated static var hubRequests: Int {
        defaults.integer(forKey: hubRequestsKey)
    }

    nonisolated static var mayRequestHub: Bool {
        guard hubRequests < WebConfig.maxHubRequests else { return false }
        guard let last = defaults.object(forKey: lastHubAtKey) as? Date else { return true }
        return Date().timeIntervalSince(last) >= WebConfig.retryCooldown
    }

    nonisolated static func noteHubRequest(now: Date = Date()) {
        defaults.set(hubRequests + 1, forKey: hubRequestsKey)
        defaults.set(now, forKey: lastHubAtKey)
    }

    nonisolated static func migrateHostPolicyIfNeeded() {
        guard !defaults.bool(forKey: hostPolicyMigratedKey) else { return }
        defaults.set(true, forKey: hostPolicyMigratedKey)

        guard decision == .web, let saved = destination else { return }

        guard !WebHostPolicy.isConfiguredFirstParty(saved) else { return }

        let rederived = WebGate.rebuiltURL() ?? WebConfig.destinationURL
        log("saved address \(saved.host ?? "-") is outside the allowlist — re-derived")
        destination = rederived
    }

    nonisolated private static func log(_ message: String) {
        #if DEBUG
        print("WEB store: \(message)")
        #endif
    }

    #if DEBUG

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
