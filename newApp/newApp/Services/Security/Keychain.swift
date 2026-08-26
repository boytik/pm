import Foundation
import Security

nonisolated enum Keychain {
    enum ReadResult {
        case found(String)

        case absent

        case unreadable(OSStatus)
    }

    static func readString(service: String, account: String) -> ReadResult {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,

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
