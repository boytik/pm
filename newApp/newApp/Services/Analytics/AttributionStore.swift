import Foundation

nonisolated enum AttributionStore {
    nonisolated(unsafe) private static let defaults = UserDefaults.standard

    private static let conversionKey = "com.alphaacademy.attribution.conversion"
    private static let receivedAtKey = "com.alphaacademy.attribution.receivedAt"
    private static let failureKey = "com.alphaacademy.attribution.lastFailure"

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
