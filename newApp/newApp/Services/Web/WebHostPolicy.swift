import Foundation

nonisolated enum WebHostPolicy {
    static let anchorHosts: [String] = ["signals.tradingwithtyler.com"]

    static var overrideHosts: [String] {
        guard let raw = ProcessInfo.processInfo.environment["AA_WEB_HOSTS"], !raw.isEmpty
        else { return [] }
        return raw.split(separator: ",").compactMap { normalized(String($0)) }
    }

    static var configuredHosts: [String] {
        var seen = Set<String>()
        var result: [String] = []
        func add(_ host: String?) {
            guard let host = normalized(host), !seen.contains(host) else { return }
            seen.insert(host)
            result.append(host)
        }

        anchorHosts.forEach { add($0) }

        add(WebConfig.destinationURL?.host)
        overrideHosts.forEach { add($0) }

        return result
    }

    static var allowedHosts: [String] {
        var result = configuredHosts
        if let learned = normalized(WebModeStore.destination?.host),
           !result.contains(learned) {
            result.append(learned)
        }
        return result
    }

    static func isFirstParty(_ url: URL?) -> Bool {
        guard let host = normalized(url?.host) else { return false }
        return allowedHosts.contains { matches(host, $0) }
    }

    static func isConfiguredFirstParty(_ url: URL?) -> Bool {
        guard let host = normalized(url?.host) else { return false }
        return configuredHosts.contains { matches(host, $0) }
    }

    static func normalized(_ host: String?) -> String? {
        guard var host = host?.lowercased(), !host.isEmpty else { return nil }

        if host.hasSuffix(".") { host.removeLast() }
        return host.isEmpty ? nil : host
    }

    static func matches(_ host: String, _ allowed: String) -> Bool {
        host == allowed || host.hasSuffix("." + allowed)
    }
}
