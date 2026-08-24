//
//  PushConfig.swift
//  Alpha Academy
//
//  Where the push API lives, and the constants the registrar is tuned by.
//
//  Deliberately NOT `WebConfig.destination`. That address is a keitaro cloaking
//  link whose job is to route a *page* view; the API is served from the funnel's
//  own origin. Sending JSON through the cloaker would inherit its redirects and
//  its geo rules, and a 404 from a campaign that does not recognise the caller
//  is not something a registration should ever have to survive.
//

import Foundation

nonisolated enum PushConfig {

    private static let defaultBaseURL = "https://signals.tradingwithtyler.com"

    /// Read unconditionally rather than under `#if DEBUG`, matching how
    /// `WebConfig` treats `AA_WEB_URL`: QA needs to point release builds at a
    /// staging host without a rebuild.
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

    /// `X-App-Key`, if they ever issue one. Sent the moment it is non-nil —
    /// the header may start being enforced without warning, exactly as the old
    /// `X-App-Session` note warned.
    static let appKey: String? = nil

    static let requestTimeout: TimeInterval = 15
    static let resourceTimeout: TimeInterval = 60

    /// Floor between two registrations. The server's limit is 60 requests per
    /// minute per *IP*, so the case to protect against is not one handset but a
    /// QA lab or an office behind one NAT — plus relaunch and crash loops.
    static let minRegisterInterval: TimeInterval = 60

    /// How old a successful registration has to be before a foreground makes
    /// another one.
    static let staleRegistrationAge: TimeInterval = 6 * 3600

    /// Three attempts. Jitter is applied on top: without it an install base
    /// woken by one push wave hits the endpoint in a synchronised burst.
    static let retryDelays: [TimeInterval] = [0, 2, 8]
}
