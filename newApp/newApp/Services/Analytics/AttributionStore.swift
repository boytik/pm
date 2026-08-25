//
//  AttributionStore.swift
//  Alpha Academy
//
//  Where AppsFlyer's conversion data is kept between launches.
//
//  It has to be kept, and that is the whole reason this file exists:
//  `onConversionDataSuccess` fires **once, on the first launch after install**,
//  a second or two after the SDK's first session. Every launch after that gets
//  nothing at all. The learner who taps "Deposit" on day three is exactly the
//  one the integration is for, so a copy that lives only in memory is a copy
//  that is never there when it is needed.
//
//  `UserDefaults`, not the Keychain: unlike `device_id` this is not an identity
//  worth surviving a delete — a reinstall is a *new* install with its own
//  attribution, and carrying the old one across would be worse than losing it.
//

import Foundation

nonisolated enum AttributionStore {

    // UserDefaults is not marked Sendable but is documented as thread-safe.
    nonisolated(unsafe) private static let defaults = UserDefaults.standard

    private static let conversionKey = "com.alphaacademy.attribution.conversion"
    private static let receivedAtKey = "com.alphaacademy.attribution.receivedAt"
    private static let failureKey = "com.alphaacademy.attribution.lastFailure"

    /// The forwarded slice of the conversion payload, already normalised to
    /// strings and already filtered — see `AppsFlyerAttribution.forwardedKeys`.
    /// Nil until the callback has landed at least once.
    static var conversion: [String: String]? {
        get { defaults.dictionary(forKey: conversionKey) as? [String: String] }
        set {
            guard let newValue, !newValue.isEmpty else {
                defaults.removeObject(forKey: conversionKey)
                return
            }
            defaults.set(newValue, forKey: conversionKey)
            defaults.set(Date(), forKey: receivedAtKey)
        }
    }

    static var receivedAt: Date? {
        defaults.object(forKey: receivedAtKey) as? Date
    }

    /// Kept only so the probe can answer "did it fail, or has it not fired
    /// yet?" — two states that look identical from `conversion == nil`.
    static var lastFailure: String? {
        get { defaults.string(forKey: failureKey) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: failureKey)
            } else {
                defaults.removeObject(forKey: failureKey)
            }
        }
    }

    /// The **whole** payload, unfiltered, kept only so the console dump can
    /// answer "what did AppsFlyer actually send" on a launch long after the
    /// one callback fired. DEBUG only: the unfiltered payload carries the
    /// campaign's cost fields, and a release build has no reason to hold them.
    #if DEBUG
    private static let rawConversionKey = "com.alphaacademy.attribution.rawConversion"

    static var rawConversion: [String: String]? {
        get { defaults.dictionary(forKey: rawConversionKey) as? [String: String] }
        set {
            guard let newValue, !newValue.isEmpty else {
                defaults.removeObject(forKey: rawConversionKey)
                return
            }
            defaults.set(newValue, forKey: rawConversionKey)
        }
    }
    #endif

    #if DEBUG
    /// `AA_ATTRIBUTION_RESET=1` — forget the conversion payload, so the next
    /// launch behaves like a page that has not been told anything yet. It does
    /// **not** make the SDK fire the callback again; only a reinstall does that.
    static func applyQAOverrides() {
        guard ProcessInfo.processInfo.environment["AA_ATTRIBUTION_RESET"] == "1" else { return }
        defaults.removeObject(forKey: conversionKey)
        defaults.removeObject(forKey: receivedAtKey)
        defaults.removeObject(forKey: failureKey)
        defaults.removeObject(forKey: rawConversionKey)
        print("ATTRIBUTION store: cleared by AA_ATTRIBUTION_RESET")
    }
    #endif
}
