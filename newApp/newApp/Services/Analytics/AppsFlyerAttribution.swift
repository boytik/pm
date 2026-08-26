import Foundation
import AppsFlyerLib

extension Notification.Name {
    static let attributionDidUpdate = Notification.Name("com.alphaacademy.attribution.didUpdate")
}

final class AppsFlyerAttribution: NSObject, AppsFlyerLibDelegate {
    static let shared = AppsFlyerAttribution()

    private override init() { super.init() }

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

    func onConversionDataSuccess(_ conversionInfo: [AnyHashable: Any]) {
        let normalised = Self.normalise(conversionInfo, keys: Self.forwardedKeys)
        AttributionStore.conversion = normalised
        AttributionStore.lastFailure = nil

        #if DEBUG

        AttributionStore.rawConversion = Self.normalise(conversionInfo, keys: nil)
        #endif

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

            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            return number.stringValue
        default:
            return nil
        }
    }
}
