//
//  DeviceRegistrar.swift
//  Alpha Academy
//
//  Reports this handset to the push backend. Two calls against one idempotent
//  endpoint: one on every launch carrying whatever metadata is known, and one
//  the moment Apple hands over an APNs token. Empty fields do not overwrite
//  what the server already knows, so the second call sends only the token.
//
//  `has_apns_token` in the response — not the 200 — is the answer to "is my
//  integration working".
//

import Foundation
import UIKit

// `nonisolated` so the Decodable conformance is not pinned to the main actor,
// matching how the rest of the project handles `SWIFT_DEFAULT_ACTOR_ISOLATION`.
nonisolated struct DeviceRegisterResponse: Decodable {
    let ok: Bool
    let deviceID: String?
    /// Whether the backend knows which lead owns this device. Flips to true
    /// once the page reports `window.__native.device_id` alongside the login.
    let linked: Bool?
    let hasAPNsToken: Bool?

    enum CodingKeys: String, CodingKey {
        case ok
        case deviceID = "device_id"
        case linked
        case hasAPNsToken = "has_apns_token"
    }
}

enum DeviceRegistrar {

    enum Reason: String {
        case launch
        case foreground
        case apnsToken
        case permissionGranted
    }

    private enum Outcome {
        case success(DeviceRegisterResponse)
        /// Transport failure, 5xx, or 429 — worth another attempt.
        case retryable(String)
        /// 4xx other than 429. The payload is wrong; retrying only triples the
        /// noise and the rate-limit spend.
        case fatal(Int)
    }

    /// Not the ephemeral, `waitsForConnectivity = false` session the old pull
    /// funnel used — that was tuned for a `BGAppRefreshTask`'s few seconds of
    /// life, and there is no background task any more. Waiting for connectivity
    /// means a launch in a lift simply lands a few seconds later, with no retry
    /// state spent on it.
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = PushConfig.requestTimeout
        config.timeoutIntervalForResource = PushConfig.resourceTimeout
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    // MARK: - Entry points

    /// The every-launch metadata call. Fire and forget: there is nothing the
    /// learner could do about a failure and nothing worth telling them.
    static func registerLaunch(reason: Reason) async {
        guard let deviceID = DeviceIdentity.current() else {
            log("\(reason.rawValue) skipped — no device_id (keychain unreadable)")
            return
        }

        if let last = DeviceRegistrationStore.lastRegisterAt,
           Date().timeIntervalSince(last) < PushConfig.minRegisterInterval {
            log("\(reason.rawValue) throttled (\(Int(Date().timeIntervalSince(last)))s since last)")
            return
        }

        // A foreground only re-registers when the last success has gone stale
        // or the token has never made it across.
        if reason == .foreground,
           let ok = DeviceRegistrationStore.lastRegisterOKAt,
           Date().timeIntervalSince(ok) < PushConfig.staleRegistrationAge,
           DeviceRegistrationStore.lastSentToken != nil {
            return
        }

        await send(body: launchBody(deviceID: deviceID), reason: reason)
        await flushPendingToken()
    }

    /// Called from `didRegisterForRemoteNotificationsWithDeviceToken`. Always
    /// sent: it happens at most once per launch, the endpoint is idempotent,
    /// and sending unconditionally makes the client self-healing against any
    /// server-side loss.
    static func registerAPNsToken(_ token: Data) async {
        let hex = hexString(token)
        let env = APNSEnvironment.current.rawValue

        // A token that changes on every launch is a real bug class — usually a
        // provisioning mismatch — so the transition is worth being able to grep.
        let changed = DeviceRegistrationStore.lastSentToken.map { $0 != hex } ?? true
        logToken("token \(redact(hex)) (\(hex.count) chars) env=\(env) "
                 + (changed ? "[CHANGED]" : "[unchanged]"))

        guard let deviceID = DeviceIdentity.current() else {
            // No id to send it with. Hold it rather than dropping it, or this
            // device never reports a token at all.
            DeviceRegistrationStore.pendingToken = hex
            logToken("token held — no device_id yet")
            return
        }

        await send(
            body: ["device_id": deviceID, "apns_token": hex, "apns_env": env],
            reason: .apnsToken
        )
        DeviceRegistrationStore.lastSentToken = hex
        DeviceRegistrationStore.lastSentEnv = env
        DeviceRegistrationStore.pendingToken = nil
    }

    /// Sends a token that arrived before there was a `device_id` to attach it to.
    static func flushPendingToken() async {
        guard let hex = DeviceRegistrationStore.pendingToken,
              let deviceID = DeviceIdentity.current()
        else { return }

        let env = APNSEnvironment.current.rawValue
        log("flushing held token \(redact(hex))")
        await send(
            body: ["device_id": deviceID, "apns_token": hex, "apns_env": env],
            reason: .apnsToken
        )
        DeviceRegistrationStore.lastSentToken = hex
        DeviceRegistrationStore.lastSentEnv = env
        DeviceRegistrationStore.pendingToken = nil
    }

    // MARK: - Payload

    private static func launchBody(deviceID: String) -> [String: String] {
        var body: [String: String] = [
            "device_id": deviceID,
            "platform": "ios",
        ]
        // Empty values are omitted rather than sent as "": the endpoint treats
        // an absent field as "leave what you know", and an empty string would
        // be a value.
        func put(_ key: String, _ value: String?) {
            guard let value, !value.isEmpty else { return }
            body[key] = value
        }

        let info = Bundle.main.infoDictionary
        put("bundle_id", Bundle.main.bundleIdentifier)
        put("app_version", info?["CFBundleShortVersionString"] as? String)
        put("build", info?["CFBundleVersion"] as? String)
        put("os_version", UIDevice.current.systemVersion)
        // BCP-47 rather than the POSIX form Foundation returns: `es_MX` is not
        // a language tag, and the server documents `es-MX` → `es`.
        put("locale", Locale.current.identifier.replacingOccurrences(of: "_", with: "-"))
        put("appsflyer_id", AppsFlyerService.installUID)
        put("idfv", UIDevice.current.identifierForVendor?.uuidString)

        return body
    }

    // MARK: - Transport

    private static func send(body: [String: String], reason: Reason) async {
        DeviceRegistrationStore.lastRegisterAt = Date()

        for (attempt, delay) in PushConfig.retryDelays.enumerated() {
            if delay > 0 {
                let jittered = delay * Double.random(in: 0.75...1.25)
                try? await Task.sleep(nanoseconds: UInt64(jittered * 1_000_000_000))
            }

            switch await post(body) {
            case .success(let response):
                DeviceRegistrationStore.lastRegisterOKAt = Date()
                DeviceRegistrationStore.lastLinked = response.linked ?? false
                DeviceRegistrationStore.lastHasAPNsToken = response.hasAPNsToken ?? false
                log("\(reason.rawValue) ok linked=\(response.linked ?? false) "
                    + "has_apns_token=\(response.hasAPNsToken ?? false)")
                return

            case .retryable(let why):
                log("\(reason.rawValue) attempt \(attempt + 1) failed — \(why)")

            case .fatal(let status):
                log("\(reason.rawValue) rejected \(status) — contract bug, not retrying")
                return
            }
        }

        log("\(reason.rawValue) gave up after \(PushConfig.retryDelays.count) attempts")
    }

    private static func post(_ body: [String: String]) async -> Outcome {
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else {
            return .fatal(-1)
        }

        var request = URLRequest(
            url: PushConfig.baseURL.appendingPathComponent(PushConfig.registerPath)
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = PushConfig.appKey, !key.isEmpty {
            request.setValue(key, forHTTPHeaderField: "X-App-Key")
        }
        request.httpBody = payload

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .retryable("no HTTP response")
            }
            switch http.statusCode {
            case 200..<300:
                guard let decoded = try? JSONDecoder().decode(DeviceRegisterResponse.self, from: data) else {
                    return .retryable("undecodable body")
                }
                return .success(decoded)
            case 429, 500...599:
                return .retryable("status \(http.statusCode)")
            default:
                return .fatal(http.statusCode)
            }
        } catch {
            return .retryable((error as NSError).localizedDescription)
        }
    }

    // MARK: - Helpers

    /// Lowercase hex, no separators. `String(describing:)` on the raw `Data`
    /// yields `"<a1b2c3d4 e5f60718 …>"`, which the server discards — and it is
    /// the single most likely way to get this integration wrong, which is why
    /// `DebugSelfCheck` asserts on it.
    static func hexString(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    private static func redact(_ token: String) -> String {
        guard token.count > 8 else { return "…" }
        return "…" + token.suffix(6)
    }

    private static func log(_ message: String) {
        #if DEBUG
        print("PUSH reg: \(message)")
        #endif
    }

    /// Token traffic gets its own prefix so `PUSH apns:` alone answers "did
    /// Apple ever hand us one, and which gateway is it for".
    private static func logToken(_ message: String) {
        #if DEBUG
        print("PUSH apns: \(message)")
        #endif
    }
}
