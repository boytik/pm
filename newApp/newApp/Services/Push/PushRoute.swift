//
//  PushRoute.swift
//  Alpha Academy
//
//  Carries the URL from a tapped push to whatever is on screen.
//
//  It exists because `RootView` renders `WebShellView(destination:)` out of
//  `AppRouter.phase`, and `WebShellView` seeds its `@State currentURL` from
//  that argument. Re-assigning `.web(pushURL)` re-runs the initialiser but
//  SwiftUI keeps the view's identity, so the `@State` seed is discarded and the
//  page never changes. Forcing a new identity with `.id(url)` would work and is
//  the wrong answer: it tears down the WKWebView and its content process, and
//  this destination needs 5–30s to boot its bundle from a cold cache.
//
//  So the URL travels beside the phase instead, and the live web view reloads.
//

import Foundation
import Combine

@MainActor final class PushRoute: ObservableObject {

    static let shared = PushRoute()

    /// `@Published` replays its current value to every new subscriber, which is
    /// what makes the cold-start tap work: the delegate publishes shortly after
    /// launch, before the scene body is evaluated, and the shell's `onReceive`
    /// fires the moment it first appears.
    @Published private(set) var pendingURL: URL?

    /// The web shell writes every main-frame URL it visits back to
    /// `WebModeStore.destination`, which is what the next cold launch opens. A
    /// push URL carries `?pid=…`, so letting it become the saved address would
    /// make every future launch look like a click on a stale push — permanently.
    /// This suppresses exactly the write that follows a push navigation.
    private(set) var suppressNextAddressWrite = false

    private init() {}

    func request(_ url: URL) {
        suppressNextAddressWrite = true
        pendingURL = url
    }

    /// Called by whoever displayed it.
    func consume() {
        pendingURL = nil
    }

    /// One-shot: returns true if this address write is the push navigation's
    /// and should be dropped.
    func shouldSuppressAddressWrite() -> Bool {
        guard suppressNextAddressWrite else { return false }
        suppressNextAddressWrite = false
        return true
    }
}
