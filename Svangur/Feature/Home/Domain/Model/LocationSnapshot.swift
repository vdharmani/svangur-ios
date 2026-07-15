import Foundation

/// The device's current coordinate plus its human-readable "City, Country" label, resolved
/// together so callers needing the raw coordinate (e.g. the deals feed's `lat`/`lng`) don't
/// have to re-fetch location a second time after `HomeViewModel` already resolved it for the
/// header's display text.
struct LocationSnapshot: Sendable, Equatable {
    let latitude: Double
    let longitude: Double
    let displayText: String
}
