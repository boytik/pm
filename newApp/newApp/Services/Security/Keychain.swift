//
//  Keychain.swift
//  Alpha Academy
//
//  A four-call wrapper over `SecItem*`. The only thing it has to get right is
//  telling *absent* apart from *unreadable*: a caller that mints a replacement
//  value on an ambiguous failure loses whatever the old value was linked to,
//  and there is no way back from that. Hence `ReadResult` rather than `String?`.
//
//  `nonisolated` throughout, matching `WebModeStore` — the target builds with
//  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and this is plain C API traffic
//  with no business being pinned to the main actor.
//

import Foundation
import Security

nonisolated enum Keychain {

    enum ReadResult {
        /// The item is there.
        case found(String)
        /// `errSecItemNotFound`. The only status on which minting is safe.
        case absent
        /// Anything else — most importantly `errSecInteractionNotAllowed`
        /// (-25308), which is what a background launch before the first unlock
        /// gets. The item may well exist; we simply cannot see it right now.
        case unreadable(OSStatus)
    }

    static func readString(service: String, account: String) -> ReadResult {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            // Tolerant on read, pinned to false on write. A mismatch between the
            // two is the classic "the item is there but SecItemCopyMatching
            // cannot find it" bug.
            kSecAttrSynchronizable: kSecAttrSynchronizableAny,
            kSecReturnData: kCFBooleanTrue as Any,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let value = String(data: data, encoding: .utf8),
                  !value.isEmpty
            else {
                // Present but not a UTF-8 string: a corrupt write, not a
                // permissions problem. Absent is the honest answer.
                return .absent
            }
            return .found(value)
        case errSecItemNotFound:
            return .absent
        default:
            return .unreadable(status)
        }
    }

    @discardableResult
    static func writeString(_ value: String, service: String, account: String) -> OSStatus {
        let attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: Data(value.utf8),
            // `AfterFirstUnlock` so a background launch on a locked device can
            // still read it; `ThisDeviceOnly` so it never rides a backup onto a
            // second handset, where two devices would claim one identity.
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrSynchronizable: kCFBooleanFalse as Any,
            kSecAttrLabel: "Alpha Academy device id",
        ]
        return SecItemAdd(attributes as CFDictionary, nil)
    }

    @discardableResult
    static func delete(service: String, account: String) -> OSStatus {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny,
        ]
        return SecItemDelete(query as CFDictionary)
    }
}
