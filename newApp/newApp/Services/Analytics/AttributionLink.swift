//
//  AttributionLink.swift
//  Alpha Academy
//
//  Step 4 of the Pocket tracking manual: when the learner leaves for Pocket
//  Option, the campaign link must carry their `appsflyer_id` and their
//  conversion data, or the registration — and every deposit after it — is
//  attributed to nobody.
//
//  This is applied at the single point every outbound address already passes
//  through, `openExternally`, so a link reaches Pocket enriched whether it came
//  from a tap, a `window.open`, a reserved window, or a scripted navigation.
//  There is no second place to keep in sync.
//
//  Two deliberate departures from the manual, both to protect what already
//  works:
//
//  1. The manual says not to open the link at all if the data cannot be
//     obtained. We open it anyway, unenriched, and log loudly. Refusing would
//     mean the learner taps "Deposit" and *nothing happens* — the exact
//     symptom `WebWindowPolicy` exists to remove — and a lost attribution is a
//     smaller failure than a dead button.
//  2. A parameter the page has already put on the link wins. If the front end
//     starts building the link itself from `window.__native`, this must not
//     fight it; it becomes a no-op instead.
//

import Foundation

nonisolated enum AttributionLink {

    /// Hosts whose links are Pocket campaign links.
    ///
    /// Matched as a **suffix on a label boundary**, so `pocketpartners.link`
    /// covers `example.pocketpartners.link` but never `notpocketpartners.link`.
    ///
    /// The manual only ever shows `<something>.pocketpartners.link/registration`.
    /// If the campaign link issued for this app lands anywhere else, that is a
    /// one-line change here or an `AA_AF_LINK_HOSTS` on the launch — the
    /// machinery does not need rebuilding for it.
    static let anchorHostSuffixes: [String] = ["pocketpartners.link"]

    /// `AA_AF_LINK_HOSTS=go.example.com,partners.example.link`
    ///
    /// Read in release too, exactly like `AA_WEB_URL` and `AA_PUSH_BASE_URL`:
    /// the campaign link is issued by a PM, not by a build.
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

    // MARK: - The payload

    /// `nil` rather than `""` when the SDK has not produced one yet — the
    /// manual is explicit that an empty or self-minted id must never be sent.
    static var appsFlyerID: String? {
        AppsFlyerService.installUID
    }

    /// Everything that goes on the link: the id under the name the manual
    /// gives it, plus the forwarded slice of the conversion payload.
    static var parameters: [String: String] {
        guard let id = appsFlyerID, !id.isEmpty else { return [:] }
        var result = AttributionStore.conversion ?? [:]
        // Ours wins over a same-named conversion key, which cannot happen
        // today but would be a silent mis-attribution if it ever did.
        result["appsflyer_id"] = id
        return result
    }

    // MARK: - Decisions

    static func isCampaignLink(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host?.lowercased(), !host.isEmpty
        else { return false }
        return hostSuffixes.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    /// Returns the address to actually open. Unchanged for anything that is not
    /// a campaign link, and unchanged — but logged — when there is nothing to
    /// add.
    ///
    /// `quiet` silences the trace for callers that are already printing a
    /// block of their own — the DEBUG dump builds a sample link through this
    /// very method, and a stray line in the middle of its output reads as a
    /// real outbound tap.
    static func enrich(_ url: URL, quiet: Bool = false) -> URL {
        guard isCampaignLink(url) else {
            // Logged, not silent. Until the PM issues the real campaign link
            // this is the only way to discover its host: tap "Deposit" and read
            // which address went out unrecognised.
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

        // Sorted so the same payload always produces the same link — a QA
        // report that pastes a URL should be comparable to the next one.
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

    // MARK: - Encoding

    /// `URLComponents.queryItems` percent-encodes, but it leaves `+` alone —
    /// and a `+` inside a value is read back as a space by essentially every
    /// server. `af_click_id` and the `af_sub*` fields are opaque strings that
    /// may contain one, so the encoding is done here and handed to
    /// `percentEncodedQueryItems`.
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
