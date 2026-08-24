//
//  APNSEnvironment.swift
//  Alpha Academy
//
//  Which APNs gateway this build's device token belongs to.
//
//  This is the highest-consequence value in the whole push integration and the
//  one the server spec singles out: a token minted against the sandbox gateway
//  and pushed to the production one comes back `BadDeviceToken`, and from the
//  app there is nothing to see — the request left, no error surfaced, the push
//  simply never arrived. Worse, if the field is omitted the server assumes
//  `production`, so every Xcode and development-profile TestFlight build fails
//  silently by default.
//
//  So it is resolved from the entitlement of the *built binary*, never from a
//  constant and never from `#if DEBUG` — a Release build signed with a
//  development profile is sandbox, and `#if DEBUG` would call it production.
//

import Foundation

nonisolated enum APNSEnvironment: String {
    case sandbox
    case production

    /// Resolved once. `static let` is lazy and thread-safe by the runtime.
    static let current: APNSEnvironment = resolved.environment

    /// The raw `aps-environment` string, when the profile could be read.
    static let entitlementValue: String? = resolved.entitlement

    /// Greppable provenance — `simulator`, `profile:development`,
    /// `profile:production`, `profile:unknown`, `no-profile`, `fallback:debug`,
    /// `fallback:release`. This is what turns a `BadDeviceToken` report into a
    /// one-line diagnosis, so it is logged next to the value itself.
    static let source: String = resolved.source

    // MARK: - Resolution

    private static let resolved: (environment: APNSEnvironment, entitlement: String?, source: String) = {
        #if targetEnvironment(simulator)
        // A simulator can obtain a real token on recent macOS, and it is always
        // a sandbox one.
        return (.sandbox, nil, "simulator")
        #else
        guard let raw = provisionedAPSEnvironment() else {
            // An App Store build has its provisioning profile stripped during
            // Apple's re-signing, and an App Store binary is production by
            // definition. This is the normal path in the store, not a failure.
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

    /// `embedded.mobileprovision` is a DER-encoded PKCS#7 blob wrapping a plain
    /// XML property list. iOS has no `CMSDecoder` and no public `SecCMS*`, so
    /// the accepted approach is to find the plist inside the blob by hand.
    ///
    /// Deliberately a byte scan and not `String(data:encoding: .utf8)`: the DER
    /// wrapper carries certificate bytes that are not valid UTF-8, so that
    /// decode returns nil and the whole detection fails silently — which is the
    /// exact failure mode this file exists to prevent.
    private static func provisionedAPSEnvironment() -> String? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url, options: .mappedIfSafe)
        else { return nil }

        let opening = Array("<?xml".utf8)
        let closing = Array("</plist>".utf8)

        let range: Range<Int>? = data.withUnsafeBytes { raw -> Range<Int>? in
            let bytes = raw.bindMemory(to: UInt8.self)
            // Forward for the opening, backward for the closing: a certificate
            // that happens to contain the closing bytes cannot truncate us.
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
    /// One line, printed at launch. If a push never arrives, this is the first
    /// thing to read.
    static func logState() {
        let receipt = Bundle.main.appStoreReceiptURL?.lastPathComponent ?? "-"
        let build: String
        #if DEBUG
        build = "Debug"
        #else
        build = "Release"
        #endif
        // The receipt name is printed as a diagnostic only. It says "installed
        // via TestFlight", which is orthogonal to the APNs gateway — a normal
        // TestFlight build has a sandboxReceipt AND a production environment.
        // Using it as an input is the classic BadDeviceToken bug.
        print("PUSH env: aps-environment=\(entitlementValue ?? "-") → apns_env=\(current.rawValue) "
              + "(source=\(source), receipt=\(receipt), build=\(build))")
    }
    #endif
}
