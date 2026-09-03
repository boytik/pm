import Foundation
import AppTrackingTransparency
import UIKit

enum TrackingAuthorization {
    static var status: ATTrackingManager.AuthorizationStatus {
        ATTrackingManager.trackingAuthorizationStatus
    }

    static var isResolved: Bool { status != .notDetermined }

    /// Two shapes of "no prompt ever appeared" look identical from inside the app and
    /// only one of them is ours to fix. iOS declines to draw the alert while the app is
    /// not the active foreground app and leaves the status `.notDetermined` — transient,
    /// and the cure is to ask again on the next activation. It also declines forever when
    /// Settings › Privacy & Security › Tracking › "Allow Apps to Request to Track" is off,
    /// or a Screen Time restriction forbids it: `.denied` comes back in microseconds with
    /// nothing drawn, and no amount of asking will change that. Asking on every foreground
    /// costs nothing in the second case and is the whole fix in the first.
    @MainActor private static var inFlight: Task<Void, Never>?

    @MainActor
    static func requestIfNeeded() async {
        guard status == .notDetermined else { return }

        if let existing = inFlight {
            await existing.value
            return
        }

        let task = Task { @MainActor in await perform() }
        inFlight = task
        await task.value
        inFlight = nil
    }

    static func settle(timeout: TimeInterval = 30) async {
        guard status == .notDetermined else { return }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, status == .notDetermined {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
    }

    @MainActor
    private static func perform() async {
        guard await waitUntilActive() else {
            log("app never became active — not asking, will retry on the next foreground")
            return
        }

        let started = Date()
        let result = await ATTrackingManager.requestTrackingAuthorization()
        let elapsed = Date().timeIntervalSince(started)

        switch result {
        case .notDetermined:
            log("system declined to show the prompt — will retry on the next foreground")
        case .denied where elapsed < 0.25:
            log(String(
                format: "denied in %.0fms with no alert drawn — "
                    + "'Allow Apps to Request to Track' is off in "
                    + "Settings › Privacy & Security › Tracking, or a Screen Time "
                    + "restriction forbids it. The prompt CANNOT be shown on this device.",
                elapsed * 1000
            ))
        default:
            log("answered \(name(result)) after \(Int(elapsed * 1000))ms")
        }
    }

    /// Bounded on purpose: this sits on the launch path ahead of `WebGate.decide()`, so a
    /// wait that never returns would strand the install on the splash. Giving up here is
    /// not giving up on the prompt — every subsequent activation calls back in.
    @MainActor
    private static func waitUntilActive(timeout: TimeInterval = 10) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if UIApplication.shared.applicationState == .active { return true }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return false
    }

    private static func name(_ status: ATTrackingManager.AuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .restricted:    return "restricted"
        case .denied:        return "denied"
        case .authorized:    return "authorized"
        @unknown default:    return "unknown(\(status.rawValue))"
        }
    }

    private static func log(_ message: String) {
        #if DEBUG
        print("ATT: \(message)")
        #endif
    }
}
