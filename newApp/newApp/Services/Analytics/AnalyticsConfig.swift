import Foundation

enum AnalyticsConfig {
    static let appsFlyerDevKey = "tpo26kGGQA3vjcHX6gYBmW"

    static let appleAppID = "6802423819"

    static var isConfigured: Bool {
        !appsFlyerDevKey.isEmpty && !appleAppID.isEmpty
    }
}
