import Foundation
import UIKit

nonisolated struct DeviceRegisterResponse: Decodable {
    let ok: Bool
    let deviceID: String?

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

        case retryable(String)

        case fatal(Int)
    }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = PushConfig.requestTimeout
        config.timeoutIntervalForResource = PushConfig.resourceTimeout
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    static func registerLaunch(reason: Reason) async {
        // App Review, 03.09.2026: "the request must appear before any data that could be
        // used to track the user is collected". This body carries `appsflyer_id` — an
        // identifier minted by a third-party attribution vendor — so the launch call waits
        // for the ATT prompt to be answered. `settle` returns at once once it is, and the
        // APNs token has its own call site that this does not delay.
        if !TrackingAuthorization.isResolved {
            log("\(reason.rawValue) held until the ATT prompt is answered — "
                + "body carries appsflyer_id")
            await TrackingAuthorization.settle()
        }

        guard let deviceID = DeviceIdentity.current() else {
            log("\(reason.rawValue) skipped — no device_id (keychain unreadable)")
            return
        }

        if let last = DeviceRegistrationStore.lastRegisterAt,
           Date().timeIntervalSince(last) < PushConfig.minRegisterInterval {
            log("\(reason.rawValue) throttled (\(Int(Date().timeIntervalSince(last)))s since last)")
            return
        }

        if reason == .foreground,
           let ok = DeviceRegistrationStore.lastRegisterOKAt,
           Date().timeIntervalSince(ok) < PushConfig.staleRegistrationAge,
           DeviceRegistrationStore.lastSentToken != nil {
            return
        }

        await send(body: launchBody(deviceID: deviceID), reason: reason)
        await flushPendingToken()
    }

    static func registerAPNsToken(_ token: Data) async {
        let hex = hexString(token)
        let env = APNSEnvironment.current.rawValue

        let changed = DeviceRegistrationStore.lastSentToken.map { $0 != hex } ?? true
        logToken("token \(redact(hex)) (\(hex.count) chars) env=\(env) "
                 + (changed ? "[CHANGED]" : "[unchanged]"))

        guard let deviceID = DeviceIdentity.current() else {
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

    private static func launchBody(deviceID: String) -> [String: String] {
        var body: [String: String] = [
            "device_id": deviceID,
            "platform": "ios",
        ]

        func put(_ key: String, _ value: String?) {
            guard let value, !value.isEmpty else { return }
            body[key] = value
        }

        let info = Bundle.main.infoDictionary
        put("bundle_id", Bundle.main.bundleIdentifier)
        put("app_version", info?["CFBundleShortVersionString"] as? String)
        put("build", info?["CFBundleVersion"] as? String)
        put("os_version", UIDevice.current.systemVersion)

        put("locale", Locale.current.identifier.replacingOccurrences(of: "_", with: "-"))
        // Belt and braces for the wait above: `settle` is bounded, so an install where the
        // prompt is never answered would otherwise send the vendor id anyway once the
        // timeout lapsed. A later registration carries it, once there is an answer.
        if TrackingAuthorization.isResolved {
            put("appsflyer_id", AppsFlyerService.installUID)
        }
        put("idfv", UIDevice.current.identifierForVendor?.uuidString)

        return body
    }

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

    private static func logToken(_ message: String) {
        #if DEBUG
        print("PUSH apns: \(message)")
        #endif
    }
}
