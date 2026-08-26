import Foundation
import Combine

@MainActor final class PushRoute: ObservableObject {
    static let shared = PushRoute()

    @Published private(set) var pendingURL: URL?

    private(set) var suppressNextAddressWrite = false

    private init() {}

    func request(_ url: URL) {
        suppressNextAddressWrite = true
        pendingURL = url
    }

    func consume() {
        pendingURL = nil
    }

    func shouldSuppressAddressWrite() -> Bool {
        guard suppressNextAddressWrite else { return false }
        suppressNextAddressWrite = false
        return true
    }
}
