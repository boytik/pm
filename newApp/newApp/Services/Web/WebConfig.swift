import Foundation

enum WebConfig {
    nonisolated private static let destination = "https://lumetriqbogins.com/wVRpyY"

    nonisolated static var destinationURL: URL? {
        let raw = ProcessInfo.processInfo.environment["AA_WEB_URL"]
            .flatMap { $0.isEmpty ? nil : $0 } ?? destination
        guard !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    nonisolated static let requestTimeout: TimeInterval = 5

    nonisolated static let loadWatchdog: TimeInterval = 7

    nonisolated static let stallWatchdog: TimeInterval = 25

    nonisolated static let maxHubRequests = 2

    nonisolated static let retryCooldown: TimeInterval = 90

    nonisolated static let positiveStatus: ClosedRange<Int> = 200...403

    nonisolated static let pathParameterName = "pathid"
}
