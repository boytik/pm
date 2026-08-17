//
//  AnalyticsConfig.swift
//  Alpha Academy
//
//  Credentials for the AppsFlyer SDK. Kept in one place so the values can be
//  filled in without touching the service that consumes them.
//

import Foundation

enum AnalyticsConfig {

    /// TODO: paste the AppsFlyer dev key before any device build.
    /// An empty value is not an error — `AppsFlyerService` treats it as
    /// "analytics not configured yet" and never starts the SDK, so simulator
    /// runs and the DEBUG self-check stay quiet.
    static let appsFlyerDevKey = ""

    /// TODO: paste the numeric Apple App ID (App Store Connect), no `id` prefix.
    static let appleAppID = ""

    static var isConfigured: Bool {
        !appsFlyerDevKey.isEmpty && !appleAppID.isEmpty
    }
}
