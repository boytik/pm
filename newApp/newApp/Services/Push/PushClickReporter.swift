//
//  PushClickReporter.swift
//  Alpha Academy
//
//  §6 of the push spec: a tap that does not reach the page has to be reported,
//  or the whole "push → click → deposit" funnel reads as empty on iOS.
//
//  Kept apart from `DeviceRegistrar` because the failure semantics are the
//  opposite: never retried, never throttled, never allowed to delay opening
//  the URL the learner just tapped.
//

import Foundation

nonisolated enum PushClickReporter {

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config)
    }()

    /// Idempotent on the server — the first call wins and later ones are
    /// ignored, so a duplicate is cheaper than a miss.
    static func report(pid: String) async {
        var request = URLRequest(
            url: PushConfig.baseURL.appendingPathComponent(PushConfig.clickPath(pid: pid))
        )
        request.httpMethod = "POST"
        if let key = PushConfig.appKey, !key.isEmpty {
            request.setValue(key, forHTTPHeaderField: "X-App-Key")
        }
        _ = try? await session.data(for: request)
        #if DEBUG
        print("PUSH tap: reported click for pid=\(pid)")
        #endif
    }
}
