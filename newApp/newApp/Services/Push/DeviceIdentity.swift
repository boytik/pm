import Foundation

nonisolated enum DeviceIdentity {
    static let service = "com.jorgspan.alphaacademy.device"
    static let account = "device_id"

    private static let mirrorKey = "com.alphaacademy.device.idMirror"

    nonisolated(unsafe) private static let defaults = UserDefaults.standard
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cachedID: String?

    static var cached: String? {
        lock.lock(); defer { lock.unlock() }
        return cachedID
    }

    @discardableResult
    static func current() -> String? {
        lock.lock(); defer { lock.unlock() }

        if let cachedID { return cachedID }

        switch Keychain.readString(service: service, account: account) {
        case .found(let stored) where isValid(stored):
            log("keychain hit \(redact(stored))")
            defaults.set(stored, forKey: mirrorKey)
            cachedID = stored
            return stored

        case .found(let stored):

            log("keychain holds an invalid id (\(stored.count) chars) — reminting")
            Keychain.delete(service: service, account: account)
            return mintLocked()

        case .absent:
            if let mirrored = defaults.string(forKey: mirrorKey), isValid(mirrored) {
                log("keychain empty but mirror survived — restoring \(redact(mirrored))")
                Keychain.writeString(mirrored, service: service, account: account)
                cachedID = mirrored
                return mirrored
            }
            return mintLocked()

        case .unreadable(let status):

            log("keychain unreadable (\(status)) — deferring, NOT minting")
            return nil
        }
    }

    static func isValid(_ id: String) -> Bool {
        guard (8...128).contains(id.count) else { return false }
        return id.unicodeScalars.allSatisfy { scalar in
            switch scalar {
            case "A"..."Z", "a"..."z", "0"..."9": return true
            case ".", "_", ":", "-": return true
            default: return false
            }
        }
    }

    private static func mintLocked() -> String {
        let minted = UUID().uuidString.lowercased()
        let status = Keychain.writeString(minted, service: service, account: account)

        if status == errSecDuplicateItem {
            if case .found(let existing) = Keychain.readString(service: service, account: account),
               isValid(existing) {
                log("mint raced an existing item — keeping \(redact(existing))")
                defaults.set(existing, forKey: mirrorKey)
                cachedID = existing
                return existing
            }
        }

        if status == errSecSuccess {
            defaults.set(minted, forKey: mirrorKey)
            log("minted \(redact(minted)) — first launch on this device")
        } else {
            log("keychain write failed (\(status)) — using \(redact(minted)) for this launch only")
        }

        cachedID = minted
        return minted
    }

    private static func redact(_ id: String) -> String {
        guard id.count > 8 else { return "…" }
        return id.prefix(8) + "…"
    }

    private static func log(_ message: String) {
        #if DEBUG
        print("PUSH device: \(message)")
        #endif
    }

    #if DEBUG

    static func applyQAOverrides() {
        guard ProcessInfo.processInfo.environment["AA_DEVICE_RESET"] == "1" else { return }
        lock.lock(); defer { lock.unlock() }
        Keychain.delete(service: service, account: account)
        defaults.removeObject(forKey: mirrorKey)
        cachedID = nil
        print("PUSH device: AA_DEVICE_RESET — keychain entry and mirror cleared")
    }
    #endif
}
