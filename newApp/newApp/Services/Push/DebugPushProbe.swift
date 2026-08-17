//
//  DebugPushProbe.swift
//  Alpha Academy
//
//  DEBUG-only round trip against the live push endpoint. The poller itself is
//  gated on notification permission, and `simctl` cannot grant that — so this
//  exercises the half that can regress silently (URL shape, headers, decoding)
//  without tapping through onboarding first.
//
//    SIMCTL_CHILD_AA_PUSH_PROBE=1 SIMCTL_CHILD_AA_LEAD_ID=<user_id> \
//      xcrun simctl launch --console-pty booted j.newApp
//

#if DEBUG
import Foundation

enum DebugPushProbe {

    static var isRequested: Bool {
        ProcessInfo.processInfo.environment["AA_PUSH_PROBE"] == "1"
    }

    static func run() async {
        guard let raw = LeadIdentity.rawUserID else {
            print("PROBE no lead id — set AA_LEAD_ID")
            return
        }
        print("PROBE raw lead id: \(raw)")
        print("PROBE accepted as user_id: \(LeadIdentity.userID ?? "no — see the warning above")")

        guard let userID = LeadIdentity.userID else { return }
        do {
            let response = try await PushAPI.fetchPending(
                userID: userID,
                session: LeadIdentity.session
            )
            print("PROBE has_push=\(response.hasPush) "
                  + "next_poll_after_sec=\(response.nextPollAfterSec) "
                  + "reason=\(response.reason ?? "-")")
            if let push = response.push {
                print("PROBE post=\(push.postID) delivery=\(push.deliveryID) "
                      + "lang=\(push.lang) action=\(push.action?.url ?? "null")")
                print("PROBE title: \(push.title)")
                print("PROBE body: \(push.body)")
            }
        } catch {
            print("PROBE failed — \(error)")
        }
    }
}
#endif
