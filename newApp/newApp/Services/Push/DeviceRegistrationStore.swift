//
//  DeviceRegistrationStore.swift
//  Alpha Academy
//
//  What the last `/device/register` call did, so the next one can decide
//  whether it is worth making. Modelled on `WebModeStore`: a namespace over
//  `UserDefaults`, no instances, every key spelled out in one place.
//

import Foundation

nonisolated enum DeviceRegistrationStore {

    nonisolated(unsafe) private static let defaults = UserDefaults.standard

    private static let lastRegisterAtKey = "com.alphaacademy.device.lastRegisterAt"
    private static let lastRegisterOKAtKey = "com.alphaacademy.device.lastRegisterOKAt"
    private static let lastSentTokenKey = "com.alphaacademy.device.lastSentToken"
    private static let lastSentEnvKey = "com.alphaacademy.device.lastSentEnv"
    private static let lastLinkedKey = "com.alphaacademy.device.lastLinked"
    private static let lastHasTokenKey = "com.alphaacademy.device.lastHasAPNsToken"
    private static let pendingTokenKey = "com.alphaacademy.device.pendingToken"
    private static let didPurgeLegacyKey = "com.alphaacademy.device.didPurgeLegacyNotifications"

    /// Stamped before the request, not after: the throttle has to hold even
    /// when the request never comes back.
    static var lastRegisterAt: Date? {
        get { defaults.object(forKey: lastRegisterAtKey) as? Date }
        set { defaults.set(newValue, forKey: lastRegisterAtKey) }
    }

    static var lastRegisterOKAt: Date? {
        get { defaults.object(forKey: lastRegisterOKAtKey) as? Date }
        set { defaults.set(newValue, forKey: lastRegisterOKAtKey) }
    }

    static var lastSentToken: String? {
        get { defaults.string(forKey: lastSentTokenKey) }
        set { defaults.set(newValue, forKey: lastSentTokenKey) }
    }

    static var lastSentEnv: String? {
        get { defaults.string(forKey: lastSentEnvKey) }
        set { defaults.set(newValue, forKey: lastSentEnvKey) }
    }

    static var lastLinked: Bool {
        get { defaults.bool(forKey: lastLinkedKey) }
        set { defaults.set(newValue, forKey: lastLinkedKey) }
    }

    static var lastHasAPNsToken: Bool {
        get { defaults.bool(forKey: lastHasTokenKey) }
        set { defaults.set(newValue, forKey: lastHasTokenKey) }
    }

    /// A token that arrived while the Keychain was unreadable, so there was no
    /// `device_id` to send it with. Flushed after the next successful
    /// registration; without it such a device never reports its token at all.
    static var pendingToken: String? {
        get { defaults.string(forKey: pendingTokenKey) }
        set {
            if let newValue { defaults.set(newValue, forKey: pendingTokenKey) }
            else { defaults.removeObject(forKey: pendingTokenKey) }
        }
    }

    /// One-shot: upgraded installs still hold `push.*` local notifications the
    /// old pull funnel raised.
    static var didPurgeLegacyNotifications: Bool {
        get { defaults.bool(forKey: didPurgeLegacyKey) }
        set { defaults.set(newValue, forKey: didPurgeLegacyKey) }
    }
}
