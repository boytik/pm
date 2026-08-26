import Foundation

enum WebGate {
    enum Outcome {
        case web(url: URL, pathID: String?)
        case native
    }

    nonisolated private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = WebConfig.requestTimeout
        config.timeoutIntervalForResource = WebConfig.requestTimeout
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

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

            let final = http.url ?? base

            #if DEBUG
            dump(requested: base, final: final, response: http, body: data, redirected: trail.didRedirect)
            #endif

            guard WebConfig.positiveStatus.contains(http.statusCode) else {
                log("status \(http.statusCode) → native")
                return .native
            }

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
