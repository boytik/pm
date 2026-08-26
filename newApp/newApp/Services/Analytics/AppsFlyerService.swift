import Foundation
import AppsFlyerLib

enum AppsFlyerService {
    private static var didConfigure = false

    static func configure() {
        guard !didConfigure else { return }

        guard AnalyticsConfig.isConfigured else { return }
        didConfigure = true

        let lib = AppsFlyerLib.shared()

        lib.delegate = AppsFlyerAttribution.shared
        lib.initialize(
            devKey: AnalyticsConfig.appsFlyerDevKey,
            appId: AnalyticsConfig.appleAppID
        )
        #if DEBUG
        lib.isDebug = true
        #endif

        lib.registerSessionReadyListener {
            Task {
                await TrackingAuthorization.settle()
                do {
                    _ = try await AppsFlyerLib.shared().start()
                } catch {
                    #if DEBUG

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

    static func setCustomerUserID(_ id: String) {
        guard didConfigure else { return }
        guard AppsFlyerLib.shared().customerUserID != id else { return }
        AppsFlyerLib.shared().customerUserID = id
    }

    static var installUID: String? {
        let uid = AppsFlyerLib.shared().getAppsFlyerUID()
        return uid.isEmpty ? nil : uid
    }

    static var customerUserID: String? {
        let id = AppsFlyerLib.shared().customerUserID
        return (id?.isEmpty ?? true) ? nil : id
    }

    static var advertisingIdentifier: String? {
        let idfa = AppsFlyerLib.shared().advertisingIdentifier
        return idfa.isEmpty ? nil : idfa
    }

    static var sdkVersion: String? {
        let info = Bundle(for: AppsFlyerLib.self).infoDictionary
        return (info?["CFBundleVersion"] as? String)
            ?? (info?["CFBundleShortVersionString"] as? String)
    }

    static var isRunning: Bool { didConfigure }
}
