import Foundation

/// Bridges a location confirmed on `ConfirmLocationScreen` back to the long-lived `HomeViewModel`
/// singleton. `AppRoute` is a plain `Hashable` enum (required by `NavigationPath`) so it can't
/// carry a completion closure, and `router.popToRoot()` never tears down or reconstructs the
/// root `HomeScreen` — so there is no other channel for "screen B hands a result to screen A"
/// in this app. `HomeViewModel` subscribes to `updates` once, in `onAppear`.
protocol SelectedLocationStoreProtocol: Sendable {
    func set(_ location: SelectedLocation) async
    func updates() async -> AsyncStream<SelectedLocation>
}

actor SelectedLocationStore: SelectedLocationStoreProtocol {
    private var current: SelectedLocation?
    private var continuation: AsyncStream<SelectedLocation>.Continuation?

    func set(_ location: SelectedLocation) {
        current = location
        continuation?.yield(location)
    }

    func updates() -> AsyncStream<SelectedLocation> {
        AsyncStream { continuation in
            self.continuation = continuation
            if let current {
                continuation.yield(current)
            }
        }
    }
}
