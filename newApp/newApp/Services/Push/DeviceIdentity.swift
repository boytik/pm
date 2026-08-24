//
//  DeviceIdentity.swift
//  Alpha Academy
//
//  The `device_id` the whole push funnel now hangs from. The app mints it
//  itself, once, and the backend builds everything else around it: the APNs
//  token, the bundle id, the locale, the AppsFlyer id, and — reported from
//  inside the web layer — which lead owns the handset.
//
//  It lives in the Keychain rather than `UserDefaults` for one reason:
//  `UserDefaults` is wiped when the app is deleted. A learner who reinstalls
//  would arrive as a brand new device, with the lead link dropped and the
//  install attribution lost. The Keychain survives that.
//
//  Read once per process and cached, so the touch from `WebShellView` (which
//  runs on the main actor) is a memory read rather than Keychain I/O — the
//  first read is done in `newAppApp.init()`.
//

import Foundation

nonisolated enum DeviceIdentity {

    static let service = "com.rainerhansen.globoton.device"
    static let account = "device_id"

    /// Not a source of truth — the Keychain is. This exists so that an item
    /// that vanishes from the Keychain while the install survives can be put
    /// back rather than replaced, because replacing it silently re-attributes
    /// the device.
    private static let mirrorKey = "com.alphaacademy.device.idMirror"

    nonisolated(unsafe) private static let defaults = UserDefaults.standard
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cachedID: String?

    /// Whatever `current()` last resolved, without touching the Keychain.
    static var cached: String? {
        lock.lock(); defer { lock.unlock() }
        return cachedID
    }

    /// `nil` only when the Keychain is genuinely unreadable — a background
    /// launch before the first unlock after a reboot. Callers must treat that
    /// as "not yet", never as "none": the registration is deferred to the next
    /// launch instead of being made against a second, invented identity.
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
            // Present but outside the contract's alphabet or length. The
            // backend would reject it, so it is no more useful than nothing.
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
            // Almost always errSecInteractionNotAllowed (-25308): the device
            // has not been unlocked since boot. Minting here would split the
            // device from its lead permanently.
            log("keychain unreadable (\(status)) — deferring, NOT minting")
            return nil
        }
    }

    /// Contract: `[A-Za-z0-9._:-]`, 8...128 characters. Also the guard that
    /// makes it safe to interpolate the value into injected JavaScript — the
    /// alphabet contains no quote and no backslash.
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

    // MARK: - Minting

    /// Caller holds `lock`.
    private static func mintLocked() -> String {
        let minted = UUID().uuidString.lowercased()   // 36 chars of [0-9a-f-]
        let status = Keychain.writeString(minted, service: service, account: account)

        if status == errSecDuplicateItem {
            // Lost a race against another thread, or an item we could not read
            // a moment ago became readable. Whatever is in there wins.
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
            // Cache it anyway so the launch call and the token call agree with
            // each other this session, but do not mirror it: the next launch
            // must be free to retry the write rather than adopt a value that
            // never reached the Keychain.
            log("keychain write failed (\(status)) — using \(redact(minted)) for this launch only")
        }

        cachedID = minted
        return minted
    }

    // MARK: - Logging

    /// Never the whole id: it identifies a person to anyone reading the log.
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
    /// `AA_DEVICE_RESET=1` — forces the next `current()` to mint, so the
    /// "survives reinstall" check has something to compare against.
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
