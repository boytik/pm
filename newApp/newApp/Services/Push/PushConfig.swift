import Foundation

nonisolated enum PushConfig {
    private static let defaultBaseURL = "https://signals.tradingwithtyler.com"

    static var baseURL: URL {
        let raw = ProcessInfo.processInfo.environment["AA_PUSH_BASE_URL"]
            .flatMap { $0.isEmpty ? nil : $0 } ?? defaultBaseURL
        return URL(string: raw) ?? URL(string: defaultBaseURL)!
    }

    static let registerPath = "/userapi/device/register"

    static func clickPath(pid: String) -> String {
        let encoded = pid.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? pid
        return "/userapi/push/\(encoded)/clicked"
    }

    static let appKey: String? = nil

    static let requestTimeout: TimeInterval = 15
    static let resourceTimeout: TimeInterval = 60

    static let minRegisterInterval: TimeInterval = 60

    static let staleRegistrationAge: TimeInterval = 6 * 3600

    static let retryDelays: [TimeInterval] = [0, 2, 8]
}
