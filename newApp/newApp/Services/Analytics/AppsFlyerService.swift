//
//  AppsFlyerService.swift
//  Alpha Academy
//
//  Thin wrapper over AppsFlyerLib. The SDK was already linked to the target but
//  never imported; this is the only file that talks to it.
//

import Foundation
import AppsFlyerLib

enum AppsFlyerService {

    private static var didConfigure = false

    /// Call once, from the App's `init()`.
    ///
    /// SDK 7 dropped `waitForATTUserAuthorization` and no longer manages ATT
    /// timing itself: readiness is signalled through a session-ready listener,
    /// `start()` is never called automatically, and any consent has to be
    /// collected inside that block. So the listener waits for the ATT prompt to
    /// be answered before starting — otherwise the launch event goes out without
    /// the IDFA no matter what the learner picks.
    static func configure() {
        guard !didConfigure else { return }
        // Empty credentials are the normal state until the dev key is pasted
        // into AnalyticsConfig — leave the SDK dormant rather than half-started.
        guard AnalyticsConfig.isConfigured else { return }
        didConfigure = true

        let lib = AppsFlyerLib.shared()
        // Set BEFORE `initialize`, as the manual requires listeners to be
        // registered before the SDK is brought up: `onConversionDataSuccess`
        // fires once per install, a second or two after the first session, and
        // a delegate attached after that races the only callback there will
        // ever be. `AppsFlyerLib.delegate` is `weak`, which is why the object
        // is a `static let` and not built here.
        lib.delegate = AppsFlyerAttribution.shared
        lib.initialize(
            devKey: AnalyticsConfig.appsFlyerDevKey,
            appId: AnalyticsConfig.appleAppID
        )
        #if DEBUG
        lib.isDebug = true
        #endif

        // Fires once per foreground cycle, on the main queue, and resets on
        // background — so this covers every session, not just the first.
        lib.registerSessionReadyListener {
            Task {
                await TrackingAuthorization.settle()
                do {
                    // The completion-handler form, so a failed session is
                    // visible instead of silent.
                    _ = try await AppsFlyerLib.shared().start()
                } catch {
                    #if DEBUG
                    // Code 10 is the SDK refusing a session that arrived inside
                    // `minTimeBetweenSessions` — it logs `[WARNING] Skip launch`
                    // and keeps the earlier one. Normal when the listener fires
                    // again (an ATT or notification alert ends a foreground
                    // cycle) and normal under repeated QA relaunches. Not a
                    // failure, and printing it as one buries the real ones.
                    let ns = error as NSError
                    if ns.domain == "com.appsflyer.sdk.event", ns.code == 10 {
                        print("APPSFLYER session already counted — skipped")
                    } else {
                        print("APPSFLYER start failed — \(error)")
                    }
                    #endif
                }
            }
        }
    }

    /// The reason AppsFlyer is in this project at all: carrying our lead id out
    /// into the attribution postbacks. Safe to call repeatedly with the same id.
    static func setCustomerUserID(_ id: String) {
        guard didConfigure else { return }
        guard AppsFlyerLib.shared().customerUserID != id else { return }
        AppsFlyerLib.shared().customerUserID = id
    }

    /// AppsFlyer's own per-install UUID — stable for the lifetime of an install,
    /// regenerated on reinstall. Empty until the SDK is configured.
    static var installUID: String? {
        let uid = AppsFlyerLib.shared().getAppsFlyerUID()
        return uid.isEmpty ? nil : uid
    }

    /// Whatever `setCustomerUserID` last put there — the lead id, once the web
    /// bridge has lifted it out of the page. Read-only; nothing sets it here.
    static var customerUserID: String? {
        let id = AppsFlyerLib.shared().customerUserID
        return (id?.isEmpty ?? true) ? nil : id
    }

    /// All zeroes when ATT was denied or never answered, which is exactly what
    /// the dump needs to show: an IDFA of zeroes is the single most common
    /// reason an install looks organic when it was not.
    static var advertisingIdentifier: String? {
        let idfa = AppsFlyerLib.shared().advertisingIdentifier
        return idfa.isEmpty ? nil : idfa
    }

    /// Read off the linked framework's bundle — the SDK exposes no accessor.
    ///
    /// `CFBundleVersion`, not `CFBundleShortVersionString`: AppsFlyer ships the
    /// real version ("7.0.1") in the former and a hardcoded "1.0" in the
    /// latter, which is the wrong way round and reads as a healthy answer.
    static var sdkVersion: String? {
        let info = Bundle(for: AppsFlyerLib.self).infoDictionary
        return (info?["CFBundleVersion"] as? String)
            ?? (info?["CFBundleShortVersionString"] as? String)
    }

    /// Whether `configure()` actually brought the SDK up this launch. A false
    /// here makes every other AppsFlyer reading meaningless.
    static var isRunning: Bool { didConfigure }
}
