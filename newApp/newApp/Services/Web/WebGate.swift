//
//  WebGate.swift
//  Alpha Academy
//
//  Decides, exactly once per install, whether the app runs as the native
//  trainer or as the remote page. Runs after the ATT prompt has been answered —
//  see the sequencing in `RootView`.
//

import Foundation

enum WebGate {

    enum Outcome {
        case web(url: URL, pathID: String?)
        case native
    }

    /// Ephemeral with a short ceiling: this sits between the learner and the
    /// first screen, so a stalled host must fail rather than hang. Cookies are
    /// deliberately not shared with the shell's `WKWebsiteDataStore` — the probe
    /// only needs to know whether the address answers.
    nonisolated private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = WebConfig.requestTimeout
        config.timeoutIntervalForResource = WebConfig.requestTimeout
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    /// Only ever called while `WebModeStore.decision` is nil.
    ///
    /// Anything short of a live, redirecting destination answers `.native`, and
    /// the caller writes that down permanently. That includes transport
    /// failures: a first launch with no network settles on the native trainer.
    nonisolated static func decide() async -> Outcome {
        guard let base = WebConfig.destinationURL else {
            log("no destination configured → native")
            return .native
        }

        guard WebModeStore.mayRequestHub else {
            log("request budget spent (\(WebModeStore.hubRequests)/\(WebConfig.maxHubRequests)) → native")
            return .native
        }

        WebModeStore.noteHubRequest()

        do {
            var request = URLRequest(url: base)
            request.httpMethod = "GET"
            let trail = RedirectTrail()
            let (data, response) = try await session.data(for: request, delegate: trail)

            guard let http = response as? HTTPURLResponse else {
                log("non-HTTP response → native")
                return .native
            }

            // URLSession follows redirects itself, so this is the end of the
            // chain: a 302 that lands on a 404 correctly reports 404.
            let final = http.url ?? base

            // Dumped before classification, so a destination that goes native
            // still shows why rather than just announcing the verdict.
            #if DEBUG
            dump(requested: base, final: final, response: http, body: data, redirected: trail.didRedirect)
            #endif

            guard WebConfig.positiveStatus.contains(http.statusCode) else {
                log("status \(http.statusCode) → native")
                return .native
            }

            // A destination that redirects and lands back on itself has not
            // routed anywhere. Conditioned on an actual redirect: an address
            // that simply answers in place is a perfectly good answer, and
            // `response.url` alone cannot tell the two cases apart.
            if trail.didRedirect, final.absoluteString == base.absoluteString {
                log("redirect chain returned to the destination → native")
                return .native
            }

            let pathID = extractPathID(from: final, body: data)
            log("status \(http.statusCode)\(trail.didRedirect ? " after redirect" : " in place") → web \(final.absoluteString)")
            return .web(url: final, pathID: pathID)
        } catch {
            let ns = error as NSError
            log("transport failure \(ns.code) (\(ns.domain)) → native")
            log("  \(ns.localizedDescription)")
            return .native
        }
    }

    /// The one recovery move: the configured destination carrying the `pathid`
    /// captured when web mode was first granted. Callers must check
    /// `WebModeStore.mayRequestHub` and spend a request themselves.
    nonisolated static func rebuiltURL() -> URL? {
        guard let base = WebConfig.destinationURL,
              let pathID = WebModeStore.pathID, !pathID.isEmpty,
              var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        else { return nil }

        var items = components.queryItems ?? []
        items.removeAll {
            $0.name.caseInsensitiveCompare(WebConfig.pathParameterName) == .orderedSame
        }
        items.append(URLQueryItem(name: WebConfig.pathParameterName, value: pathID))
        components.queryItems = items
        return components.url
    }

    // MARK: - Helpers

    /// The query parameter is the reliable source; the body is a fallback for
    /// destinations that only echo it into the page.
    nonisolated static func extractPathID(from url: URL, body: Data?) -> String? {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let value = components.queryItems?.first(where: {
               $0.name.caseInsensitiveCompare(WebConfig.pathParameterName) == .orderedSame
           })?.value,
           !value.isEmpty {
            return value
        }

        guard let body, let html = String(data: body, encoding: .utf8) else { return nil }
        let pattern = "\(WebConfig.pathParameterName)[\"']?\\s*[=:]\\s*[\"']?([^&\\s\"'<>]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html)
        else { return nil }
        return String(html[range])
    }

    /// Only exists to answer "did the chain move at all?". URLSession follows
    /// redirects for us; this just watches it happen. Written on the session's
    /// delegate queue and read once `data(for:delegate:)` has returned, so the
    /// lock is what makes that hand-off legal rather than merely likely.
    private final class RedirectTrail: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        private let lock = NSLock()
        private var redirected = false

        nonisolated var didRedirect: Bool {
            lock.lock()
            defer { lock.unlock() }
            return redirected
        }

        nonisolated func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest,
            completionHandler: @escaping (URLRequest?) -> Void
        ) {
            lock.lock()
            redirected = true
            lock.unlock()
            completionHandler(request)
        }
    }

    /// The whole server answer, DEBUG only. Compiled out of release entirely:
    /// the body of a funnel response is not something to leave in a shipping log.
    #if DEBUG
    nonisolated private static let bodyDumpLimit = 4000

    nonisolated private static func dump(
        requested: URL,
        final: URL,
        response: HTTPURLResponse,
        body: Data,
        redirected: Bool
    ) {
        print("WEB gate ── response ─────────────────────────────")
        print("  requested : \(requested.absoluteString)")
        print("  final     : \(final.absoluteString)\(redirected ? "  (after redirect)" : "  (no redirect)")")
        print("  status    : \(response.statusCode)")

        for (key, value) in response.allHeaderFields.sorted(by: {
            String(describing: $0.key) < String(describing: $1.key)
        }) {
            print("  \(String(describing: key)): \(String(describing: value))")
        }

        print("  body      : \(body.count) bytes")
        if let text = String(data: body, encoding: .utf8) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                print("  (empty)")
            } else if trimmed.count > bodyDumpLimit {
                print(trimmed.prefix(bodyDumpLimit))
                print("  … truncated at \(bodyDumpLimit) of \(trimmed.count) characters")
            } else {
                print(trimmed)
            }
        } else {
            print("  (not UTF-8)")
        }
        print("WEB gate ─────────────────────────────────────────")
    }
    #endif

    nonisolated private static func log(_ message: String) {
        #if DEBUG
        print("WEB gate: \(message)")
        #endif
    }
}
