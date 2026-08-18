//
//  AnalyticsConfig.swift
//  Alpha Academy
//
//  Credentials for the AppsFlyer SDK. Kept in one place so the values can be
//  filled in without touching the service that consumes them.
//

import Foundation

enum AnalyticsConfig {

    /// AppsFlyer dev key (AppsFlyer dashboard → App Settings).
    /// An empty value is not an error — `AppsFlyerService` treats it as
    /// "analytics not configured yet" and never starts the SDK, so simulator
    /// runs and the DEBUG self-check stay quiet.
    static let appsFlyerDevKey = "VRzpHt6GaPfuBnjKME9ig9"

    /// Numeric Apple App ID (App Store Connect), no `id` prefix.
    static let appleAppID = "6798298103"

    static var isConfigured: Bool {
        !appsFlyerDevKey.isEmpty && !appleAppID.isEmpty
    }
}
