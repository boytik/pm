import Foundation

nonisolated enum PushClickReporter {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config)
    }()

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
