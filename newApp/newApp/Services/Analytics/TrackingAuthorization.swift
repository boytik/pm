import Foundation
import AppTrackingTransparency
import UIKit

enum TrackingAuthorization {
    static var status: ATTrackingManager.AuthorizationStatus {
        ATTrackingManager.trackingAuthorizationStatus
    }

    static var isResolved: Bool { status != .notDetermined }

    static func requestIfNeeded() async {
        guard status == .notDetermined else { return }
        guard await waitUntilActive() else { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    static func settle(timeout: TimeInterval = 30) async {
        guard status == .notDetermined else { return }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, status == .notDetermined {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
    }

    private static func waitUntilActive(timeout: TimeInterval = 5) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await MainActor.run(body: { UIApplication.shared.applicationState == .active }) {
                return true
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return false
    }
}
