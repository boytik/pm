//
//  PushAPI.swift
//  Alpha Academy
//
//  Client for the Pocket Alpha push endpoints.
//  Contract: Pocket_Alpha_iOS_Push_API.md §2.
//

import Foundation

// MARK: - Wire types

// `nonisolated` because the target defaults to MainActor isolation, which would
// otherwise pin the Decodable conformance to the main actor and make it unusable
// from the background refresh.
nonisolated struct PendingPushResponse: Decodable {
    let hasPush: Bool
    let push: PushPayload?
    /// Sent on EVERY response, including the ones that carry a push (§2).
    let nextPollAfterSec: Int
    /// Debug-only hint (`telegram_lead` / `posts_disabled` / `in_app`).
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case hasPush = "has_push"
        case push
        case nextPollAfterSec = "next_poll_after_sec"
        case reason
    }
}

nonisolated struct PushPayload: Decodable {
    let deliveryID: String
    let postID: Int
    let title: String
    let body: String
    /// May legitimately be `null` — then the tap just opens the app (§2).
    let action: Action?
    let lang: String

    struct Action: Decodable {
        let text: String
        /// Absolute; attribution is already baked in. Append nothing (§2).
        let url: String
    }

    enum CodingKeys: String, CodingKey {
        case deliveryID = "delivery_id"
        case postID = "post_id"
        case title, body, action, lang
    }
}

// MARK: - Client

enum PushAPIError: Error {
    case badStatus(Int)
}

/// The target builds with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so every
/// member here is marked `nonisolated` — this is plain networking and has no
/// business being pinned to the main actor, least of all inside a background
/// refresh with a tight time budget.
enum PushAPI {

    nonisolated static let baseURL = URL(string: "https://lumetriqbogins.com/wVRpyY")!

    /// Ephemeral, with a short timeout: a BGAppRefreshTask gets a small window
    /// and a stalled request would burn it for nothing.
    nonisolated private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    /// `es` gets the Spanish copy, everything else falls back to English (§2.1).
    nonisolated static var deviceLang: String {
        let code: String?
        if #available(iOS 16.0, *) {
            code = Locale.current.language.languageCode?.identifier
        } else {
            code = Locale.current.languageCode
        }
        return code == "es" ? "es" : "en"
    }

    nonisolated static func fetchPending(
        userID: String,
        session sessionToken: String?,
        lang: String = deviceLang
    ) async throws -> PendingPushResponse {
        let encodedID = userID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userID
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/userapi/user/\(encodedID)/push/pending"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "lang", value: lang)]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        // §3: the secret is not enabled on prod yet, so the check runs in shadow
        // mode and unauthenticated requests still pass. Send the header the
        // moment we have a token — it starts being enforced without warning.
        if let sessionToken, !sessionToken.isEmpty {
            request.setValue(sessionToken, forHTTPHeaderField: "X-App-Session")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PushAPIError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(PendingPushResponse.self, from: data)
    }

    /// §2.2. Idempotent — the first click wins. Without this the whole iOS
    /// channel reads as delivered-but-never-opened, so failures are swallowed
    /// rather than allowed to block opening the action URL.
    nonisolated static func reportClick(deliveryID: String) async {
        let encoded = deliveryID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? deliveryID
        var request = URLRequest(
            url: baseURL.appendingPathComponent("/userapi/push/\(encoded)/clicked")
        )
        request.httpMethod = "POST"
        _ = try? await session.data(for: request)
    }
}
