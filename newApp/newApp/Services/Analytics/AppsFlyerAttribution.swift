//
//  AppsFlyerAttribution.swift
//  Alpha Academy
//
//  `AppsFlyerLibDelegate` — the half of the Pocket integration manual that was
//  missing. Step 4 of the manual wants the campaign link opened with the
//  learner's `appsflyer_id` *and* their conversion data; `appsflyer_id` is a
//  synchronous read off the SDK, conversion data only ever arrives here.
//
//  Retained by a `static let`, deliberately. `AppsFlyerLib.delegate` is a
//  `weak` property, so a delegate built inline at the call site is deallocated
//  before the callback it exists for can fire — and the failure is silent: the
//  SDK simply calls nobody.
//

import Foundation
import AppsFlyerLib

extension Notification.Name {
    /// Posted on the main queue once the conversion payload has landed. The web
    /// shell listens so a page that is already open gets the data pushed into
    /// it, instead of waiting for a navigation that a single-page app may never
    /// make.
    static let attributionDidUpdate = Notification.Name("com.alphaacademy.attribution.didUpdate")
}

final class AppsFlyerAttribution: NSObject, AppsFlyerLibDelegate {

    static let shared = AppsFlyerAttribution()

    private override init() { super.init() }

    /// What is carried onward into the campaign link.
    ///
    /// A whitelist rather than "everything the callback handed us", for two
    /// reasons. Conversion data carries the campaign's **cost** fields
    /// (`af_cpi`, `orig_cost`, `af_cost_value`, `af_cost_currency`) — media
    /// buying economics that have no business being pasted into a URL the
    /// learner can read in Safari's address bar. And it carries SDK
    /// diagnostics (`iscache`, `af_r`, `http_referrer`, `esp_name`) that mean
    /// nothing to the receiving end and only make the link longer.
    ///
    /// Everything the manual's example shows — `campaign`, `media_source`,
    /// `af_click_id` — is here.
    static let forwardedKeys: Set<String> = [
        "af_status",
        "media_source",
        "campaign",
        "campaign_id",
        "agency",
        "af_prt",
        "af_channel",
        "af_siteid",
        "af_ad",
        "af_ad_id",
        "af_ad_type",
        "adset",
        "adset_id",
        "adgroup",
        "adgroup_id",
        "af_sub1",
        "af_sub2",
        "af_sub3",
        "af_sub4",
        "af_sub5",
        "af_click_id",
        "is_retargeting",
        "retargeting_conversion_type",
        "click_time",
        "install_time",
    ]

    // MARK: - AppsFlyerLibDelegate

    func onConversionDataSuccess(_ conversionInfo: [AnyHashable: Any]) {
        let normalised = Self.normalise(conversionInfo, keys: Self.forwardedKeys)
        AttributionStore.conversion = normalised
        AttributionStore.lastFailure = nil

        #if DEBUG
        // The full payload, not just the forwarded slice: when the link comes
        // out wrong the first question is always "what did AppsFlyer actually
        // send us", and the answer must not be the filtered view. Persisted so
        // the console dump can still answer it on the next launch, by which
        // point this callback will never fire again.
        AttributionStore.rawConversion = Self.normalise(conversionInfo, keys: nil)
        #endif

        // Main queue: the observer pushes into a WKWebView. The SDK does not
        // promise which queue this arrives on.
        DispatchQueue.main.async {
            #if DEBUG
            DebugAttributionDump.emit(reason: "conversion data arrived")
            #endif
            NotificationCenter.default.post(name: .attributionDidUpdate, object: nil)
        }
    }

    func onConversionDataFail(_ error: Error) {
        AttributionStore.lastFailure = error.localizedDescription
        #if DEBUG
        print("ATTRIBUTION failed: \(error.localizedDescription)")
        #endif
    }

    // MARK: - Normalisation

    /// Conversion data is a loosely typed `NSDictionary`: values arrive as
    /// `NSString`, `NSNumber` or `NSNull` depending on the key and on the
    /// campaign. The manual is explicit that empty parameters must not be
    /// appended to the link, so anything that does not reduce to a non-empty
    /// string is dropped here rather than at the point of use.
    /// `keys: nil` keeps everything — used only by the DEBUG dump, which has to
    /// show what arrived before it shows what survived the whitelist.
    private static func normalise(_ raw: [AnyHashable: Any], keys: Set<String>?) -> [String: String] {
        var result: [String: String] = [:]
        for (rawKey, rawValue) in raw {
            guard let key = rawKey as? String else { continue }
            if let keys, !keys.contains(key) { continue }
            guard let value = string(from: rawValue), !value.isEmpty else { continue }
            result[key] = value
        }
        return result
    }

    private static func string(from value: Any) -> String? {
        switch value {
        case is NSNull:
            return nil
        case let string as String:
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        case let number as NSNumber:
            // `CFBoolean` is an `NSNumber` whose `stringValue` is "1"/"0";
            // `is_retargeting` reads far better as a word on the receiving end.
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            return number.stringValue
        default:
            return nil
        }
    }
}
