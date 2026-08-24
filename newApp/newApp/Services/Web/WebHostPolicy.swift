//
//  WebHostPolicy.swift
//  Alpha Academy
//
//  Which addresses belong to us. Everything else the page tries to open in the
//  main frame is handed to the system browser instead.
//
//  Its own file rather than a member of `WebConfig`: that type is a leaf —
//  "the single place the remote destination lives, plus the constants" — with
//  no dependencies, and this needs `WebModeStore`, which already depends on
//  `WebConfig`. Putting it there would invert the layering.
//
//  The list is deliberately not a compile-time constant. `WebConfig.destination`
//  is a keitaro cloaking address; the funnel's real host is the end of a
//  redirect chain and is unknown until the app has followed it. So the list is
//  seeded from configuration and learned from the chain, and recomputed on
//  every call — freezing it at the first navigation is the bug that makes a
//  funnel migration undebuggable.
//

import Foundation

nonisolated enum WebHostPolicy {

    /// The funnel's own origin, and the host the push API is served from. The
    /// one entry that cannot be lost, whatever happens to the stored address.
    ///
    /// The apex `tradingwithtyler.com` is deliberately absent: only this host
    /// and its subdomains are ours. If the funnel ever serves anything from
    /// the apex, adding it here is a one-word change.
    static let anchorHosts: [String] = ["signals.tradingwithtyler.com"]

    /// `AA_WEB_HOSTS=funnel.example.com,cdn.example.com`
    ///
    /// Read in release too, exactly like `AA_WEB_URL`. If the funnel ever lands
    /// somewhere the redirect chain cannot teach us, this pins it from the
    /// launch environment rather than from a new build.
    static var overrideHosts: [String] {
        guard let raw = ProcessInfo.processInfo.environment["AA_WEB_HOSTS"], !raw.isEmpty
        else { return [] }
        return raw.split(separator: ",").compactMap { normalized(String($0)) }
    }

    /// What the build and the launch environment say is ours, with nothing
    /// learned at runtime. Kept separate because the full list contains the
    /// saved address, which makes every saved address first-party by
    /// construction — fine for deciding navigation, useless for asking whether
    /// the saved address itself is sane.
    static var configuredHosts: [String] {
        var seen = Set<String>()
        var result: [String] = []
        func add(_ host: String?) {
            guard let host = normalized(host), !seen.contains(host) else { return }
            seen.insert(host)
            result.append(host)
        }

        anchorHosts.forEach { add($0) }
        // Without this, `recover()` would load a rebuilt keitaro URL that the
        // shell then throws out to Safari, killing the only recovery path the
        // app has. It also keeps `AA_WEB_URL=<anything>` self-consistent.
        add(WebConfig.destinationURL?.host)
        overrideHosts.forEach { add($0) }

        return result
    }

    /// Ordered, normalised, de-duplicated. A computed property on purpose.
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

    /// Ignores the learned host. The one caller is the migration that has to
    /// decide whether the learned host should have been learned at all.
    static func isConfiguredFirstParty(_ url: URL?) -> Bool {
        guard let host = normalized(url?.host) else { return false }
        return configuredHosts.contains { matches(host, $0) }
    }

    // MARK: - Internals

    static func normalized(_ host: String?) -> String? {
        // `lowercased()` with no argument is locale-independent. Never
        // `lowercased(with: .current)`: in a Turkish locale `I` lowercases to
        // `ı` and every comparison here silently stops matching.
        guard var host = host?.lowercased(), !host.isEmpty else { return nil }
        // `https://signals.tradingwithtyler.com./x` is a valid absolute-FQDN
        // URL and `URL.host` hands back the trailing dot.
        if host.hasSuffix(".") { host.removeLast() }
        return host.isEmpty ? nil : host
    }

    /// The leading dot is load-bearing. `host.hasSuffix(allowed)` on its own
    /// accepts `notsignals.tradingwithtyler.com`, which is the single most
    /// common bug in exactly this function.
    ///
    /// Comparison is on the punycode form `URL.host` returns, and that is the
    /// security property we want: a Cyrillic homograph of the anchor normalises
    /// to a different ASCII string and does not match. Do not "improve" this
    /// into a Unicode-aware compare.
    static func matches(_ host: String, _ allowed: String) -> Bool {
        host == allowed || host.hasSuffix("." + allowed)
    }
}
