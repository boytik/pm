import Foundation

enum AnalyticsConfig {
    static let appsFlyerDevKey = "VRzpHt6GaPfuBnjKME9ig9"

    static let appleAppID = "6798298103"

    static var isConfigured: Bool {
        !appsFlyerDevKey.isEmpty && !appleAppID.isEmpty
    }
}
