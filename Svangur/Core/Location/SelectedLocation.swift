import Foundation

/// A location the user manually confirmed on `ConfirmLocationScreen` — as opposed to one read
/// live from `LocationServiceProtocol.currentLocation()` (GPS).
struct SelectedLocation: Sendable, Equatable {
    let latitude: Double
    let longitude: Double
    let displayText: String
}
