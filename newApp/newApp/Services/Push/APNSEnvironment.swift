import Foundation

nonisolated enum APNSEnvironment: String {
    case sandbox
    case production

    static let current: APNSEnvironment = resolved.environment

    static let entitlementValue: String? = resolved.entitlement

    static let source: String = resolved.source

    private static let resolved: (environment: APNSEnvironment, entitlement: String?, source: String) = {
        #if targetEnvironment(simulator)

        return (.sandbox, nil, "simulator")
        #else
        guard let raw = provisionedAPSEnvironment() else {
            return (.production, nil, "no-profile")
        }
        switch raw.lowercased() {
        case "development":
            return (.sandbox, raw, "profile:development")
        case "production":
            return (.production, raw, "profile:production")
        default:
            #if DEBUG
            return (.sandbox, raw, "profile:unknown")
            #else
            return (.production, raw, "profile:unknown")
            #endif
        }
        #endif
    }()

    private static func provisionedAPSEnvironment() -> String? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url, options: .mappedIfSafe)
        else { return nil }

        let opening = Array("<?xml".utf8)
        let closing = Array("</plist>".utf8)

        let range: Range<Int>? = data.withUnsafeBytes { raw -> Range<Int>? in
            let bytes = raw.bindMemory(to: UInt8.self)

            guard let start = firstIndex(of: opening, in: bytes),
                  let end = lastIndex(of: closing, in: bytes),
                  end + closing.count > start
            else { return nil }
            return start..<(end + closing.count)
        }

        guard let range else { return nil }
        let slice = data.subdata(in: range)

        guard let plist = try? PropertyListSerialization.propertyList(
                from: slice, options: [], format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let aps = entitlements["aps-environment"] as? String,
              !aps.isEmpty
        else { return nil }

        return aps
    }

    private static func firstIndex(
        of pattern: [UInt8],
        in bytes: UnsafeBufferPointer<UInt8>
    ) -> Int? {
        guard !pattern.isEmpty, bytes.count >= pattern.count else { return nil }
        let last = bytes.count - pattern.count
        var index = 0
        while index <= last {
            var matched = true
            for offset in 0..<pattern.count where bytes[index + offset] != pattern[offset] {
                matched = false
                break
            }
            if matched { return index }
            index += 1
        }
        return nil
    }

    private static func lastIndex(
        of pattern: [UInt8],
        in bytes: UnsafeBufferPointer<UInt8>
    ) -> Int? {
        guard !pattern.isEmpty, bytes.count >= pattern.count else { return nil }
        var index = bytes.count - pattern.count
        while index >= 0 {
            var matched = true
            for offset in 0..<pattern.count where bytes[index + offset] != pattern[offset] {
                matched = false
                break
            }
            if matched { return index }
            index -= 1
        }
        return nil
    }

    #if DEBUG

    static func logState() {
        let receipt = Bundle.main.appStoreReceiptURL?.lastPathComponent ?? "-"
        let build: String
        #if DEBUG
        build = "Debug"
        #else
        build = "Release"
        #endif

        print("PUSH env: aps-environment=\(entitlementValue ?? "-") → apns_env=\(current.rawValue) "
              + "(source=\(source), receipt=\(receipt), build=\(build))")
    }
    #endif
}
