import Foundation

nonisolated enum AttributionLink {
    static let anchorHostSuffixes: [String] = ["pocketpartners.link"]

    static var overrideHostSuffixes: [String] {
        guard let raw = ProcessInfo.processInfo.environment["AA_AF_LINK_HOSTS"], !raw.isEmpty
        else { return [] }
        return raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
    }

    static var hostSuffixes: [String] {
        var seen = Set<String>()
        return (anchorHostSuffixes + overrideHostSuffixes).filter { seen.insert($0).inserted }
    }

    static var appsFlyerID: String? {
        AppsFlyerService.installUID
    }

    static var parameters: [String: String] {
        guard let id = appsFlyerID, !id.isEmpty else { return [:] }
        var result = AttributionStore.conversion ?? [:]

        result["appsflyer_id"] = id
        return result
    }

    static func isCampaignLink(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host?.lowercased(), !host.isEmpty
        else { return false }
        return hostSuffixes.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    static func enrich(_ url: URL, quiet: Bool = false) -> URL {
        guard isCampaignLink(url) else {
            if !quiet {
                log("outbound \(url.host ?? "-") is not a campaign host "
                    + "(known: \(hostSuffixes.joined(separator: ", "))) — untouched")
            }
            return url
        }

        let payload = parameters
        guard !payload.isEmpty else {
            if !quiet { log("campaign link with no appsflyer_id yet — opening unenriched: \(url.absoluteString)") }
            return url
        }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            if !quiet { log("campaign link could not be parsed — opening unenriched: \(url.absoluteString)") }
            return url
        }

        var items = components.percentEncodedQueryItems ?? []
        let existing = Set(items.map(\.name))
        var added: [String] = []

        for key in payload.keys.sorted() {
            guard !existing.contains(key), let value = payload[key], !value.isEmpty else { continue }
            items.append(
                URLQueryItem(name: encode(key), value: encode(value))
            )
            added.append(key)
        }

        guard !added.isEmpty else {
            if !quiet { log("campaign link already carried every parameter — untouched") }
            return url
        }

        components.percentEncodedQueryItems = items
        guard let enriched = components.url else {
            if !quiet { log("campaign link could not be rebuilt — opening unenriched") }
            return url
        }

        if !quiet {
            log("campaign link + \(added.joined(separator: ", "))")
            log("  before: \(url.absoluteString)")
            log("  after : \(enriched.absoluteString)")
        }
        return enriched
    }

    private static let queryAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "+&=?#")
        return set
    }()

    private static func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: queryAllowed) ?? value
    }

    private static func log(_ message: String) {
        #if DEBUG
        print("ATTRIBUTION link: \(message)")
        #endif
    }
}
