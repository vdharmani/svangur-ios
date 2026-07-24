import Foundation

/// A location the user previously searched for and picked. Carries `placeID` (not just the
/// display text) so re-selecting it from the recent-searches list resolves the same real
/// coordinate/address again via `PlacesServiceProtocol.placeDetails(placeID:)` — without it,
/// `ConfirmLocationViewModel` has nothing to look up and falls back to the device's GPS fix.
struct RecentLocationSearch: Codable, Equatable, Identifiable, Sendable {
    let displayName: String
    let placeID: String?

    var id: String { displayName }
}
